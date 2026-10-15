import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat service for SyncDub AI (the ONLY billing stack in the app).
///
/// Responsibilities:
/// - Dynamic offerings fetched live from RevenueCat (nothing hardcoded)
/// - Google Play Billing via RevenueCat
/// - Reactive ChangeNotifier so the paywall updates when the catalog loads
/// - Restore purchases
///
/// SECURITY: this class NEVER credits translation minutes. A purchase is confirmed by RevenueCat's
/// server-to-server webhook, which credits the user's profile on the Render server (idempotent,
/// see translator/server/revenuecat_webhook.js). The app only starts the purchase and then reads
/// the resulting balance back from the server.
class RevenueCatService extends ChangeNotifier {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  /// Official Android Public API Key for SyncDub AI
  static const String apiKey = 'goog_hRFflvyUzHSKFXnTBALlgbdPpRx';

  /// Primary Pro Entitlement
  static const String entitlementPro = 'syncdub_ai_pro';

  /// Google Play one-time product IDs (see GOOGLE_PLAY_IN_APP_PRODUCTS_GUIDE.md).
  /// Safety net only: when RevenueCat returns no packages (offering missing, or Play products not
  /// attached to it in the dashboard) the paywall reads these straight from Google Play, so the
  /// prices always show. Purchases still go through the RevenueCat SDK, so the webhook still credits.
  static const List<String> storeProductIds = [
    'syncdub_starter_120m',
    'syncdub_pro_300m',
    'syncdub_power_700m',
    'syncdub_studio_1600m',
  ];

  List<StoreProduct> _storeProducts = [];

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Single in-flight/finished initialization. Guarantees Purchases.configure() runs at most once,
  /// even when initialize() and logIn() are called concurrently at startup.
  Future<void>? _initFuture;

  Offerings? _offerings;
  Offerings? get offerings => _offerings;

  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Callback when a purchase fails
  void Function(String error)? onPurchaseError;

  /// True when the last purchase attempt ended as "pending" / "already waiting" (e.g. UPI or a slow
  /// bank). Google Play still completes it later and the webhook credits it, so the app keeps watching.
  bool _lastPurchasePending = false;
  bool get lastPurchasePending => _lastPurchasePending;

  /// Technical reason for the last failure. It is always written to the log, and only debug builds
  /// can show it on screen. End users only ever see the simple messages below.
  String? _lastDebugDetail;
  String? get lastDebugDetail => kDebugMode ? _lastDebugDetail : null;

  // Simple, user-facing messages (no provider / store / dashboard wording).
  static const String _msgNoInternet = 'No internet connection. Please check your network and try again.';
  static const String _msgPricesUnavailable = 'Prices are not available right now. Please try again in a little while.';
  static const String _msgPaymentFailed =
      'The payment could not be completed. If any amount was deducted, your minutes will be added automatically.';
  static const String _msgRestoreFailed = 'Could not restore your purchases. Please check your internet connection and try again.';
  static const String _msgLinkFailed = 'We could not link this purchase to your account. Please check your connection and try again.';

  /// Initialize the RevenueCat SDK. Safe to call many times / concurrently: every caller shares
  /// the same initialization.
  Future<void> initialize({String? appUserId}) {
    return _initFuture ??= _doInitialize(appUserId);
  }

