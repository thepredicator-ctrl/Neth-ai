import SwiftUI

// MARK: - NethOrbView
// The signature animated visual centerpiece of Neth-AI.
// Pure SwiftUI Canvas + TimelineView. Each layer is a separate struct view
// with a minimal closure body for fast type-checking. Uses fill()/stroke()
// (simpler than draw()) and explicit Shading let-bindings to help inference.

struct NethOrbView: View {
    var state: OrbState
    var size: CGFloat = 280

    @State private var particleSeed: UInt64

    init(state: OrbState, size: CGFloat = 280) {
        self.state = state
        self.size = size
        _particleSeed = State(initialValue: UInt64(Date().timeIntervalSince1970 * 1000))
    }

    var body: some View {
        ZStack {
            HaloLayer(state: state, size: size)
            RingsLayer(state: state, size: size, seed: particleSeed)
            ParticlesLayer(state: state, size: size, seed: particleSeed)
            CoreLayer(state: state, size: size)
            HighlightLayer(size: size)
            if state == .generating || state == .listening {
                WaveformLayer(state: state, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Halo
private struct HaloLayer: View {
    let state: OrbState
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let period = NethTheme.pulseSpeed(for: state)
            let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / period)
            let glow = NethTheme.glowColor(for: state)
            let radius = size * (0.55 + 0.05 * pulse)
            HaloCanvas(radius: radius, glow: glow)
                .frame(width: size * 1.8, height: size * 1.8)
                .blur(radius: 14 + 6 * pulse)
                .opacity(0.85)
        }
    }
}

private struct HaloCanvas: View {
    let radius: CGFloat
    let glow: Color

    var body: some View {
        Canvas { gCtx, sz in
            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let rect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
            let path = Path(ellipseIn: rect)
            let grad = Gradient(colors: [
                glow.opacity(0.45),
                glow.opacity(0.18),
                glow.opacity(0.0)
            ])
            let shading: GraphicsContext.Shading = .radialGradient(
                grad, center: center, startRadius: 0, endRadius: radius
            )
            gCtx.fill(path, with: shading)
        }
    }
}

// MARK: - Rings
private struct RingsLayer: View {
    let state: OrbState
    let size: CGFloat
    let seed: UInt64

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let period = NethTheme.pulseSpeed(for: state)
            let glow = NethTheme.glowColor(for: state)
            RingsCanvas(t: t, period: period, glow: glow, baseR: size * 0.5)
                .frame(width: size, height: size)
        }
    }
}

private struct RingsCanvas: View {
    let t: Double
    let period: Double
    let glow: Color
    let baseR: CGFloat

    var body: some View {
        Canvas { gCtx, _ in
            for i in 0..<3 {
                drawRing(gCtx, i: i)
            }
        }
    }

    private func drawRing(_ gCtx: GraphicsContext, i: Int) {
        let center = CGPoint(x: baseR, y: baseR)
        let direction: Double = (i % 2 == 0) ? 1 : -1
        let rotation = t * direction * (0.4 + 0.15 * Double(i)) / period
        let radius = baseR * (0.78 + 0.08 * CGFloat(i))
        let arcLen: CGFloat = 0.7 + 0.2 * CGFloat(sin(t * 2 + Double(i)))
        let phase = rotation.truncatingRemainder(dividingBy: 2 * .pi)

        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        let path = Path(ellipseIn: rect)

        let strokeStyle = StrokeStyle(
            lineWidth: 1.4,
            lineCap: .round,
            dash: [radius * arcLen, radius * (2 - arcLen) * 1.6],
            dashPhase: CGFloat(phase) * radius
        )

        let grad = Gradient(colors: [glow.opacity(0.85), glow.opacity(0.15)])
        let shading: GraphicsContext.Shading = .linearGradient(
            grad,
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
        )
        gCtx.stroke(path, with: shading, style: strokeStyle)
    }
}

// MARK: - Particles
private struct ParticlesLayer: View {
    let state: OrbState
    let size: CGFloat
    let seed: UInt64

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let period = NethTheme.pulseSpeed(for: state)
            let glow = NethTheme.glowColor(for: state)
            let count: Int = {
                switch state {
                case .idle:        return 14
                case .listening:   return 24
                case .thinking:    return 32
                case .generating:  return 40
                case .complete:    return 18
                case .error:       return 12
                }
            }()
            ParticlesCanvas(t: t, period: period, glow: glow, baseR: size * 0.5,
                            seed: seed, count: count)
                .frame(width: size, height: size)
        }
    }
}

private struct ParticlesCanvas: View {
    let t: Double
    let period: Double
    let glow: Color
    let baseR: CGFloat
    let seed: UInt64
    let count: Int

    var body: some View {
        Canvas { gCtx, _ in
            let center = CGPoint(x: baseR, y: baseR)
            var rng = SeededRNG(seed: seed &+ UInt64(t * 4))
            for i in 0..<count {
                drawParticle(gCtx, i: i, center: center, rng: &rng)
            }
        }
    }

