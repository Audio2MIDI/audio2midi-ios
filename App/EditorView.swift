import Audio2MIDICore
import SwiftUI
import WebKit

struct EditorView: View {
    @Bindable var model: AppModel
    let projectID: UUID
    @State private var token: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let token {
                EditorWebView(projectID: projectID, token: token) { message in
                    errorMessage = message
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Editor unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Opening the editor…").tint(StudioColor.blue)
            }
        }
        .background(StudioColor.black)
        .navigationTitle("Piano editor")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard token == nil, errorMessage == nil else { return }
            do { token = try await model.service.editorHandoffToken(projectID: projectID) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

private struct EditorWebView: UIViewRepresentable {
    let projectID: UUID
    let token: String
    let onError: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(projectID: projectID, onError: onError) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(StudioColor.black)
        view.scrollView.backgroundColor = UIColor(StudioColor.black)

        var request = URLRequest(url: URL(string: "https://app.audio2midi.ru/api/v1/auth/browser-handoff/consume")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(HandoffConsumeRequest(token: token))
        view.load(request)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let projectID: UUID
        let onError: @MainActor (String) -> Void
        private var exchanged = false
        private var failed = false

        init(projectID: UUID, onError: @escaping @MainActor (String) -> Void) {
            self.projectID = projectID
            self.onError = onError
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if !exchanged,
               let response = navigationResponse.response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                failed = true
                Task { @MainActor in onError("The secure editor sign-in failed (HTTP \(response.statusCode)).") }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !exchanged, !failed else { return }
            exchanged = true
            webView.load(URLRequest(url: URL(string: "https://app.audio2midi.ru/editor/\(projectID)")!))
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in onError(error.localizedDescription) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in onError(error.localizedDescription) }
        }
    }
}

private struct HandoffConsumeRequest: Encodable {
    let token: String
}
