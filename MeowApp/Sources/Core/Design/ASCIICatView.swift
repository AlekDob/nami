import SwiftUI

enum CatMood: String, CaseIterable, Sendable {
    case idle
    case thinking
    case happy
    case sleeping
    case error

    var ascii: String {
        switch self {
        case .idle:
            return """
              /\\_/\\
             ( o.o )
              > ^ <
            """
        case .thinking:
            return """
              /\\_/\\
             ( -.- )  ...
              > ^ <
            """
        case .happy:
            return """
              /\\_/\\
             ( ^.^ )
              > ^ <  ~
            """
        case .sleeping:
            return """
              /\\_/\\
             ( -.- ) zzZ
              > ^ <
            """
        case .error:
            return """
              /\\_/\\
             ( x.x )  !
              > ^ <
            """
        }
    }

    var compactAscii: String {
        switch self {
        case .idle:     return "(o.o)"
        case .thinking: return "(-.-) ..."
        case .happy:    return "(^.^)"
        case .sleeping: return "(-.-) z"
        case .error:    return "(x.x) !"
        }
    }
}

struct ASCIICatView: View {
    let mood: CatMood
    let size: CatSize

    @Environment(\.colorScheme) private var colorScheme
    @State private var cursorVisible = true

    enum CatSize: Sendable {
        case small, medium, large

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 13
            case .large: return 16
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(size == .small ? mood.compactAscii : mood.ascii)
                .font(.system(size: size.fontSize, design: .monospaced))
                .foregroundColor(textColor)
                .lineSpacing(2)

            if mood == .thinking {
                Text("_")
                    .font(.system(size: size.fontSize, design: .monospaced))
                    .foregroundColor(MeowTheme.accent)
                    .opacity(cursorVisible ? 1 : 0)
                    .onAppear { startBlink() }
            }
        }
    }

    private var textColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.textSecondary
            : MeowTheme.Light.textSecondary
    }

    private func startBlink() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            cursorVisible = false
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(CatMood.allCases, id: \.self) { mood in
            ASCIICatView(mood: mood, size: .large)
        }
    }
    .padding()
}