    private func drawParticle(_ gCtx: GraphicsContext, i: Int, center: CGPoint, rng: inout SeededRNG) {
        let angle = (Double(i) / Double(count)) * 2 * .pi + t / period
        let orbitR = baseR * (0.55 + 0.35 * rng.nextDouble())
        let wobble = sin(t * 1.6 + Double(i)) * 4
        let x = center.x + cos(angle) * (orbitR + CGFloat(wobble))
        let y = center.y + sin(angle) * (orbitR + CGFloat(wobble))
        let pSize: CGFloat = 1.6 + CGFloat(rng.nextDouble()) * 2.4
        let alpha = 0.5 + 0.5 * sin(t * 2 + Double(i) * 0.7)
        let rect = CGRect(x: x - pSize, y: y - pSize, width: pSize * 2, height: pSize * 2)
        let path = Path(ellipseIn: rect)
        let shading: GraphicsContext.Shading = .color(glow.opacity(Double(alpha)))
        gCtx.fill(path, with: shading)
    }
}

// MARK: - Core
private struct CoreLayer: View {
    let state: OrbState
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let period = NethTheme.pulseSpeed(for: state)
            let breath = 0.5 + 0.5 * sin(t * 2 * .pi / period)
            let scale = 0.92 + 0.06 * breath
            let glow = NethTheme.glowColor(for: state)
            let coreR = size * 0.4 * scale
            CoreCanvas(coreR: coreR, glow: glow)
                .frame(width: size, height: size)
        }
    }
}

private struct CoreCanvas: View {
    let coreR: CGFloat
    let glow: Color

    var body: some View {
        Canvas { gCtx, sz in
            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let rect = CGRect(x: center.x - coreR, y: center.y - coreR,
                              width: coreR * 2, height: coreR * 2)
            let path = Path(ellipseIn: rect)
            let grad = Gradient(colors: [
                Color.white.opacity(0.95),
                NethTheme.orangeBright,
                NethTheme.orange,
                NethTheme.orangeDeep,
                Color.black.opacity(0.9)
            ])
            let highlightCenter = CGPoint(x: center.x - coreR * 0.25, y: center.y - coreR * 0.25)
            let coreShading: GraphicsContext.Shading = .radialGradient(
                grad, center: highlightCenter, startRadius: 0, endRadius: coreR
            )
            gCtx.fill(path, with: coreShading)

            let inset = rect.insetBy(dx: coreR * 0.15, dy: coreR * 0.15)
            let rimPath = Path(ellipseIn: inset)
            let rimShading: GraphicsContext.Shading = .color(glow.opacity(0.25))
            gCtx.stroke(rimPath, with: rimShading, lineWidth: 1)
        }
    }
}

// MARK: - Highlight
private struct HighlightLayer: View {
    let size: CGFloat

    var body: some View {
        Canvas { gCtx, sz in
            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let r = size * 0.4 * 0.6
            let hx = center.x - r * 0.35
            let hy = center.y - r * 0.45
            let hw = r * 0.4
            let hh = r * 0.3
            let rect = CGRect(x: hx - hw, y: hy - hh, width: hw * 2, height: hh * 2)
            let path = Path(ellipseIn: rect)
            let grad = Gradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0)])
            let shading: GraphicsContext.Shading = .radialGradient(
                grad,
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: rect.width / 2
            )
            gCtx.fill(path, with: shading)
        }
        .frame(width: size, height: size)
        .blendMode(.screen)
    }
}

// MARK: - Waveform
private struct WaveformLayer: View {
    let state: OrbState
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let glow = NethTheme.glowColor(for: state)
            let amplitude: CGFloat = state == .generating ? 1.0 : 0.6
            WaveformCanvas(t: t, glow: glow, amplitude: amplitude)
                .frame(width: size, height: size)
        }
    }
}

private struct WaveformCanvas: View {
    let t: Double
    let glow: Color
    let amplitude: CGFloat

    var body: some View {
        Canvas { gCtx, sz in
            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let bars = 28
            let barWidth: CGFloat = 2
            let gap: CGFloat = 3
            let total = CGFloat(bars) * (barWidth + gap)
            let sx = center.x - total / 2
            for i in 0..<bars {
                let phase = Double(i) / 28.0
                let wave = sin(t * 6 + phase * 2 * .pi * 2)
                let env = sin(phase * .pi)
                let h: CGFloat = 8 + 28 * abs(CGFloat(wave)) * CGFloat(env) * amplitude
                let x = sx + CGFloat(i) * (barWidth + gap)
                let rect = CGRect(x: x, y: center.y - h / 2, width: barWidth, height: h)
                let path = Path(roundedRect: rect, cornerRadius: 1)
                let shading: GraphicsContext.Shading = .color(glow.opacity(0.95))
                gCtx.fill(path, with: shading)
            }
        }
    }
}

// MARK: - Seeded RNG
struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }

    mutating func nextUInt64() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }

    mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) / Double(1 << 53)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        NethOrbView(state: .idle, size: 220)
        NethOrbView(state: .listening, size: 220)
        NethOrbView(state: .thinking, size: 220)
        NethOrbView(state: .generating, size: 220)
    }
    .padding(40)
    .background(Color.black)
}
#endif
