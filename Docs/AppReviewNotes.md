# App Review Notes

Paste this into App Store Connect review notes when you submit the build that includes subscriptions:

```text
NearBLE uses one auto-renewable subscription:

Product:
- NearBLE Pro Monthly
- Product ID: com.codify.nearble.pro.monthly

Where to find the purchase flow:
1. Launch the app.
2. Go to Settings.
3. Tap "Upgrade to Pro".

The paywall is also shown automatically if a Free user reaches the daily Ask AI limit:
1. Open any scanned BLE device.
2. Tap "Ask AI".
3. Send prompts until the daily free limit is reached.
4. The Pro paywall will appear automatically.

What the subscription unlocks:
- Unlimited Ask AI usage
- Pro entitlement state across the app

The app uses StoreKit 2 for:
- Product loading
- Purchase
- Restore Purchases
- Current entitlement refresh

There is no external account creation required to use the subscription.
```

## Suggested review screenshot

Upload a screenshot of the paywall screen showing:

- NearBLE Pro title
- monthly price
- Unlock Pro button
- Restore Purchases button

## Internal submission checklist

- Product ID in App Store Connect exactly matches `com.codify.nearble.pro.monthly`
- Subscription status is not missing metadata
- Localization, price, tax category, and review screenshot are filled
- Subscription is attached to the app submission if this is the first IAP review
