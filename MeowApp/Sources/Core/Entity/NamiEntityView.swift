import SwiftUI

// MARK: - Entity State

enum NamiState: Equatable {
    case idle
    case thinking
    case speaking
    case listening
    case touched(CGPoint)

    var waveSpeed: Double {
        switch self {
        case .idle: return 2.0
        case .thinking: return 0.8
        case .speaking: return 1.0
        case .listening: return 1.5
        case .touched: return 0.5
        }
    }

    var amplitudeMultiplier: Double {
        switch self {
        case .idle: return 1.0
        case .thinking: return 1.3
        case .speaking: return 1.5
        case .listening: return 1.2
        case .touched: return 1.8
        }
    }
}

// MARK: - Face Expression (Kawaii Style)

struct NamiExpression {
    let eyeStyle: EyeStyle        // Style of eye curves
    let eyeScale: CGFloat         // Size multiplier for eyes
    let mouthWidth: CGFloat       // 0 = closed, 1 = wide
    let mouthCurve: CGFloat       // -1 = frown, 0 = neutral, 1 = big smile
    let mouthOpen: CGFloat        // 0 = closed line, 1 = open oval

    enum EyeStyle {
        case happy       // ^_^ curved up (happy/closed)
        case neutral     // - - straight lines
        case wide        // o_o round open eyes
        case curious     // ^.^ one up one neutral
    }

    static func forState(_ state: NamiState, time: Double) -> NamiExpression {
        switch state {
        case .idle:
            return NamiExpression(
                eyeStyle: .happy,
                eyeScale: 1.0,
                mouthWidth: 0.8,
                mouthCurve: 0.7,
                mouthOpen: 0
            )
        case .thinking:
            return NamiExpression(
                eyeStyle: .neutral,
                eyeScale: 0.8,
                mouthWidth: 0.4,
                mouthCurve: 0.1,
                mouthOpen: 0
            )
        case .speaking:
            let mouthAnim = abs(sin(time * 8)) * 0.7
            return NamiExpression(
                eyeStyle: .happy,
                eyeScale: 0.9,
                mouthWidth: 0.6,
                mouthCurve: 0.5,
                mouthOpen: mouthAnim
            )
        case .listening:
            return NamiExpression(
                eyeStyle: .wide,
                eyeScale: 1.1,
                mouthWidth: 0.5,
                mouthCurve: 0.3,
                mouthOpen: 0.15
            )
        case .touched:
            return NamiExpression(
                eyeStyle: .happy,
                eyeScale: 1.2,
                mouthWidth: 1.0,
                mouthCurve: 1.0,
                mouthOpen: 0.3
            )
        }
    }
}

// MARK: - Nami Entity View (Wave Form)

struct NamiEntityView: View {
    let props: NamiProps
    let state: NamiState
    let level: Int
    let size: CGFloat
    var audioLevel: CGFloat = 0.0
    var disableTouch: Bool = false

    @State private var touchPoint: CGPoint? = nil
    @State private var smoothedAudioLevel: CGFloat = 0.0
    @State private var lastBlinkTime: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let baseRadius = min(canvasSize.width, canvasSize.height) / 2 * 0.7

                // Draw glow layer (if level >= 3)
                if level >= 3 {
                    drawGlow(context: context, center: center, radius: baseRadius, time: time)
                }

                // Draw ripples (if level >= 5)
                if level >= 5 {
                    drawRipples(context: context, center: center, radius: baseRadius, time: time)
                }

                // Draw spray particles (if level >= 7)
                if level >= 7 {
                    drawSpray(context: context, center: center, radius: baseRadius, time: time)
                }

                // Draw main wave form
                drawWaveForm(context: context, center: center, radius: baseRadius, time: time)

