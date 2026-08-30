import SwiftUI

// MARK: - NethOrbView
// The signature animated visual centerpiece of Neth-AI.
// Layered Canvas + TimelineView with: orange glow core, rotating energy rings,
// orbiting particles, breathing pulse, state-reactive motion + color.
// Pure SwiftUI (no Metal) so it builds cleanly on iOS 17+ without shader pipeline work.

struct NethOrbView: View {
    var state: OrbState
    var size: CGFloat = 280

    @State private var particleSeed: UInt64 = 0
    @State private var audioLevel: CGFloat = 0.0 // 0...1, used for listening
    @State private var tick: CGFloat = 0

    var body: some View {
        ZStack {
            // Outer halo
            halo
            // Rotating rings (3 layers, counter-rotating)
            rings
            // Particle field
            particles
            // Core sphere with radial gradient
            core
            // Specular highlight
            highlight
            // Inner waveform when generating/listening
            if state == .generating || state == .listening {
                innerWaveform
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            particleSeed = UInt64(Date().timeIntervalSince1970 * 1000)
        }
    }

    // MARK: - Halo
    private var halo: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let speed = NethTheme.pulseSpeed(for: state)
            let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / speed)
            let baseRadius = size * (0.55 + 0.05 * pulse)
            let glowColor = NethTheme.glowColor(for: state)

            Canvas { gCtx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radial = gCtx.resolve(
                    Path(ellipseIn: CGRect(x: center.x - baseRadius, y: center.y - baseRadius, width: baseRadius * 2, height: baseRadius * 2))
                )
                let gradient = Gradient(colors: [
                    glowColor.opacity(0.45),
                    glowColor.opacity(0.18),
                    glowColor.opacity(0.0)
                ])
                gCtx.drawLayer { ctx in
                    ctx.draw(radial, with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: baseRadius
                    ))
                }
            }
            .frame(width: size * 1.8, height: size * 1.8)
            .blur(radius: 14 + 6 * pulse)
            .opacity(0.85)
        }
    }

    // MARK: - Rings
    private var rings: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let speed = NethTheme.pulseSpeed(for: state)
            let glowColor = NethTheme.glowColor(for: state)

            Canvas { gCtx, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let baseR = min(sz.width, sz.height) * 0.5

                // 3 counter-rotating rings with dashed strokes
                for i in 0..<3 {
                    let dir: Double = (i % 2 == 0) ? 1 : -1
                    let rotation = t * dir * (0.4 + 0.15 * Double(i)) / speed
                    let radius = baseR * (0.78 + 0.08 * Double(i))
                    var path = Path()
                    path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

                    let arcLen: CGFloat = 0.7 + 0.2 * sin(t * 2 + Double(i))
                    let phase = rotation.truncatingRemainder(dividingBy: 2 * .pi)
                    let stroke = StrokeStyle(
                        lineWidth: 1.4,
                        lineCap: .round,
                        dash: [radius * arcLen, radius * (2 - arcLen) * 1.6],
                        dashPhase: CGFloat(phase) * radius
                    )

                    gCtx.draw(path, with: .linearGradient(
                        Gradient(colors: [glowColor.opacity(0.85), glowColor.opacity(0.15)]),
                        startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
                        endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
                    ), style: stroke)
                }
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: - Particles
    private var particles: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let glowColor = NethTheme.glowColor(for: state)
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
            let speedFactor = NethTheme.pulseSpeed(for: state)

            Canvas { gCtx, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let baseR = min(sz.width, sz.height) * 0.5

                var rng = SeededRNG(seed: particleSeed &+ UInt64(t * 4))
                for i in 0..<count {
                    let angle = (Double(i) / Double(count)) * 2 * .pi + t / speedFactor
                    let orbitR = baseR * (0.55 + 0.35 * rng.nextDouble())
                    let wobble = sin(t * 1.6 + Double(i)) * 4
                    let x = center.x + cos(angle) * (orbitR + wobble)
                    let y = center.y + sin(angle) * (orbitR + wobble)
                    let pSize: CGFloat = 1.6 + CGFloat(rng.nextDouble()) * 2.4
                    let alpha = 0.5 + 0.5 * sin(t * 2 + Double(i) * 0.7)
                    let rect = CGRect(x: x - pSize, y: y - pSize, width: pSize * 2, height: pSize * 2)
                    let path = Path(ellipseIn: rect)
                    gCtx.draw(path, with: .color(glowColor.opacity(Double(alpha))))
                }
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: - Core sphere
    private var core: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let speed = NethTheme.pulseSpeed(for: state)
            let breath = 0.5 + 0.5 * sin(t * 2 * .pi / speed)
            let scale = 0.92 + 0.06 * breath
            let glowColor = NethTheme.glowColor(for: state)
            let coreR = size * 0.4 * scale

            Canvas { gCtx, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let rect = CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)
                let path = Path(ellipseIn: rect)

                let gradient = Gradient(colors: [
                    Color.white.opacity(0.95),
                    NethTheme.orangeBright,
                    NethTheme.orange,
                    NethTheme.orangeDeep,
                    Color.black.opacity(0.9)
                ])
                gCtx.draw(path, with: .radialGradient(
                    gradient,
                    center: CGPoint(x: center.x - coreR * 0.25, y: center.y - coreR * 0.25),
                    startRadius: 0,
                    endRadius: coreR
                ))

                // Inner rim light
                var rim = Path()
                rim.addEllipse(in: rect.insetBy(dx: coreR * 0.15, dy: coreR * 0.15))
                gCtx.draw(rim, with: .color(glowColor.opacity(0.25)))
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: - Specular highlight
    private var highlight: some View {
        Canvas { ctx, sz in
            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let r = size * 0.4 * 0.6
            let highlightCenter = CGPoint(x: center.x - r * 0.35, y: center.y - r * 0.45)
            let rect = CGRect(x: highlightCenter.x - r * 0.4, y: highlightCenter.y - r * 0.3, width: r * 0.8, height: r * 0.6)
            let path = Path(ellipseIn: rect)
            ctx.draw(path, with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0)]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: rect.width / 2
            ))
        }
        .frame(width: size, height: size)
        .blendMode(.screen)
    }

    // MARK: - Inner waveform (for listening / generating)
    private var innerWaveform: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let glowColor = NethTheme.glowColor(for: state)
            let bars = 28
            let speed = NethTheme.pulseSpeed(for: state)

            Canvas { gCtx, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let barWidth: CGFloat = 2
                let totalWidth = CGFloat(bars) * (barWidth + 3)
                let startX = center.x - totalWidth / 2

                for i in 0..<bars {
                    let phase = Double(i) / Double(bars)
                    let wave = sin(t * 6 + phase * 2 * .pi * 2)
                    let env = sin(phase * .pi) // envelope
                    let h: CGFloat = CGFloat(8 + 28 * abs(wave) * env * (state == .generating ? 1.0 : 0.6))
                    let x = startX + CGFloat(i) * (barWidth + 3)
                    let rect = CGRect(x: x, y: center.y - h / 2, width: barWidth, height: h)
                    let path = Path(roundedRect: rect, cornerRadius: 1)
                    gCtx.draw(path, with: .color(glowColor.opacity(0.95)))
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Seeded RNG (deterministic per-frame particle placement)
struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }

    mutating func nextUInt64() -> UInt64 {
        // xorshift64*
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