  Future<void> _doInitialize(String? appUserId) async {
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      final configuration = PurchasesConfiguration(apiKey);
      if (appUserId != null && appUserId.isNotEmpty) {
        configuration.appUserID = appUserId;
      }

      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint('[RevenueCatService] Initialized (signed in: ${appUserId != null && appUserId.isNotEmpty})');

      // Listen for customer info updates (restores, pending approvals, other devices)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _customerInfo = customerInfo;
        notifyListeners();
      });

      // Load initial customer info & live offerings from RevenueCat
      await refreshCustomerInfo();
      await fetchOfferings();
    } catch (e) {
      debugPrint('[RevenueCatService] Initialization failed: $e');
      // Allow a later call to retry, but only if configure() itself did not complete.
      if (!_isInitialized) _initFuture = null;
    }
  }

  /// Makes sure RevenueCat's App User ID is the Supabase user id. The webhook can only credit a
  /// purchase when the App User ID is that id, so a purchase must never run while anonymous.
  Future<bool> ensureLoggedIn(String appUserId) async {
    await initialize(appUserId: appUserId);
    if (!_isInitialized) return false;
    try {
      if (await Purchases.appUserID == appUserId) return true;
      final result = await Purchases.logIn(appUserId);
      _customerInfo = result.customerInfo;
      notifyListeners();
      debugPrint('[RevenueCatService] Logged in to RevenueCat');
      await fetchOfferings();
      return true;
    } catch (e) {
      debugPrint('[RevenueCatService] LogIn error: $e');
      _lastDebugDetail = e.toString();
      _lastErrorMessage = _msgLinkFailed;
      return false;
    }
  }

  /// Update App User ID (e.g. after Google OAuth / Supabase login)
  Future<void> logIn(String appUserId) async {
    await ensureLoggedIn(appUserId);
  }

  /// Log out from RevenueCat (on app sign-out)
  Future<void> logOut() async {
    if (!_isInitialized) return;
    try {
      if (await Purchases.isAnonymous) return;
      _customerInfo = await Purchases.logOut();
      notifyListeners();
      debugPrint('[RevenueCatService] Logged out successfully');
    } catch (e) {
      debugPrint('[RevenueCatService] LogOut error: $e');
    }
  }

  /// Refreshes and returns the current CustomerInfo
  Future<CustomerInfo?> refreshCustomerInfo() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      notifyListeners();
      return _customerInfo;
    } catch (e) {
      debugPrint('[RevenueCatService] getCustomerInfo failed: $e');
      return null;
    }
  }

  /// Checks if the user has the active pro entitlement
  bool get hasProEntitlement {
    final info = _customerInfo;
    if (info == null) return false;
    return info.entitlements.active.containsKey(entitlementPro);
  }

  /// Fetch dynamic offerings live from RevenueCat
  Future<Offerings?> fetchOfferings() async {
    try {
      _isLoading = true;
      _lastErrorMessage = null;
      notifyListeners();

      // The paywall can open before the SDK finished configuring. Wait for it instead of failing.
      if (!_isInitialized) {
        await initialize();
      }
      if (!_isInitialized) {
        _lastDebugDetail = 'Purchases SDK is not configured (configure failed or no network at start-up).';
        _lastErrorMessage = _msgPricesUnavailable;
        return null;
      }

      var networkDown = false;
      try {
        _offerings = await Purchases.getOfferings();
        debugPrint('[RevenueCatService] Loaded offerings: all=${_offerings?.all.keys.toList()}, current=${_offerings?.current?.identifier}, packages=${availablePackages.length}');
        if (_offerings == null || _offerings!.all.isEmpty) {
          _lastDebugDetail = 'No offerings exist in RevenueCat for this app. Create an offering and make it Current.';
        } else if (availablePackages.isEmpty) {
          _lastDebugDetail = 'The RevenueCat offering has no packages. Add packages that point to your Google Play products.';
        }
      } on PlatformException catch (e) {
        debugPrint('[RevenueCatService] Failed to fetch offerings: $e');
        _lastDebugDetail = _offeringsDebugHint(e);
        networkDown = PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.networkError;
      } catch (e) {
        debugPrint('[RevenueCatService] Failed to fetch offerings: $e');
        _lastDebugDetail = e.toString();
      }

      // Safety net: RevenueCat gave no packages, so read the products straight from Google Play.
      if (availablePackages.isEmpty && !networkDown) {
        await _loadStoreProducts();
      }

      if (displayProducts.isEmpty) {
        _lastErrorMessage = networkDown ? _msgNoInternet : _msgPricesUnavailable;
      } else {
        _lastErrorMessage = null;
      }
      return _offerings;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reads the one-time products directly from Google Play (through the RevenueCat SDK).
  Future<void> _loadStoreProducts() async {
    try {
      final products = await Purchases.getProducts(
        storeProductIds,
        productCategory: ProductCategory.nonSubscription,
      );
      _storeProducts = List<StoreProduct>.from(products);
      debugPrint('[RevenueCatService] Loaded ${products.length} products directly from the store');
      if (products.isEmpty) {
        _lastDebugDetail =
            'Google Play returned none of the product IDs. Each ID must be ACTIVE in Play Console, and the app must be installed from Google Play (testing track or production).';
      }
    } catch (e) {
      debugPrint('[RevenueCatService] Direct store products failed: $e');
      _lastDebugDetail = e.toString();
    }
  }

  /// What the paywall shows: RevenueCat packages when they exist, otherwise the products read
  /// directly from Google Play. Sorted from the smallest to the largest price.
  List<StoreProduct> get displayProducts {
    final pkgs = availablePackages;
    final list = pkgs.isNotEmpty
        ? pkgs.map((p) => p.storeProduct).toList()
        : List<StoreProduct>.from(_storeProducts);
    list.sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  /// The RevenueCat package that wraps this store product, if the dashboard offering has one.
  Package? _packageFor(StoreProduct product) {
    for (final pkg in availablePackages) {
      if (pkg.storeProduct.identifier == product.identifier) return pkg;
    }
    return null;
  }

  /// Packages to show on the paywall. Uses the offering flagged "Current" in RevenueCat; if none is
  /// flagged (or it is empty) it falls back to the first offering that has packages, so a missing
  /// "Current" flag in the dashboard never leaves the paywall empty.
  List<Package> get availablePackages {
    final offerings = _offerings;
    if (offerings == null) return [];
    final current = offerings.current;
    if (current != null && current.availablePackages.isNotEmpty) {
      return current.availablePackages;
    }
    for (final offering in offerings.all.values) {
      if (offering.availablePackages.isNotEmpty) return offering.availablePackages;
    }
    return [];
  }

  /// Technical explanation of why the catalog could not load. Debug builds / logs only.
  String _offeringsDebugHint(PlatformException e) {
    switch (PurchasesErrorHelper.getErrorCode(e)) {
      case PurchasesErrorCode.configurationError:
        return 'Google Play did not return the products. Each RevenueCat product ID must exactly match an ACTIVE Google Play product, and this build must be installed from a Google Play testing track.';
      case PurchasesErrorCode.networkError:
        return 'No internet connection. Check your network and tap Refresh.';
      case PurchasesErrorCode.storeProblemError:
        return 'Google Play is not available right now. Update Google Play services and try again.';
      case PurchasesErrorCode.invalidCredentialsError:
        return 'RevenueCat rejected the API key. Check the Android public key in the app.';
      default:
        return e.message ?? e.toString();
    }
  }

  String _friendlyPurchaseError(PlatformException e) {
    switch (PurchasesErrorHelper.getErrorCode(e)) {
      case PurchasesErrorCode.networkError:
        return _msgNoInternet;
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already have a payment waiting. Your minutes will be added shortly.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Your payment is pending. Your minutes will be added as soon as it is confirmed.';
      default:
        return _msgPaymentFailed;
    }
  }

  /// Purchase a dynamic RevenueCat package.
  ///
  /// Returns true when Google Play accepted the payment. It does NOT mean minutes are credited yet:
  /// the server credits them after RevenueCat's webhook arrives (usually within seconds).
  Future<bool> purchaseProduct(StoreProduct product, {required String appUserId}) async {
    try {
      _isLoading = true;
      _lastErrorMessage = null;
      _lastPurchasePending = false;
      notifyListeners();

      // A purchase made while anonymous could never be credited by the webhook. Refuse it.
      if (!await ensureLoggedIn(appUserId)) {
        _lastErrorMessage =
            'We could not link this purchase to your account. Please check your connection and try again.';
        onPurchaseError?.call(_lastErrorMessage!);
        return false;
      }

      final package = _packageFor(product);
      final purchaseResult = await Purchases.purchase(
        package != null ? PurchaseParams.package(package) : PurchaseParams.storeProduct(product),
      );
      _customerInfo = purchaseResult.customerInfo;

      debugPrint('[RevenueCatService] Purchase accepted for ${product.identifier}; awaiting server credit');
      return true;
    } catch (e) {
      if (e is PlatformException) {
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
          debugPrint('[RevenueCatService] Purchase cancelled by user');
          return false;
        }
        if (errorCode == PurchasesErrorCode.paymentPendingError ||
            errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
          _lastPurchasePending = true;
        }
        if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
          // Google Play still holds an unconsumed purchase: syncing hands it to RevenueCat so the
          // webhook can credit it (idempotent on the server, so this can never double-credit).
          try {
            await Purchases.syncPurchases();
          } catch (_) {}
        }
      }
      debugPrint('[RevenueCatService] Purchase error: $e');
      _lastDebugDetail = e.toString();
      _lastErrorMessage = e is PlatformException ? _friendlyPurchaseError(e) : _msgPaymentFailed;
      onPurchaseError?.call(_lastErrorMessage!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore purchases
  Future<CustomerInfo?> restorePurchases() async {
    try {
      _isLoading = true;
      _lastErrorMessage = null;
      notifyListeners();
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      debugPrint('[RevenueCatService] Restored purchases successfully');
      return info;
    } catch (e) {
      debugPrint('[RevenueCatService] restorePurchases error: $e');
      _lastDebugDetail = e.toString();
      _lastErrorMessage = _msgRestoreFailed;
      onPurchaseError?.call(_msgRestoreFailed);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// DISPLAY ONLY: reads the pack size from the product id (e.g. syncdub_pro_300m -> 300) or the
  /// store title/description. Returns 0 when it cannot be determined, in which case the UI simply
  /// hides the minutes label. The real credited amount always comes from the server catalog
  /// (public.iap_products), never from this value.
  static int parseMinutesFromProduct(StoreProduct product) {
    final id = product.identifier;
    final idMatch = RegExp(r'(\d+)\s*m\b', caseSensitive: false).firstMatch(id);
    if (idMatch != null) {
      final m = int.tryParse(idMatch.group(1) ?? '');
      if (m != null && m > 0) return m;
    }

    final text = '${product.title} ${product.description}'.replaceAll(',', '');
    final textMatch = RegExp(r'(\d+)\s*(?:minute|min)', caseSensitive: false).firstMatch(text);
    if (textMatch != null) {
      final m = int.tryParse(textMatch.group(1) ?? '');
      if (m != null && m > 0) return m;
    }
    return 0;
  }
}
