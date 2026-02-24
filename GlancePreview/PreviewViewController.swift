import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!
    private var pendingHTML: String?

    override func loadView() {
        let config = WKWebViewConfiguration()
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = pagePrefs

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), configuration: config)
        webView.navigationDelegate = self
        self.view = webView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let html = pendingHTML {
            pendingHTML = nil
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown: String
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                markdown = utf8
            } else {
                let data = try Data(contentsOf: url)
                markdown = String(data: data, encoding: .macOSRoman) ?? ""
            }
            let baseURL = url.deletingLastPathComponent()
            let html = MarkdownRenderer.render(markdown, baseURL: baseURL)
            pendingHTML = html
            view.needsLayout = true
            handler(nil)
        } catch {
            handler(error)
        }
    }
}

extension PreviewViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        switch navigationAction.navigationType {
        case .other:
            // Allow the initial loadHTMLString call
            decisionHandler(.allow)
        case .linkActivated:
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        default:
            decisionHandler(.cancel)
        }
    }
}
