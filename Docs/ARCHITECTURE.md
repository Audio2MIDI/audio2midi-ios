# Architecture

## Boundaries

- `Audio2MIDICore` contains wire models, the cookie-backed production client,
  fixture service, upload/import orchestration, and stable product output modes.
- `App` contains SwiftUI presentation, microphone/file affordances, push
  registration, and the hybrid `WKWebView` editor.
- `UITests` consume fixture scenarios rather than production data.
- The UI exposes the same five processing choices as the mini-app. Stable
  product modes use `/process`; piano routing and quick MIDI use the existing
  public `/processing-requests` and `/submit` compatibility routes.

The native base URL is `https://api.audio2midi.ru`. Artifact downloads are made
with the authenticated native `URLSession` and then handed to the iOS share
sheet. The editor receives its own web session through a rate-limited,
single-use browser handoff; native session cookies are never copied between
domains.

## Product flows

1. Email OTP creates the same account session as the web app.
2. A file is hashed locally, presigned, uploaded, and submitted using a stable
   output mode.
3. A URL or catalog track creates a durable import; the client polls the import
   record, then submits the resulting project.
4. Library state maps the backend's real `queued`, `leased`, `running`,
   `succeeded`, `failed`, and `cancelled` states and polls active jobs every four
   seconds in the foreground.
5. APNs registration is just-in-time. Result notifications deep-link by project
   ID; invalid device tokens are disabled server-side.
6. Result editing exchanges a five-minute, single-use handoff inside
   `WKWebView`, then opens the existing Signal editor. The button is shown only
   when the backend editor rollout enables the current account.

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
