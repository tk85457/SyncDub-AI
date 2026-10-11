# Google Play Console — In-App Products Setup Guide (One-Time Minute Packs)

This guide provides step-by-step instructions to configure the **4 One-Time In-App Purchase (IAP) Products** for SyncDub AI in the [Google Play Console](https://play.google.com/console).

---

## 1. Product Summary & IDs

In Google Play Console, go to **Monetize > Products > In-app products** (Managed Products).

> **Important**: All products are configured as **In-app products (One-time purchase)**, NOT subscriptions. Once consumed by the app, they grant minutes to the user's Supabase account.

| Product ID | Product Name | Description | Default Price (USD) | Default Price (INR) | Pricing Tier |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `syncdub_starter_120m` | **SyncDub Starter Pack** | 120 minutes of real-time AI dubbing across 70+ languages. One-time purchase, never expires. | **$9.99** | **₹799.00** | Tier 1 (Entry) |
| `syncdub_pro_300m` | **SyncDub Pro Pack** | 300 minutes of real-time AI dubbing. Most popular pack for courses & podcasts. | **$19.99** | **₹1,599.00** | Tier 2 (Most Popular) |
| `syncdub_power_700m` | **SyncDub Power Viewer Pack** | 700 minutes of high-speed AI dubbing. Best value for series & binge watchers. | **$39.99** | **₹3,199.00** | Tier 3 (Best Value) |
| `syncdub_studio_1600m` | **SyncDub Studio Pack** | 1,600 minutes of studio-grade neural speech dubbing with priority edge routing. | **$79.99** | **₹6,499.00** | Tier 4 (Studio / Power) |

---

## 2. Step-by-Step Creation on Google Play Console

### Step 2.1: Prerequisites
1. Log in to [Google Play Console](https://play.google.com/console).
2. Select your app: **SyncDub AI** (`com.syncdub.livedub`).
3. Ensure your **Merchant Account** is linked (**Settings > Developer account > Payment settings**).
4. Verify your app bundle (`app-release.aab`) with billing permissions has been uploaded to an internal testing or closed testing track at least once. (Our app's Manifest already includes `com.android.vending.BILLING`).

---

### Step 2.2: Create Product 1 — Starter Pack (120 Minutes)
1. On the left navigation menu, expand **Monetize with Play** and click **In-app products**.
2. Click the blue **Create product** button.
3. Fill in the details:
   - **Product ID**: `syncdub_starter_120m` *(Must be all lowercase with underscores, cannot be changed later)*.
   - **Name**: `SyncDub Starter Pack (120 Mins)`
   - **Description**: `Get 120 minutes of real-time AI video dubbing across 70+ languages. One-time purchase, yours to keep forever.`
4. Click **Set price**:
   - Enter Default price: **$9.99 USD** (or **₹799.00 INR**).
   - Click **Update exchange rates** to auto-fill all regional currencies.
   - Click **Apply prices**.
5. Under **Status**, select **Active**.
6. Click **Save** at the bottom right.

---

### Step 2.3: Create Product 2 — Pro Pack (300 Minutes) [Most Popular]
1. Click **Create product**.
2. Details:
   - **Product ID**: `syncdub_pro_300m`
   - **Name**: `SyncDub Pro Pack (300 Mins)`
   - **Description**: `Get 300 minutes of neural video dubbing. Most popular pack for lectures, courses, and podcasts with priority AI speed.`
3. Set price:
   - Default price: **$19.99 USD** (or **₹1,599.00 INR**).
   - Click **Update exchange rates** $\rightarrow$ **Apply prices**.
4. Set Status to **Active**.
5. Click **Save**.

---

### Step 2.4: Create Product 3 — Power Viewer Pack (700 Minutes)
1. Click **Create product**.
2. Details:
   - **Product ID**: `syncdub_power_700m`
   - **Name**: `SyncDub Power Viewer Pack (700 Mins)`
   - **Description**: `Get 700 minutes of AI voice dubbing. Perfect for multi-episode series and binge-watching foreign content.`
3. Set price:
   - Default price: **$39.99 USD** (or **₹3,199.00 INR**).
   - Click **Update exchange rates** $\rightarrow$ **Apply prices**.
4. Set Status to **Active**.
5. Click **Save**.

---

### Step 2.5: Create Product 4 — Studio Pack (1,600 Minutes)
1. Click **Create product**.
2. Details:
   - **Product ID**: `syncdub_studio_1600m`
   - **Name**: `SyncDub Studio Pack (1,600 Mins)`
   - **Description**: `Get 1,600 minutes of studio-grade neural translation with maximum bandwidth and priority edge proxy routing.`
3. Set price:
   - Default price: **$79.99 USD** (or **₹6,499.00 INR**).
   - Click **Update exchange rates** $\rightarrow$ **Apply prices**.
4. Set Status to **Active**.
5. Click **Save**.

---

## 3. License Testing (Test Without Real Money)

To test the purchases directly on your physical test device without being charged:
1. In Google Play Console, go to **Setup > License testing**.
2. Under **License testers**, add your Gmail address (e.g. your Google account on the phone).
3. Under **License response**, set it to **`RESPOND_NORMALLY`**.
4. Now, when you trigger purchase from the app, Google Play will display a test card:
   - *"Test card, always approves"* or *"Test instrument"*.
   - No actual money is deducted, and the purchase token is generated immediately.

---

## 4. Consumable Workflow (How the App Grants Minutes)

Because these are **minute packs** that users can purchase multiple times:
1. When user taps **Purchase**, Google Play Billing launches the native bottom sheet.
2. Once the payment succeeds, the app receives the `PurchaseDetails`.
3. The app's backend or Flutter service sends the `purchaseToken` to your Supabase Edge Function to verify and credit the exact minutes (`120`, `300`, `700`, or `1600`) to `profiles.credits`.
4. The app calls `InAppPurchase.completePurchase(purchaseDetails)` / `consumePurchaseAndroid()`:
   - This marks the purchase as **consumed** in Google Play so the user is permitted to buy the pack again whenever they need more minutes.

---

## 5. Checklist Before Production Launch

- [ ] All 4 products created and set to **Active**.
- [ ] Product IDs match exact strings: `syncdub_starter_120m`, `syncdub_pro_300m`, `syncdub_power_700m`, `syncdub_studio_1600m`.
- [ ] Merchant Account bank details verified in Google Play Console.
- [ ] License tester email added for QA validation.
- [ ] App bundle uploaded to internal testing track with billing permission.
