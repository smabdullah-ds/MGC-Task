# Privacy disclosures

These are the answers for **Google Play → Data safety** and **App Store Connect → App Privacy**, based on what the app and its SDKs do. Review them with whoever writes your privacy policy before submitting. SDK behaviour can change between versions; Google, Firebase, RevenueCat and each mediation network publish their own disclosure guides.

**Audience:** general audience, 13+. Not directed at children, and not in the Play Families programme. Ads are requested with no child or teen treatment and a maximum content rating of T.

## Google Play — Data safety

| Data type | Collected | Shared | Purpose | Optional? |
| --- | --- | --- | --- | --- |
| Device or other IDs (advertising ID, Firebase installation ID) | Yes | Yes (ad networks) | Advertising or marketing, Analytics, Fraud prevention | No |
| App interactions (levels, boosters, screens) | Yes | No | Analytics, App functionality | No |
| In-app search history / other user content | No | – | – | – |
| Purchase history | Yes | No | App functionality, Analytics | No |
| Crash logs | Yes | No | App functionality (Crashlytics) | No |
| Diagnostics (performance) | Yes | No | App functionality | No |
| Approximate location (from IP, by ad SDKs) | Yes | Yes (ad networks) | Advertising | No |
| Personal info (name, e-mail, …) | No | – | – | – |

- Data is encrypted in transit: **yes**.
- Users can request deletion: **yes**, by e-mailing support. Firebase Analytics data can be deleted per user via the Firebase/Google Analytics user deletion API.
- Contains ads: **yes**.

## App Store — App Privacy

**Used to track you:** Identifiers → Device ID (IDFA, only when ATT is allowed). Usage Data → Advertising Data.

**Linked to you:** none. The game has no accounts, and RevenueCat uses an anonymous app user ID.

**Not linked to you:**
- Identifiers → Device ID: Third-Party Advertising, Analytics
- Usage Data → Product Interaction: Analytics, Product Personalization
- Usage Data → Advertising Data: Third-Party Advertising
- Purchases → Purchase History: App Functionality, Analytics
- Diagnostics → Crash Data, Performance Data: App Functionality
- Location → Coarse Location (IP-derived, by ad SDKs): Third-Party Advertising

The app-level privacy manifest is `ios/Runner/PrivacyInfo.xcprivacy`. The SDKs ship their own manifests, which Xcode merges. Generate the privacy report in Xcode (Product → Archive → Generate Privacy Report) and check it matches the answers above.

## Consent flow (what the code does)

1. **Google UMP** runs first on every launch. It shows the GDPR form in the EEA, UK and Switzerland, and the US state-regulation message where it applies.
2. **iOS ATT** prompt (text: "Your data will be used to show you more relevant ads and keep Bazaar Sort free to play.").
3. Only then do the ads SDKs initialise. Ads are personalised only when UMP allows it *and*, on iOS, ATT is authorised; otherwise they're non-personalised. If UMP says ads may not be requested at all, no ads are requested.
4. Settings → "Manage ad consent" re-opens the UMP privacy options form at any time.
