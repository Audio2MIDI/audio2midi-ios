# Architecture

## Boundaries

- `Audio2MIDICore` contains wire models, the cookie-backed production client,
  fixture service, upload/import orchestration, and stable product output modes.
- `App` contains SwiftUI presentation, microphone/file affordances, push
  registration, and the hybrid `WKWebView` editor.
- `UITests` consume fixture scenarios rather than production data.
- Backend engine names never appear in UI decisions. The server maps
  `piano_cover`, `notes_chords`, and `stems` to processing engines.

The native base URL is `https://app.audio2midi.ru/api`, not the separate API
hostname. This keeps the HttpOnly account session available to both URLSession
and the editor hosted at `https://app.audio2midi.ru/editor/{projectID}`.

## Product flows

1. Email OTP creates the same account session as the web app.
2. A file is hashed locally, presigned, uploaded, and submitted using a stable
   output mode.
3. A URL or catalog track creates a durable import; the client polls the import
   record, then submits the resulting project.
4. Library state is refreshed immediately and again by pull-to-refresh.
5. APNs registration is just-in-time. Result notifications deep-link by project
   ID; invalid device tokens are disabled server-side.
6. Result editing uses the existing Signal editor in `WKWebView`; native file,
   library, auth, and creation surfaces remain independent of editor rollout.

## Design decision ledger

Reference lock for the first beta:

- Splice: dark studio tone and focus on the active audio object.
- Ableton Live: flat, precise controls with visible state instead of decoration.
- Spotify library: recognizable hierarchy and dense, scannable project rows.
- Stemz/Moises: source-first conversion flow and explicit output selection.

Applied rules: near-black canvas, one cobalt accent (`#1253FF`), no gradients,
no decorative glass, no card-per-sentence layout, and one primary action per
screen. SF Symbols are used only for platform actions and status. The visual
system is intentionally not copied from the legacy mini-app banner.

