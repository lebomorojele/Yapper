import Foundation

enum AppResourceLocator {
    static func url(forResource name: String, withExtension ext: String?, subdirectory: String? = nil) -> URL? {
        for root in resourceRoots {
            let directory = subdirectory.map { root.appendingPathComponent($0, isDirectory: true) } ?? root
            let filename = ext.map { "\(name).\($0)" } ?? name
            let url = directory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private static var resourceRoots: [URL] {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return [Bundle.main.resourceURL].compactMap { $0 }
        }

        return [Bundle.module.resourceURL].compactMap { $0 }
    }
}
