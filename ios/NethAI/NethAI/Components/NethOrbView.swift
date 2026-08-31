import SwiftUI

// MARK: - NethOrbView — the signature animated AI-device centerpiece
// Layered ZStack of Canvas views, each a separate struct for fast type-checking.
// Layers: ambient halo -> rotating energy rings -> particle field -> radial core
//         -> specular highlight -> inner waveform (listening/generating).
// All state-reactive: color, speed, particle count, amplitude.

struct NethOrbView: View {
    var state: OrbState
    var size: CGFloat = 320

    @State private var particleSeed: UInt64

    init(state: OrbState, size: CGFloat = 320) {
        self.state = state
        self.size = size
        _particleSeed = State(initialValue: UInt64(Date().timeIntervalSince1970 * 1000))
    }

    var body: some View {
        ZStack {
            OrbHalo(state: state, size: size)
            OrbRings(state: state, size: size)
            OrbParticles(state: state, size: size, seed: particleSeed)
            OrbCore(state: state, size: size)
            OrbHighlight(size: size)
            if state == .generating || state == .listening {
                OrbWaveform(state: state, size: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text("Neth Orb, \(state.label)"))
    }
}

// MARK: - Halo (soft outer glow that breathes)
private struct OrbHalo: View {
    let state: OrbState
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let period = NethTheme.pulseSpeed(for: state)
            let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / period)
            let glow = NethTheme.glowColor(for: state)
            let radius = size * (0.62 + 0.06 * pulse)
            HaloCanvas(radius: radius, glow: glow)
                .frame(width: size * 1.9, height: size * 1.9)
                .blur(radius: 18 + 8 * pulse)
                .opacity(0.9)
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
                glow.opacity(0.55),
                glow.opacity(0.25),
                glow.opacity(0.0)
            ])
            let shading: GraphicsContext.Shading = .radialGradient(
                grad, center: center, startRadius: 0, endRadius: radius
            )
            gCtx.fill(path, with: shading)
        }
    }
}

// MARK: - Rings (3 counter-rotating dashed ellipses)
private struct OrbRings: View {
    let state: OrbState
    let size: CGFloat

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
        let arcLen: CGFloat = 0.65 + 0.25 * CGFloat(sin(t * 2 + Double(i)))
        let phase = rotation.truncatingRemainder(dividingBy: 2 * .pi)

        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        let path = Path(ellipseIn: rect)

        let strokeStyle = StrokeStyle(
            lineWidth: 1.6,
            lineCap: .round,
            dash: [radius * arcLen, radius * (2 - arcLen) * 1.6],
            dashPhase: CGFloat(phase) * radius
        )

        let grad = Gradient(colors: [glow.opacity(0.95), glow.opacity(0.15)])
        let shading: GraphicsContext.Shading = .linearGradient(
            grad,
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
        )
        gCtx.stroke(path, with: shading, style: strokeStyle)
    }
}

// MARK: - Particles (orbiting dots with wobble)
private struct OrbParticles: View {
    let state: OrbState
    let size: CGFloat
    let seed: UInt64

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let period = NethTheme.pulseSpeed(for: state)
            let glow = NethTheme.glowColor(for: state)
            let count = particleCount(for: state)
            ParticlesCanvas(t: t, period: period, glow: glow, baseR: size * 0.5,
                            seed: seed, count: count)
                .frame(width: size, height: size)
        }
    }

    private func particleCount(for state: OrbState) -> Int {
        switch state {
        case .idle:        return 18
        case .listening:   return 28
        case .thinking:    return 36
        case .generating:  return 44
        case .complete:    return 22
        case .error:       return 14
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
        let orbitR = baseR * (0.55 + 0.38 * rng.nextDouble())
        let wobble = sin(t * 1.6 + Double(i)) * 5
        let x = center.x + cos(angle) * (orbitR + CGFloat(wobble))
        let y = center.y + sin(angle) * (orbitR + CGFloat(wobble))
        let pSize: CGFloat = 1.8 + CGFloat(rng.nextDouble()) * 2.8
        let alpha = 0.5 + 0.5 * sin(t * 2 + Double(i) * 0.7)
        let rect = CGRect(x: x - pSize, y: y - pSize, width: pSize * 2, height: pSize * 2)
        let path = Path(ellipseIn: rect)
        let shading: GraphicsContext.Shading = .color(glow.opacity(Double(alpha)))
        gCtx.fill(path, with: shading)
    }
}

