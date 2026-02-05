import SwiftUI

// MARK: - Nami Properties

/// Customizable properties for the Nami entity (波 = wave)
/// Parsed from SOUL.md props section or set via Soul editor
struct NamiProps: Codable, Equatable {
    var name: String
    var personality: Personality
    var dominantColor: String  // Hex color
    var secondaryColor: String // Hex color
    var formStyle: FormStyle
    var voiceId: String
    var language: String

    // MARK: - Nested Types

    enum Personality: String, Codable, CaseIterable {
        case donna = "donna"
        case uomo = "uomo"
        case neutro = "neutro"

        var displayName: String {
            switch self {
            case .donna: return "Femminile"
            case .uomo: return "Maschile"
            case .neutro: return "Neutro"
            }
        }
    }

    enum FormStyle: String, Codable, CaseIterable {
        case wave = "wave"          // Primary wave form
        case ripple = "ripple"      // Concentric ripples
        case flow = "flow"          // Flowing stream

        var displayName: String {
            switch self {
            case .wave: return "Onda"
            case .ripple: return "Increspatura"
            case .flow: return "Flusso"
            }
        }

        /// Number of wave peaks
        var wavePeaks: Int {
            switch self {
            case .wave: return 3
            case .ripple: return 5
            case .flow: return 4
            }
        }

        /// How smooth the wave curves are
        var smoothness: Double {
            switch self {
            case .wave: return 0.8
            case .ripple: return 0.5
            case .flow: return 0.9
            }
        }

        /// Amplitude multiplier
        var amplitudeScale: Double {
            switch self {
            case .wave: return 1.0
            case .ripple: return 0.6
            case .flow: return 0.8
            }
        }
    }

    // MARK: - Defaults

    static let `default` = NamiProps(
        name: "Nami",
        personality: .neutro,
        dominantColor: "#00BFFF",   // Deep sky blue - ocean wave
        secondaryColor: "#0077BE",  // Ocean blue
        formStyle: .wave,
        voiceId: "Sarah",
        language: "it"
    )

    // MARK: - Color Helpers

    var dominantSwiftUIColor: Color {
        Color(hex: dominantColor) ?? .cyan
    }

    var secondarySwiftUIColor: Color {
        Color(hex: secondaryColor) ?? .blue
    }

    /// Gradient for the entity
    var gradient: LinearGradient {
        LinearGradient(
            colors: [dominantSwiftUIColor, secondarySwiftUIColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Radial gradient for glow effect
    var glowGradient: RadialGradient {
        RadialGradient(
            colors: [dominantSwiftUIColor.opacity(0.6), dominantSwiftUIColor.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        #if os(macOS)
        let nsColor = NSColor(self)
        guard let converted = nsColor.usingColorSpace(.sRGB) else {
            return "#000000"
        }
        let r = Int(converted.redComponent * 255)
        let g = Int(converted.greenComponent * 255)
        let b = Int(converted.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #endif
    }
}

// MARK: - Persistence

extension NamiProps {
    private static let storageKey = "com.nami.props"

    static func load() -> NamiProps {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let props = try? JSONDecoder().decode(NamiProps.self, from: data) else {
            return .default
        }
        return props
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
