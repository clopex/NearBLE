import SwiftUI

struct ScannerView: View {
    @EnvironmentObject private var bleScanner: BLEScannerService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scannerHeader
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nearby Devices (\(bleScanner.devices.count))")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    if bleScanner.devices.isEmpty {
                        ContentUnavailableView {
                            Label(
                                bleScanner.isScanning ? "Scanning…" : "No Devices Yet",
                                systemImage: bleScanner.isScanning ? "wave.3.right.circle" : "dot.radiowaves.left.and.right"
                            )
                        } description: {
                            Text(
                                bleScanner.isScanning
                                    ? "NearBLE is listening for BLE advertisements. Move around or wait a moment for devices to appear."
                                    : "Tap the scanner button to begin discovering nearby BLE devices."
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(bleScanner.devices) { device in
                                NavigationLink {
                                    DeviceDetailView(deviceID: device.id, initialDevice: device)
                                } label: {
                                    BLEDeviceRow(device: device)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    bleScanner.stopScan()
                                })
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .refreshable {
            bleScanner.refreshScan()
        }
    }

    private var scannerHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RadarScopeView(devices: Array(bleScanner.devices.prefix(12)), isScanning: bleScanner.isScanning)
                    .frame(height: 198)

                Button {
                    bleScanner.toggleScan()
                } label: {
                    ScannerPulseButton(isScanning: bleScanner.isScanning)
                }
                .buttonStyle(.plain)
                .disabled(!bleScanner.canToggleScan)
                .opacity(bleScanner.canToggleScan ? 1 : 0.45)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(bleScanner.availability.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(bleScanner.availability.message)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            HStack(spacing: 12) {
                statusPill(
                    title: "\(bleScanner.devices.count) devices",
                    systemImage: "sensor.tag.radiowaves.forward",
                    tint: .cyan
                )

                if bleScanner.isScanning {
                    statusPill(
                        title: "Live",
                        systemImage: "dot.radiowaves.up.forward",
                        tint: .green
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.11, blue: 0.18),
                            Color(red: 0.02, green: 0.07, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
        )
    }

    private func statusPill(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
            )
    }
}

private struct BLEDeviceRow: View {
    let device: BLEDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.isConnectable ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.title3)
                .foregroundStyle(device.isConnectable ? Color.accentColor : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)

                Text(device.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(device.lastSeenLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 6) {
                SignalBarsView(level: device.signalBars)

                Text("\(device.rssi) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct SignalBarsView: View {
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < level ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: CGFloat(8 + (index * 4)))
            }
        }
        .frame(height: 24)
    }
}

