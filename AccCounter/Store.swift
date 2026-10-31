import Foundation

/// 数据存到 App 沙盒的 Documents 目录，原子写入，App 被杀也不会丢
final class DataStore {
    static let shared = DataStore()

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("acc_data.json")
    }()

    var path: String { fileURL.path }

    func readString() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    func write(_ s: String) {
        do {
            try s.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("[DataStore] 写入失败: \(error)")
        }
    }
}
