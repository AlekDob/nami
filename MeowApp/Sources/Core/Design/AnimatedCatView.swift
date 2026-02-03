import SwiftUI

// MARK: - Animated Cat View

struct AnimatedCatView: View {
    let mood: CatMood
    let size: CatSize

    enum CatSize: Sendable {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 60
            case .large: return 100
            }
        }
    }

    @State private var breathScale: CGFloat = 1.0
    @State private var pupilOffsetX: CGFloat = 0
    @State private var blinkProgress: CGFloat = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var happyBounce: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CatShape(
            mood: mood,
            blinkProgress: blinkProgress,
            pupilOffsetX: pupilOffsetX
        )
        .frame(width: size.dimension, height: size.dimension)
        .scaleEffect(breathScale * happyBounce)
        .offset(x: shakeOffset)
        .shadow(color: glowColor.opacity(0.4), radius: glowRadius)
        .onAppear { startAnimations() }
        .onChange(of: mood) { startAnimations() }
    }

    // MARK: - Glow

    private var glowColor: Color {
        switch mood {
        case .idle: return MeowTheme.accent
        case .thinking: return MeowTheme.purple
        case .happy: return MeowTheme.orange
        case .sleeping: return MeowTheme.accent.opacity(0.3)
        case .error: return MeowTheme.red
        }
    }

    private var glowRadius: CGFloat {
        size == .large ? 12 : (size == .medium ? 8 : 4)
    }

    // MARK: - Animations

    private func startAnimations() {
        guard !reduceMotion else { return }
        resetState()

        switch mood {
        case .idle: startIdle()
        case .thinking: startThinking()
        case .happy: startHappy()
        case .sleeping: startSleeping()
        case .error: startError()
        }
    }

    private func resetState() {
        breathScale = 1.0
        pupilOffsetX = 0
        blinkProgress = 0
        shakeOffset = 0
        happyBounce = 1.0
    }

    private func startIdle() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            breathScale = 0.97
        }
        startBlinking()
    }

    private func startThinking() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pupilOffsetX = 1.0
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breathScale = 0.98
        }
    }

    private func startHappy() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            breathScale = 0.97
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            happyBounce = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                happyBounce = 1.0
            }
        }
    }

    private func startSleeping() {
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            breathScale = 0.94
        }
        blinkProgress = 1.0
    }

    private func startError() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.2).repeatCount(4, autoreverses: true)) {
            shakeOffset = 4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                shakeOffset = 0
            }
        }
    }

    private func startBlinking() {
        let delay = Double.random(in: 2.5...4.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard mood == .idle else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                blinkProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    blinkProgress = 0
                }
                startBlinking()
            }
        }
    }
}

// MARK: - Cat Shape (Pure SwiftUI Drawing)

private struct CatShape: View {
    let mood: CatMood
    let blinkProgress: CGFloat
    let pupilOffsetX: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2

            // -- Ears --
            drawEar(context: context, tip: CGPoint(x: cx - w * 0.28, y: h * 0.08),
                     base1: CGPoint(x: cx - w * 0.38, y: cy - h * 0.05),
                     base2: CGPoint(x: cx - w * 0.10, y: cy - h * 0.08),
                     size: size)
            drawEar(context: context, tip: CGPoint(x: cx + w * 0.28, y: h * 0.08),
                     base1: CGPoint(x: cx + w * 0.10, y: cy - h * 0.08),
                     base2: CGPoint(x: cx + w * 0.38, y: cy - h * 0.05),
                     size: size)

            // -- Head --
            let headRect = CGRect(
                x: cx - w * 0.38,
                y: cy - h * 0.22,
                width: w * 0.76,
                height: h * 0.55
            )
            let headPath = Ellipse().path(in: headRect)
            context.fill(headPath, with: .color(headFill))
            context.stroke(headPath, with: .color(headStroke), lineWidth: 1.2)

            // -- Eyes --
            let eyeY = cy + h * 0.02
            let eyeSpacing = w * 0.14
            let eyeW = w * 0.11
            let eyeH: CGFloat

            if mood == .happy {
                eyeH = w * 0.03
            } else if mood == .error {
                eyeH = w * 0.12
            } else {
                eyeH = w * 0.09
            }

            let leftEyeCenter = CGPoint(x: cx - eyeSpacing, y: eyeY)
            let rightEyeCenter = CGPoint(x: cx + eyeSpacing, y: eyeY)

            drawEye(context: context, center: leftEyeCenter, w: eyeW, h: eyeH, size: size)
            drawEye(context: context, center: rightEyeCenter, w: eyeW, h: eyeH, size: size)

            // -- Pupils (only when eyes are open) --
            if mood != .happy && mood != .sleeping && blinkProgress < 0.8 {
                let pupilR = w * 0.025
                let pupilShift = pupilOffsetX * w * 0.03

                let leftPupil = Circle().path(in: CGRect(
                    x: leftEyeCenter.x - pupilR + pupilShift,
                    y: leftEyeCenter.y - pupilR,
                    width: pupilR * 2, height: pupilR * 2
                ))
                let rightPupil = Circle().path(in: CGRect(
                    x: rightEyeCenter.x - pupilR + pupilShift,
                    y: rightEyeCenter.y - pupilR,
                    width: pupilR * 2, height: pupilR * 2
                ))
                context.fill(leftPupil, with: .color(pupilColor))
                context.fill(rightPupil, with: .color(pupilColor))
            }