private struct RadarScopeView: View {
    let devices: [BLEDevice]
    let isScanning: Bool
    @State private var sweepRotation = false
    @State private var pulseBlips = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.16),
                                Color.cyan.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 6,
                            endRadius: size * 0.48
                        )
                    )

                ForEach([0.28, 0.52, 0.76, 1.0], id: \.self) { ratio in
                    Circle()
                        .stroke(Color.cyan.opacity(ratio == 1 ? 0.22 : 0.12), lineWidth: 1)
                        .frame(width: size * ratio, height: size * ratio)
                }

                Rectangle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: 1, height: size)

                Rectangle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: size, height: 1)

                if isScanning {
                    RadarSweepShape()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color.clear,
                                    Color.cyan.opacity(0.04),
                                    Color.cyan.opacity(0.22),
                                    Color.clear
                                ],
                                center: .center
                            )
                        )
                        .rotationEffect(.degrees(sweepRotation ? 360 : 0))
                }

                ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                    let point = radarPoint(for: device, size: size, index: index)

                    Circle()
                        .fill(device.isConnectable ? Color.green : Color.cyan)
                        .frame(width: device.isConnectable ? 11 : 8, height: device.isConnectable ? 11 : 8)
                        .shadow(color: (device.isConnectable ? Color.green : Color.cyan).opacity(0.45), radius: 10)
                        .overlay {
                            Circle()
                                .stroke((device.isConnectable ? Color.green : Color.cyan).opacity(0.35), lineWidth: 6)
                                .scaleEffect(isScanning && pulseBlips ? 1.7 : 1)
                                .opacity(isScanning ? 0.25 : 0)
                        }
                        .offset(x: point.x, y: point.y)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            updateAnimations()
        }
        .onChange(of: isScanning) { _, _ in
            updateAnimations()
        }
    }

    private func radarPoint(for device: BLEDevice, size: CGFloat, index: Int) -> CGPoint {
        let seed = abs(device.id.uuidString.hashValue)
        let angle = Double(seed % 360) * .pi / 180
        let jitter = CGFloat((seed / 360) % 12) / 100
        let normalizedSignal = max(0.22, min(CGFloat(device.signalBars) / 4, 1))
        let radius = (size * 0.42) * (1.0 - normalizedSignal * 0.72) + (CGFloat(index % 3) * 8) + jitter * 12

        return CGPoint(
            x: CGFloat(cos(angle)) * radius,
            y: CGFloat(sin(angle)) * radius
        )
    }

    private func updateAnimations() {
        guard isScanning else {
            sweepRotation = false
            pulseBlips = false
            return
        }

        sweepRotation = false
        pulseBlips = false

        withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
            sweepRotation = true
        }

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseBlips = true
        }
    }
}

private struct RadarSweepShape: Shape {
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

private struct ScannerPulseButton: View {
    let isScanning: Bool
    @State private var animatePulse = false
    @State private var rotatePrimary = false
    @State private var rotateSecondary = false

    var body: some View {
        ZStack {
            if isScanning {
                Circle()
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 18)
                    .frame(width: 108, height: 108)
                    .scaleEffect(animatePulse ? 1.04 : 0.88)
                    .opacity(animatePulse ? 0.22 : 0.06)

                Circle()
                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 28)
                    .frame(width: 132, height: 132)
                    .scaleEffect(animatePulse ? 1.16 : 0.94)
                    .opacity(animatePulse ? 0.1 : 0.03)

                Circle()
                    .trim(from: 0.08, to: 0.34)
                    .stroke(
                        AngularGradient(
                            colors: [Color.clear, Color.cyan, Color.accentColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 118, height: 118)
                    .rotationEffect(.degrees(rotatePrimary ? 360 : 0))

                Circle()
                    .trim(from: 0.58, to: 0.86)
                    .stroke(
                        AngularGradient(
                            colors: [Color.clear, Color.white.opacity(0.4), Color.cyan.opacity(0.9)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees(rotateSecondary ? -360 : 0))
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: isScanning
                            ? [Color.accentColor, Color.cyan]
                            : [Color.accentColor.opacity(0.88), Color.accentColor.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 84, height: 84)
                .shadow(color: Color.accentColor.opacity(isScanning ? 0.32 : 0.18), radius: 18, y: 10)
                .scaleEffect(isScanning && animatePulse ? 1.03 : 1)

            Image(systemName: isScanning ? "stop.fill" : "dot.radiowaves.left.and.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(isScanning && animatePulse ? 1.08 : 1)
        }
        .frame(width: 132, height: 132)
        .onAppear {
            updatePulseAnimation()
        }
        .onChange(of: isScanning) { _, _ in
            updatePulseAnimation()
        }
        .accessibilityLabel(isScanning ? "Stop scan" : "Start scan")
    }

    private func updatePulseAnimation() {
        guard isScanning else {
            withAnimation(.easeOut(duration: 0.2)) {
                animatePulse = false
            }
            rotatePrimary = false
            rotateSecondary = false
            return
        }

        animatePulse = false
        withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
            animatePulse = true
        }
        withAnimation(.linear(duration: 2.1).repeatForever(autoreverses: false)) {
            rotatePrimary = true
        }
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            rotateSecondary = true
        }
    }
}
