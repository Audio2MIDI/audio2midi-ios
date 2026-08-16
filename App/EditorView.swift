import SwiftUI
import WebKit

struct EditorView: UIViewRepresentable {
    let projectID: UUID
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = UIColor(StudioColor.black)
        view.scrollView.backgroundColor = UIColor(StudioColor.black)
        view.load(URLRequest(url: URL(string: "https://app.audio2midi.ru/editor/\(projectID)")!))
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

