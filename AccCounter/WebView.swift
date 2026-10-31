import SwiftUI
import WebKit

/// 全屏 WKWebView，加载打包在 App 内的 index.html
/// 用自定义 scheme（app://）而不是 file://，这样页面有正常 origin
/// 数据不依赖 localStorage（WKWebView 写盘是异步的，App 被杀会丢），
/// 而是启动时把原生文件内容注入 window.__NATIVE_DB__，改动通过 messageHandler 同步写回文件
struct ContentView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let conf = WKWebViewConfiguration()
        conf.setURLSchemeHandler(AssetHandler(), forURLScheme: "app")
        conf.allowsInlineMediaPlayback = true
        conf.mediaTypesRequiringUserActionForPlayback = []

        let uc = WKUserContentController()
        uc.add(context.coordinator, name: "save")
        let stored = DataStore.shared.readString()
        let js = "window.__NATIVE_DB__ = \(Self.jsLiteral(stored));"
        uc.addUserScript(WKUserScript(source: js,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: true))
        conf.userContentController = uc

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

    /// 把任意字符串安全地转成 JS 字符串字面量
    static func jsLiteral(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              let arr = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(arr.dropFirst().dropLast())   // ["x"] -> "x"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ uc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "save", let json = message.body as? String else { return }
            DataStore.shared.write(json)
        }
    }
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

        guard let file = Bundle.main.path(forResource: name, ofType: ext) else {
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
