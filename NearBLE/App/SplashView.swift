import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animateSweep = false
    @State private var animatePulse = false
    @State private var animateGlow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.11, blue: 0.18),
                    Color(red: 0.02, green: 0.07, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.08))
                        .frame(width: 192, height: 192)
                        .scaleEffect(animatePulse ? 1.04 : 0.94)

                    ForEach([0.38, 0.62, 0.86, 1.0], id: \.self) { ratio in
                        Circle()
                            .stroke(Color.cyan.opacity(ratio == 1 ? 0.24 : 0.12), lineWidth: 1)
                            .frame(width: 192 * ratio, height: 192 * ratio)
                    }

                    Rectangle()
                        .fill(Color.cyan.opacity(0.07))
                        .frame(width: 1, height: 192)

                    Rectangle()
                        .fill(Color.cyan.opacity(0.07))
                        .frame(width: 192, height: 1)

                    if !reduceMotion {
                        SplashSweepShape()
                            .fill(
                                AngularGradient(
                                    colors: [
                                        Color.clear,
                                        Color.cyan.opacity(0.05),
                                        Color.cyan.opacity(0.28),
                                        Color.clear
                                    ],
                                    center: .center
                                )
                            )
                            .frame(width: 192, height: 192)
                            .rotationEffect(.degrees(animateSweep ? 360 : 0))
                    }

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.accentColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 104, height: 104)
                            .shadow(color: Color.cyan.opacity(animateGlow ? 0.34 : 0.16), radius: 22, y: 10)

                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            .frame(width: 104, height: 104)

                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(spacing: 8) {
                    Text("NearBLE")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    Text("BLE discovery with AI context")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        guard !reduceMotion else { return }

        animateSweep = false
        animatePulse = false
        animateGlow = false

        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            animateSweep = true
        }

        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            animatePulse = true
        }

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            animateGlow = true
        }
    }
}

private struct SplashSweepShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-28),
            endAngle: .degrees(18),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