// MARK: - Core (radial gradient sphere with rim light)
private struct OrbCore: View {
    let state: OrbState
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let period = NethTheme.pulseSpeed(for: state)
            let breath = 0.5 + 0.5 * sin(t * 2 * .pi / period)
            let scale = 0.94 + 0.06 * breath
            let glow = NethTheme.glowColor(for: state)
            let coreR = size * 0.42 * scale
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
                Color.white.opacity(0.98),
                NethTheme.orangeBright,
                NethTheme.orange,
                NethTheme.orangeDeep,
                Color.black.opacity(0.92)
            ])
            let highlightCenter = CGPoint(x: center.x - coreR * 0.28, y: center.y - coreR * 0.28)
            let coreShading: GraphicsContext.Shading = .radialGradient(
                grad, center: highlightCenter, startRadius: 0, endRadius: coreR
            )
            gCtx.fill(path, with: coreShading)

            // Rim light
            let inset = rect.insetBy(dx: coreR * 0.12, dy: coreR * 0.12)
            let rimPath = Path(ellipseIn: inset)
            let rimShading: GraphicsContext.Shading = .color(glow.opacity(0.3))
            gCtx.stroke(rimPath, with: rimShading, lineWidth: 1.2)
        }
    }
}

// MARK: - Specular highlight
private struct OrbHighlight: View {
    let size: CGFloat

    var body: some View {
        Canvas { gCtx, sz in
            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let r = size * 0.42 * 0.6
            let hx = center.x - r * 0.32
            let hy = center.y - r * 0.42
            let hw = r * 0.42
            let hh = r * 0.32
            let rect = CGRect(x: hx - hw, y: hy - hh, width: hw * 2, height: hh * 2)
            let path = Path(ellipseIn: rect)
            let grad = Gradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0)])
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

// MARK: - Inner waveform (listening / generating)
private struct OrbWaveform: View {
    let state: OrbState
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let glow = NethTheme.glowColor(for: state)
            let amplitude: CGFloat = state == .generating ? 1.0 : 0.65
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
            let bars = 32
            let barWidth: CGFloat = 2.2
            let gap: CGFloat = 3
            let total = CGFloat(bars) * (barWidth + gap)
            let sx = center.x - total / 2
            for i in 0..<bars {
                let phase = Double(i) / 28.0
                let wave = sin(t * 6 + phase * 2 * .pi * 2)
                let env = sin(phase * .pi)
                let h: CGFloat = 8 + 32 * abs(CGFloat(wave)) * CGFloat(env) * amplitude
                let x = sx + CGFloat(i) * (barWidth + gap)
                let rect = CGRect(x: x, y: center.y - h / 2, width: barWidth, height: h)
                let path = Path(roundedRect: rect, cornerRadius: 1.2)
                let shading: GraphicsContext.Shading = .color(glow.opacity(0.95))
                gCtx.fill(path, with: shading)
            }
        }
    }
}

// MARK: - Seeded RNG (deterministic per-frame particle placement)
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
    VStack(spacing: 30) {
        HStack(spacing: 30) {
            NethOrbView(state: .idle, size: 140)
            NethOrbView(state: .listening, size: 140)
        }
        HStack(spacing: 30) {
            NethOrbView(state: .thinking, size: 140)
            NethOrbView(state: .generating, size: 140)
        }
        HStack(spacing: 30) {
            NethOrbView(state: .complete, size: 140)
            NethOrbView(state: .error, size: 140)
        }
    }
    .padding(40)
    .background(Color.black)
}
#endif
