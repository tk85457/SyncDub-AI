import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat service for SyncDub AI (the ONLY billing stack in the app).
///
/// Responsibilities:
/// - Dynamic offerings fetched live from RevenueCat (nothing hardcoded)
/// - Google Play Billing via RevenueCat
/// - Reactive ChangeNotifier so the paywall updates when the catalog loads
/// - Native RevenueCat Paywall + Customer Center
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
      _lastErrorMessage = e.toString();
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

      _offerings = await Purchases.getOfferings();
      debugPrint('[RevenueCatService] Loaded offerings: current=${_offerings?.current?.identifier}, packages=${_offerings?.current?.availablePackages.length ?? 0}');
      return _offerings;
    } catch (e) {
      debugPrint('[RevenueCatService] Failed to fetch offerings: $e');
      _lastErrorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// List of available packages in the current offering
  List<Package> get availablePackages {
    final current = _offerings?.current;
    if (current == null) return [];
    return current.availablePackages;
  }

  /// Purchase a dynamic RevenueCat package.
  ///
  /// Returns true when Google Play accepted the payment. It does NOT mean minutes are credited yet:
  /// the server credits them after RevenueCat's webhook arrives (usually within seconds).
  Future<bool> purchasePackage(Package package, {required String appUserId}) async {
    try {
      _isLoading = true;
      _lastErrorMessage = null;
      notifyListeners();

      // A purchase made while anonymous could never be credited by the webhook. Refuse it.
      if (!await ensureLoggedIn(appUserId)) {
        _lastErrorMessage =
            'We could not link this purchase to your account. Please check your connection and try again.';
        onPurchaseError?.call(_lastErrorMessage!);
        return false;
      }

      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      _customerInfo = purchaseResult.customerInfo;

      debugPrint('[RevenueCatService] Purchase accepted for ${package.storeProduct.identifier}; awaiting server credit');
      return true;
    } catch (e) {
      if (e is PlatformException) {
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
          debugPrint('[RevenueCatService] Purchase cancelled by user');
          return false;
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
      _lastErrorMessage = e.toString();
      onPurchaseError?.call(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Present RevenueCat Native Paywall UI
  Future<PaywallResult> presentPaywall() async {
    try {
      final result = await RevenueCatUI.presentPaywall(
        displayCloseButton: true,
      );
      if (result == PaywallResult.purchased || result == PaywallResult.restored) {
        await refreshCustomerInfo();
      }
      return result;
    } catch (e) {
      debugPrint('[RevenueCatService] presentPaywall error: $e');
      return PaywallResult.error;
    }
  }

  /// Present RevenueCat Customer Center UI (manage purchases)
  Future<void> presentCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
      await refreshCustomerInfo();
    } catch (e) {
      debugPrint('[RevenueCatService] presentCustomerCenter error: $e');
    }
  }

  /// Restore purchases
  Future<CustomerInfo?> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      debugPrint('[RevenueCatService] Restored purchases successfully');
      return info;
    } catch (e) {
      debugPrint('[RevenueCatService] restorePurchases error: $e');
      _lastErrorMessage = e.toString();
      onPurchaseError?.call(e.toString());
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
  static int parseMinutesFromPackage(Package package) {
    final id = package.storeProduct.identifier;
    final idMatch = RegExp(r'(\d+)\s*m\b', caseSensitive: false).firstMatch(id);
    if (idMatch != null) {
      final m = int.tryParse(idMatch.group(1) ?? '');
      if (m != null && m > 0) return m;
    }

    final text = '${package.storeProduct.title} ${package.storeProduct.description}'.replaceAll(',', '');
    final textMatch = RegExp(r'(\d+)\s*(?:minute|min)', caseSensitive: false).firstMatch(text);
    if (textMatch != null) {
      final m = int.tryParse(textMatch.group(1) ?? '');
      if (m != null && m > 0) return m;
    }
    return 0;
  }
}
