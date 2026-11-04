import AppKit
import SwiftUI

/// Paleta do metronoguty.css (Apple System Dark).
enum Theme {
    static let bg = Color.black
    static let card = Color(hex: 0x1C1C1E)
    static let cardElevated = Color(hex: 0x2C2C2E)
    static let fill = Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.18)
    static let fillSecondary = Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.28)
    static let separator = Color(red: 84 / 255, green: 84 / 255, blue: 88 / 255).opacity(0.32)
    static let separatorSubtle = Color.white.opacity(0.08)
    static let chipActive = Color(hex: 0x636366)

    static let blue = Color(hex: 0x0A84FF)
    static let blueMuted = Color(hex: 0x0A84FF).opacity(0.15)
    static let cyan = Color(hex: 0x64D2FF)
    static let red = Color(hex: 0xFF453A)
    static let green = Color(hex: 0x30D158)
    static let orange = Color(hex: 0xFF9F0A)

    static let labelPrimary = Color.white
    static let labelSecondary = Color(hex: 0x8E8E93)
    static let labelTertiary = Color(hex: 0x636366)

    static let radiusCard: CGFloat = 20
    static let radiusControl: CGFloat = 12
    static let radiusSmall: CGFloat = 8
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Renderiza os SVGs originais do site como imagens template (tingíveis).
struct SVGIcon: View {
    let svg: String
    var size: CGSize? = nil

    private static var cache: [String: NSImage] = [:]

    private var image: NSImage {
        if let img = Self.cache[svg] { return img }
        let img = NSImage(data: Data(svg.utf8)) ?? NSImage()
        img.isTemplate = true
        Self.cache[svg] = img
        return img
    }

    var body: some View {
        let img = image
        Image(nsImage: img)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size?.width ?? img.size.width, height: size?.height ?? img.size.height)
    }
}

enum Logo {
    static let image: NSImage = {
        if let url = Bundle.main.url(forResource: "logo", withExtension: "jpg"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSApplication.shared.applicationIconImage
    }()
}
