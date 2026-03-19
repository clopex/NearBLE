# StoreKit Local Testing

The repo now includes a local StoreKit configuration file at:

- `NearBLE/Config/NearBLE.storekit`

This file is meant for fast local purchase testing in Xcode and Simulator using the same Product ID as the app code:

- `com.codify.nearble.pro.monthly`

## How to enable it in Xcode

1. Open the project in Xcode.
2. In the Project navigator, confirm `NearBLE/Config/NearBLE.storekit` appears under the app folder.
3. Select the `NearBLE` scheme.
4. Choose `Product` -> `Scheme` -> `Edit Scheme...`
5. Open the `Run` tab.
6. In `Options`, set `StoreKit Configuration` to `NearBLE.storekit`.
7. Run the app on Simulator or a local device from Xcode.

## What to test locally

1. Open `Settings` -> `Upgrade to Pro`
2. Verify the price/product loads.
3. Tap `Unlock Pro`
4. Confirm the purchase sheet flow completes.
5. Confirm `Settings` shows `Tier: Pro`
6. Open `Ask AI` and verify the free limit no longer blocks sending prompts.
7. Use `Restore Purchases` and confirm entitlement refresh still resolves to Pro.

## Important note

If Xcode says the StoreKit file is invalid or rewrites it, recreate it using:

1. `File` -> `New` -> `File...`
2. `Other` -> `StoreKit Configuration File`
3. Add one `Auto-Renewable Subscription`
4. Use the same Product ID:
   `com.codify.nearble.pro.monthly`

Apple notes that StoreKit Testing in Xcode uses the active StoreKit configuration file for local testing, and that product identifiers in your app must match the identifiers in that file.
