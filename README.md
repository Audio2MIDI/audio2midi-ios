# Audio2MIDI for iOS

Native iOS 17+ client for the existing Audio2MIDI account, processing, library,
and editor platform. The app is deliberately independent from the React
Telegram mini-app; the shared boundary is the backend API contract.

## Run

1. Install the current stable Xcode and XcodeGen.
2. Run `xcodegen generate`.
3. Open `Audio2MIDI.xcodeproj` and run the `Audio2MIDI` scheme.

The normal app talks directly to `https://api.audio2midi.ru`. The web editor
uses a short-lived, single-use browser handoff so the native API session is
never placed in a URL. Deterministic fixture
states require no account or network:

- `-fixture=ready -skipOnboarding`
- `-fixture=empty -skipOnboarding`
- `-fixture=processing -skipOnboarding`
- `-fixture=failed -skipOnboarding`

`swift test` validates production-shaped job statuses, the five processing
routes, Yandex Music import polling, source validation, editor handoff, and the
client/domain package without Xcode. Pull requests also generate the project
and run fixture-driven UI tests on an iPhone Simulator.

## Release boundary

The TestFlight workflow is manual and requires the protected `testflight`
environment. It archives exactly the reviewed commit, increments the build
number from the GitHub run, and uploads the exported IPA. Required variables
and secrets are documented in [RELEASING.md](Docs/RELEASING.md).