            // -- Eyelids (blink) --
            if blinkProgress > 0 {
                let lidH = eyeH * blinkProgress
                let leftLid = Ellipse().path(in: CGRect(
                    x: leftEyeCenter.x - eyeW, y: leftEyeCenter.y - eyeH,
                    width: eyeW * 2, height: lidH * 2
                ))
                let rightLid = Ellipse().path(in: CGRect(
                    x: rightEyeCenter.x - eyeW, y: rightEyeCenter.y - eyeH,
                    width: eyeW * 2, height: lidH * 2
                ))
                context.fill(leftLid, with: .color(headFill))
                context.fill(rightLid, with: .color(headFill))
            }

            // -- Nose --
            let noseY = eyeY + h * 0.10
            let noseSize = w * 0.025
            var nosePath = Path()
            nosePath.move(to: CGPoint(x: cx, y: noseY - noseSize))
            nosePath.addLine(to: CGPoint(x: cx - noseSize, y: noseY + noseSize * 0.5))
            nosePath.addLine(to: CGPoint(x: cx + noseSize, y: noseY + noseSize * 0.5))
            nosePath.closeSubpath()
            context.fill(nosePath, with: .color(noseColor))

            // -- Mouth --
            let mouthY = noseY + noseSize * 0.5
            var mouthPath = Path()
            mouthPath.move(to: CGPoint(x: cx, y: mouthY))
            mouthPath.addQuadCurve(
                to: CGPoint(x: cx - w * 0.06, y: mouthY + h * 0.04),
                control: CGPoint(x: cx - w * 0.03, y: mouthY + h * 0.03)
            )
            mouthPath.move(to: CGPoint(x: cx, y: mouthY))
            mouthPath.addQuadCurve(
                to: CGPoint(x: cx + w * 0.06, y: mouthY + h * 0.04),
                control: CGPoint(x: cx + w * 0.03, y: mouthY + h * 0.03)
            )
            context.stroke(mouthPath, with: .color(headStroke.opacity(0.5)), lineWidth: 0.8)

            // -- Whiskers --
            let whiskerY = noseY + h * 0.02
            let whiskerLen = w * 0.22
            drawWhisker(context: context,
                       from: CGPoint(x: cx - w * 0.12, y: whiskerY),
                       to: CGPoint(x: cx - w * 0.12 - whiskerLen, y: whiskerY - h * 0.02),
                       size: size)
            drawWhisker(context: context,
                       from: CGPoint(x: cx - w * 0.12, y: whiskerY + h * 0.02),
                       to: CGPoint(x: cx - w * 0.12 - whiskerLen, y: whiskerY + h * 0.04),
                       size: size)
            drawWhisker(context: context,
                       from: CGPoint(x: cx + w * 0.12, y: whiskerY),
                       to: CGPoint(x: cx + w * 0.12 + whiskerLen, y: whiskerY - h * 0.02),
                       size: size)
            drawWhisker(context: context,
                       from: CGPoint(x: cx + w * 0.12, y: whiskerY + h * 0.02),
                       to: CGPoint(x: cx + w * 0.12 + whiskerLen, y: whiskerY + h * 0.04),
                       size: size)
        }
    }

    // MARK: - Drawing Helpers

    private func drawEar(
        context: GraphicsContext,
        tip: CGPoint,
        base1: CGPoint,
        base2: CGPoint,
        size: CGSize
    ) {
        var path = Path()
        path.move(to: base1)
        path.addLine(to: tip)
        path.addLine(to: base2)
        path.closeSubpath()
        context.fill(path, with: .color(headFill))
        context.stroke(path, with: .color(headStroke), lineWidth: 1.2)

        // Inner ear
        let innerTip = CGPoint(
            x: tip.x,
            y: tip.y + size.height * 0.04
        )
        let innerBase1 = CGPoint(
            x: base1.x + (tip.x - base1.x) * 0.3,
            y: base1.y + (tip.y - base1.y) * 0.3
        )
        let innerBase2 = CGPoint(
            x: base2.x + (tip.x - base2.x) * 0.3,
            y: base2.y + (tip.y - base2.y) * 0.3
        )
        var innerPath = Path()
        innerPath.move(to: innerBase1)
        innerPath.addLine(to: innerTip)
        innerPath.addLine(to: innerBase2)
        innerPath.closeSubpath()
        context.fill(innerPath, with: .color(earInnerColor))
    }

    private func drawEye(
        context: GraphicsContext,
        center: CGPoint,
        w: CGFloat,
        h: CGFloat,
        size: CGSize
    ) {
        let eyeRect = CGRect(
            x: center.x - w,
            y: center.y - h,
            width: w * 2,
            height: h * 2
        )
        let eyePath = Ellipse().path(in: eyeRect)
        context.fill(eyePath, with: .color(eyeColor))
    }

    private func drawWhisker(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        size: CGSize
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(headStroke.opacity(0.3)), lineWidth: 0.6)
    }

    // MARK: - Colors

    private var headFill: Color {
        Color(hex: 0x0D1F3C)
    }

    private var headStroke: Color {
        MeowTheme.accent.opacity(0.5)
    }

    private var earInnerColor: Color {
        MeowTheme.accent.opacity(0.08)
    }

    private var eyeColor: Color {
        switch mood {
        case .idle, .thinking: return MeowTheme.accent.opacity(0.7)
        case .happy: return MeowTheme.orange.opacity(0.8)
        case .sleeping: return MeowTheme.accent.opacity(0.3)
        case .error: return MeowTheme.red.opacity(0.7)
        }
    }

    private var pupilColor: Color {
        Color.white.opacity(0.9)
    }

    private var noseColor: Color {
        MeowTheme.accent.opacity(0.4)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        ForEach(CatMood.allCases, id: \.self) { mood in
            VStack(spacing: 8) {
                AnimatedCatView(mood: mood, size: .large)
                Text(mood.rawValue)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    .padding()
    .background(Color(hex: 0x0A1628))
}
