# TestFlight setup and release

One-time Apple work (account holder or App Manager):

1. Create App ID `ru.audio2midi.app` with Push Notifications enabled.
2. Create the App Store Connect app named Audio2MIDI with that bundle ID.
3. Create an Apple Distribution certificate and an App Store provisioning
   profile for the bundle ID; export the certificate and private key as `.p12`.
4. Create an App Store Connect API key with App Manager access and download its
   `.p8` file.
5. Create an APNs auth key and provide its `.p8`, Key ID, and Team ID to the
   backend secret store. The key never belongs in this repository.

GitHub environment `testflight` variables:

- `APPLE_TEAM_ID`
- `IOS_APPSTORE_PROFILE_NAME`
- `APPSTORE_ISSUER_ID`
- `APPSTORE_API_KEY_ID`

GitHub environment secrets:

- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `IOS_APPSTORE_PROFILE_BASE64`
- `IOS_KEYCHAIN_PASSWORD`
- `APPSTORE_API_PRIVATE_KEY` (raw `.p8` content)

Release: merge a green PR, open Actions → TestFlight → Run workflow, and enter
brief beta notes. TestFlight processing begins only after the archive and all
tests succeed. No production backend deploy is performed by the iOS workflow.

