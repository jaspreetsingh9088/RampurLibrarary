# Setup guide

Everything is automated by GitHub Actions; you only need to create the cloud accounts
and paste a few values into **GitHub → Settings → Secrets and variables → Actions**.
Until a value is added, the related workflow still builds but skips that step (and
the apps show a "not configured" screen).

Time needed: about 30–45 minutes.

---

## 1. Firebase project

1. Go to <https://console.firebase.google.com> → **Add project** (e.g. `rampur-library`).
2. **Upgrade to the Blaze plan** (pay-as-you-go). Cloud Functions and scheduled jobs need it;
   a small library stays well inside the free quota.
3. **Build → Authentication → Get started**, then enable sign-in providers:
   - **Phone** (members). For testing, add a test number such as `+91 99999 00000` / code `123456`.
   - **Email/Password** (staff for the admin panel).
   - Under **Settings → Authorized domains** add your Vercel domains
     (`rampur-library-admin.vercel.app`, `rampur-library-site.vercel.app`, and any custom domain).
4. **Build → Firestore Database → Create database** (production mode, region `asia-south1` Mumbai).
5. **Build → Storage → Get started** (same region).
6. **Project settings → General → Your apps** — add three apps:
   - **Web app** (nickname "Admin") → copy `apiKey`, `authDomain`, `projectId`, `storageBucket`,
     `messagingSenderId`, `appId`, `measurementId`.
   - **Android app** with package name **`com.rampurlibrary.app`** → download `google-services.json`.
     Copy the Android **App ID** (`1:…:android:…`).
   - **iOS app** with bundle ID **`com.rampurlibrary.app`** → download `GoogleService-Info.plist`.
     Copy the iOS **App ID** (`1:…:ios:…`) and `CLIENT_ID` from the plist.
7. **Project settings → Cloud Messaging**:
   - For iOS push, upload an **APNs authentication key** (.p8) from your Apple Developer account.
8. **Project settings → Service accounts → Generate new private key** → downloads a JSON file
   (used by CI to deploy rules & functions, and by the admin bootstrap script).

## 2. GitHub secrets

Add these under **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `FIREBASE_API_KEY` | web `apiKey` |
| `FIREBASE_PROJECT_ID` | `projectId` |
| `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` |
| `FIREBASE_STORAGE_BUCKET` | `storageBucket` |
| `FIREBASE_AUTH_DOMAIN` | `authDomain` |
| `FIREBASE_WEB_APP_ID` | web `appId` |
| `FIREBASE_MEASUREMENT_ID` | web `measurementId` (optional) |
| `FIREBASE_ANDROID_APP_ID` | Android app ID |
| `FIREBASE_IOS_APP_ID` | iOS app ID |
| `FIREBASE_IOS_CLIENT_ID` | `CLIENT_ID` from `GoogleService-Info.plist` |
| `GOOGLE_SERVICES_JSON` | full contents of `google-services.json` |
| `GOOGLE_SERVICE_INFO_PLIST` | full contents of `GoogleService-Info.plist` |
| `FIREBASE_SERVICE_ACCOUNT` | full contents of the service-account JSON |
| `VERCEL_TOKEN` | see step 3 |
| `VERCEL_SCOPE` | *(optional)* your Vercel team slug, if deploying to a team |

And under the **Variables** tab:

| Variable | Value |
|---|---|
| `SITE_URL` | public website URL, e.g. `https://rampur-library-site.vercel.app` (or your domain) |
| `VERCEL_ADMIN_PROJECT` | *(optional)* Vercel project name for the admin panel (default `rampur-library-admin`) |
| `VERCEL_SITE_PROJECT` | *(optional)* Vercel project name for the website (default `rampur-library-site`) |

## 3. Vercel

1. Sign in at <https://vercel.com> (with GitHub is easiest).
2. **Account settings → Tokens → Create** → copy into the `VERCEL_TOKEN` secret.
3. That's it — the first run of **Deploy web (Vercel)** creates both projects automatically
   and prints the URLs in the workflow summary. Add custom domains in each Vercel project if you like
   (and add them to Firebase *Authorized domains*).

## 4. Android signing (recommended)

Without this, CI signs the APK with a throwaway debug key, so each build has a different
signature (users must uninstall before updating, and Firebase Phone Auth falls back to a
reCAPTCHA check). Create a permanent key once:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rampur
base64 -w0 release.jks > release.jks.b64     # macOS: base64 -i release.jks -o release.jks.b64
keytool -list -v -keystore release.jks -alias rampur   # shows SHA-1 and SHA-256
```

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | contents of `release.jks.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `rampur` |
| `ANDROID_KEY_PASSWORD` | key password (if different) |

Then add the **SHA-1 and SHA-256** fingerprints to Firebase → Project settings → Android app
(required for smooth Phone Auth), download the updated `google-services.json` and update its secret.
**Keep `release.jks` safe** — you need the same key for every future update and for Google Play.

## 5. iOS signing (needed to install on iPhones)

iOS apps can only be installed when signed by an Apple Developer account ($99/year).
Without these secrets CI produces an *unsigned* IPA (useful to check the build, not installable).

| Secret | Value |
|---|---|
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `IOS_CERTIFICATE_P12_BASE64` | base64 of your **Apple Distribution** certificate exported as .p12 |
| `IOS_CERTIFICATE_PASSWORD` | password of that .p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | base64 of an **App Store** provisioning profile for `com.rampurlibrary.app` with Push Notifications enabled |

The signed IPA can be uploaded to TestFlight / App Store Connect with Transporter.

## 6. First deployment

1. Push to `main` (or run each workflow manually from the **Actions** tab):
   - **Deploy Firebase** — publishes rules, indexes and functions.
   - **Deploy web (Vercel)** — admin panel + website.
   - **Mobile builds** — APK/AAB/IPA in the run's **Artifacts**.
2. Create the first admin:
   - Firebase Console → Authentication → **Add user** (your email + password).
   - On your computer:
     ```bash
     cd functions && npm install
     GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json node ../tools/set-admin.mjs you@example.com admin
     ```
   - Sign in to the admin panel. Add more staff from the **Staff** page.
3. *(Optional)* Load sample categories and books:
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json node ../tools/seed.mjs
   ```
4. In the admin panel **Settings**, fill in the library address, phone and the Android download link
   (e.g. the GitHub release URL). The website picks these up within a few minutes.

## 7. Releasing a new app version

```bash
# bump `version:` in apps/mobile_app/pubspec.yaml, then
git tag v1.0.1 && git push origin v1.0.1
```

The **Mobile builds** workflow publishes a GitHub Release with `RampurLibrary.apk`,
per-ABI APKs, the Play Store `.aab` and the `.ipa`.

## Troubleshooting

- **App shows "Almost there!"** — the build had no Firebase secrets. Add them and re-run *Mobile builds*.
- **OTP never arrives** — check Phone provider is enabled, the Blaze plan is active, and (Android) SHA fingerprints are registered.
- **Admin panel says "not a staff account"** — run `tools/set-admin.mjs` for that user, then sign out and in.
- **Firestore "requires an index" error** — the *Deploy Firebase* workflow deploys `firebase/firestore.indexes.json`; wait a few minutes for indexes to build.
- **Push not received on iPhone** — upload the APNs key in Firebase and use a signed build.