                // Draw face (eyes + mouth)
                let expression = NamiExpression.forState(state, time: time)
                let blinkValue = calculateBlink(time: time)
                drawFace(
                    context: context,
                    center: center,
                    radius: baseRadius,
                    expression: expression,
                    blink: blinkValue,
                    time: time
                )
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(disableTouch ? nil : dragGesture)
        .onChange(of: audioLevel) { _, newValue in
            withAnimation(.linear(duration: 0.1)) {
                smoothedAudioLevel = newValue
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                touchPoint = value.location
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.5)) {
                    touchPoint = nil
                }
            }
    }

    // MARK: - Wave Form Drawing

    private func drawWaveForm(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        let peaks = props.formStyle.wavePeaks + (level / 2)
        let amplitude = baseAmplitude * state.amplitudeMultiplier * props.formStyle.amplitudeScale
        let audioBoost = 1.0 + smoothedAudioLevel * 0.4
        let speed = state.waveSpeed

        var path = Path()
        let points = 64 // High resolution for smooth waves

        var pathPoints: [CGPoint] = []

        for i in 0..<points {
            let angle = (Double(i) / Double(points)) * 2 * .pi

            // Wave function: multiple sine waves create organic wave shape
            let wave1 = sin(angle * Double(peaks) + time / speed) * amplitude * 0.6
            let wave2 = sin(angle * Double(peaks + 1) - time / speed * 1.3) * amplitude * 0.3
            let wave3 = sin(angle * Double(peaks * 2) + time / speed * 0.7) * amplitude * 0.1

            var r = radius * (1.0 + (wave1 + wave2 + wave3) * audioBoost)

            // Touch deformation - creates ripple from touch point
            if let touch = touchPoint {
                let touchAngle = atan2(touch.y - center.y, touch.x - center.x)
                let angleDiff = abs(angle - touchAngle)
                let touchInfluence = max(0, 1.0 - angleDiff / .pi)
                r += radius * 0.25 * touchInfluence * sin(time * 8)
            }

            // Speaking: more pronounced wave movement
            if case .speaking = state {
                let speakWave = sin(time * 10 + angle * 3) * smoothedAudioLevel * 0.15
                r += radius * speakWave
            }

            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            pathPoints.append(CGPoint(x: x, y: y))
        }

        // Create smooth bezier path
        path = createSmoothPath(points: pathPoints, smoothness: props.formStyle.smoothness)

        // Fill with gradient
        context.fill(path, with: .linearGradient(
            Gradient(colors: [props.dominantSwiftUIColor, props.secondarySwiftUIColor]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
        ))
    }

    private func drawGlow(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        let glowRadius = radius * (1.4 + 0.1 * sin(time * 1.5))
        let glowIntensity = 0.35 + audioLevel * 0.25

        let glowPath = Path(ellipseIn: CGRect(
            x: center.x - glowRadius,
            y: center.y - glowRadius,
            width: glowRadius * 2,
            height: glowRadius * 2
        ))

        context.fill(glowPath, with: .radialGradient(
            Gradient(colors: [
                props.dominantSwiftUIColor.opacity(glowIntensity),
                props.dominantSwiftUIColor.opacity(0)
            ]),
            center: center,
            startRadius: 0,
            endRadius: glowRadius
        ))
    }

    private func drawRipples(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        let rippleCount = 3

        for i in 0..<rippleCount {
            let phase = (time + Double(i) * 0.5).truncatingRemainder(dividingBy: 2.0)
            let rippleRadius = radius * (1.2 + phase * 0.5)
            let opacity = max(0, 0.3 - phase * 0.15)

            let ripplePath = Path(ellipseIn: CGRect(
                x: center.x - rippleRadius,
                y: center.y - rippleRadius,
                width: rippleRadius * 2,
                height: rippleRadius * 2
            ))

            context.stroke(
                ripplePath,
                with: .color(props.dominantSwiftUIColor.opacity(opacity)),
                lineWidth: 2
            )
        }
    }

    private func drawSpray(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        let sprayCount = level * 2

        for i in 0..<sprayCount {
            let baseAngle = (Double(i) / Double(sprayCount)) * 2 * .pi
            let angle = baseAngle + sin(time * 2 + Double(i)) * 0.3
            let distance = radius * (1.3 + sin(time * 3 + Double(i) * 2) * 0.2)

            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance

            let dropSize: CGFloat = 2 + CGFloat(i % 3)
            let opacity = 0.4 + 0.3 * sin(time * 4 + Double(i))

            let dropPath = Path(ellipseIn: CGRect(
                x: x - dropSize,
                y: y - dropSize,
                width: dropSize * 2,
                height: dropSize * 2
            ))

            context.fill(dropPath, with: .color(props.dominantSwiftUIColor.opacity(opacity)))
        }
    }

    // MARK: - Face Drawing (Curved lines like emoji reference)

    private func drawFace(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        expression: NamiExpression,
        blink: CGFloat,
        time: Double
    ) {
        let faceScale = radius * 0.55
        let eyeSpacing = faceScale * 0.4
        let eyeY = center.y - faceScale * 0.2  // Eyes higher up
        let mouthY = center.y + faceScale * 0.55  // Mouth more spaced from eyes

        // Left eye - curved line
        drawCurvedEye(
            context: context,
            center: CGPoint(x: center.x - eyeSpacing, y: eyeY),
            size: faceScale * 0.22 * expression.eyeScale,
            style: expression.eyeStyle,
            blink: blink
        )

        // Right eye - curved line
        drawCurvedEye(
            context: context,
            center: CGPoint(x: center.x + eyeSpacing, y: eyeY),
            size: faceScale * 0.22 * expression.eyeScale,
            style: expression.eyeStyle,
            blink: blink
        )

        // Mouth - simple smile curve (width matches eye spacing)
        drawCurvedMouth(
            context: context,
            center: CGPoint(x: center.x, y: mouthY),
            size: faceScale * 0.5,
            expression: expression,
            targetWidth: eyeSpacing * 2  // Same width as distance between eyes
        )
    }

    private func drawCurvedEye(
        context: GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        style: NamiExpression.EyeStyle,
        blink: CGFloat
    ) {
        let lineWidth = size * 0.35
        var eyePath = Path()

        // During blink - horizontal line
        if blink < 0.3 {
            eyePath.move(to: CGPoint(x: center.x - size, y: center.y))
            eyePath.addLine(to: CGPoint(x: center.x + size, y: center.y))
            context.stroke(eyePath, with: .color(.white), lineWidth: lineWidth)
            return
        }

        switch style {
        case .happy:
            // ⌒ style - curved DOWN (happy/closed eyes like emoji ref)
            eyePath.move(to: CGPoint(x: center.x - size, y: center.y - size * 0.3))
            eyePath.addQuadCurve(
                to: CGPoint(x: center.x + size, y: center.y - size * 0.3),
                control: CGPoint(x: center.x, y: center.y + size * 0.8)
            )
            context.stroke(eyePath, with: .color(.white), lineWidth: lineWidth)

        case .neutral:
            // Horizontal line for thinking
            eyePath.move(to: CGPoint(x: center.x - size, y: center.y))
            eyePath.addLine(to: CGPoint(x: center.x + size, y: center.y))
            context.stroke(eyePath, with: .color(.white), lineWidth: lineWidth)

        case .wide:
            // Small circle outline for surprised/listening
            let eyeRect = CGRect(
                x: center.x - size * 0.7,
                y: center.y - size * 0.7,
                width: size * 1.4,
                height: size * 1.4
            )
            eyePath.addEllipse(in: eyeRect)
            context.stroke(eyePath, with: .color(.white), lineWidth: lineWidth * 0.8)

        case .curious:
            // Same curve as happy
            eyePath.move(to: CGPoint(x: center.x - size, y: center.y - size * 0.2))
            eyePath.addQuadCurve(
                to: CGPoint(x: center.x + size, y: center.y - size * 0.2),
                control: CGPoint(x: center.x, y: center.y + size * 0.6)
            )
            context.stroke(eyePath, with: .color(.white), lineWidth: lineWidth)
        }
    }

    private func drawCurvedMouth(
        context: GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        expression: NamiExpression,
        targetWidth: CGFloat
    ) {
        // Use targetWidth (eye spacing) as base, scaled by expression
        let mouthWidth = targetWidth * expression.mouthWidth
        let curveAmount = expression.mouthCurve * size * 0.4
        let lineWidth = size * 0.18

        var mouthPath = Path()

        if expression.mouthOpen > 0.15 {
            // Open mouth - stroke oval outline (not filled)
            let openHeight = size * 0.3 * expression.mouthOpen
            let mouthRect = CGRect(
                x: center.x - mouthWidth * 0.35,
                y: center.y - openHeight / 2,
                width: mouthWidth * 0.7,
                height: openHeight + curveAmount * 0.2
            )
            mouthPath.addEllipse(in: mouthRect)
            context.stroke(mouthPath, with: .color(.white), lineWidth: lineWidth * 0.8)
        } else {
            // Simple smile curve - stroke only
            mouthPath.move(to: CGPoint(x: center.x - mouthWidth / 2, y: center.y))
            mouthPath.addQuadCurve(
                to: CGPoint(x: center.x + mouthWidth / 2, y: center.y),
                control: CGPoint(x: center.x, y: center.y + curveAmount)
            )
            context.stroke(mouthPath, with: .color(.white), lineWidth: lineWidth)
        }
    }

    private func calculateBlink(time: Double) -> CGFloat {
        let blinkInterval = 4.0
        let blinkDuration = 0.15
        let timeMod = time.truncatingRemainder(dividingBy: blinkInterval)

        if timeMod < blinkDuration {
            return CGFloat(1.0 - (timeMod / blinkDuration))
        } else if timeMod < blinkDuration * 2 {
            return CGFloat((timeMod - blinkDuration) / blinkDuration)
        }
        return 1.0
    }

    // MARK: - Helpers

    private var baseAmplitude: Double {
        switch level {
        case 1...2: return 0.08
        case 3...4: return 0.12
        case 5...6: return 0.16
        case 7...8: return 0.20
        default: return 0.24
        }
    }

    private func createSmoothPath(points: [CGPoint], smoothness: Double) -> Path {
        guard points.count > 2 else { return Path() }

        var path = Path()
        path.move(to: points[0])

        for i in 0..<points.count {
            let p0 = points[(i - 1 + points.count) % points.count]
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            let p3 = points[(i + 2) % points.count]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * smoothness / 6,
                y: p1.y + (p2.y - p0.y) * smoothness / 6
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * smoothness / 6,
                y: p2.y - (p3.y - p1.y) * smoothness / 6
            )

            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            NamiEntityView(
                props: NamiProps(
                    name: "Nami",
                    personality: .donna,
                    dominantColor: "#00BFFF",
                    secondaryColor: "#0077BE",
                    formStyle: .wave,
                    voiceId: "Sarah",
                    language: "it"
                ),
                state: .idle,
                level: 5,
                size: 200
            )

            NamiEntityView(
                props: .default,
                state: .speaking,
                level: 8,
                size: 150,
                audioLevel: 0.5
            )
        }
    }
}
