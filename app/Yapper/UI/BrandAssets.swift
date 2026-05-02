import AppKit

enum BrandAssets {
    static func appIconImage(size: CGFloat? = nil) -> NSImage? {
        guard let url = AppResourceLocator.url(
            forResource: "AppIcon",
            withExtension: "png",
            subdirectory: "BrandResources"
        ),
        let image = NSImage(contentsOf: url) else {
            return nil
        }

        if let size {
            image.size = NSSize(width: size, height: size)
        }
        return image
    }
}
