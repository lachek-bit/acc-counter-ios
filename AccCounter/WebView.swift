import SwiftUI
import WebKit

/// 全屏 WKWebView，加载打包在 App 内的 index.html
/// 用自定义 scheme（app://）而不是 file://，这样 localStorage 才有正常的 origin，数据能持久保存
struct ContentView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.setURLSchemeHandler(AssetHandler(), forURLScheme: "app")
        conf.allowsInlineMediaPlayback = true
        conf.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(frame: .zero, configuration: conf)
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 0.96, green: 0.965, blue: 0.973, alpha: 1)
        wv.scrollView.bounces = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.allowsBackForwardNavigationGestures = false
        wv.allowsLinkPreview = false

        if let url = URL(string: "app://local/index.html") {
            wv.load(URLRequest(url: url))
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// 从 App bundle 读文件，喂给 app:// 请求
final class AssetHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(NSError(domain: "app", code: 400)); return
        }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let nsPath = path as NSString
        let name = nsPath.deletingPathExtension
        let ext = nsPath.pathExtension

        guard let file = Bundle.main.path(forResource: name, ofExtension: ext) else {
            task.didFailWithError(NSError(domain: "app", code: 404,
                                          userInfo: [NSLocalizedDescriptionKey: "not found: \(path)"]))
            return
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            let resp = HTTPURLResponse(url: url, statusCode: 200,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: [
                                        "Content-Type": Self.mime(ext) + "; charset=utf-8",
                                        "Cache-Control": "no-cache",
                                        "Access-Control-Allow-Origin": "*"
                                       ])!
            task.didReceive(resp)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    static func mime(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "png": return "image/png"
        case "svg": return "image/svg+xml"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }
}
