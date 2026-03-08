import SwiftUI

struct CampfireNodeView: View {
    let size: CGFloat

    @State private var frameIndex = 0
    private let frameDuration = 0.18

    init(size: CGFloat = 30) {
        self.size = size
    }

    var body: some View {
        ZStack {
            altarLayer
            glowLayer
            flameLayer(frame: frameIndex)
            sparksLayer(frame: frameIndex)
        }
        .frame(width: size, height: size)
        .onReceive(Timer.publish(every: frameDuration, on: .main, in: .common).autoconnect()) { _ in
            frameIndex = (frameIndex + 1) % 4
        }
        .accessibilityHidden(true)
    }

    private var altarLayer: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.26, green: 0.24, blue: 0.22))
                .frame(width: size * 0.9, height: size * 0.3)
                .offset(y: size * 0.24)

            Ellipse()
                .fill(Color(red: 0.38, green: 0.35, blue: 0.31))
                .frame(width: size * 0.74, height: size * 0.22)
                .offset(y: size * 0.15)

            glyphRing
                .offset(y: size * 0.15)
        }
    }

    private var glyphRing: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.75, green: 0.58, blue: 0.3).opacity(0.85))
                    .frame(width: size * 0.04, height: size * 0.07)
                    .offset(y: -size * 0.1)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .frame(width: size * 0.5, height: size * 0.2)
    }

    private var glowLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.65, blue: 0.2).opacity(0.7),
                        Color(red: 0.95, green: 0.25, blue: 0.05).opacity(0.05)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.32
                )
            )
            .frame(width: size * 0.68, height: size * 0.68)
            .offset(y: -size * 0.08)
            .blendMode(.screen)
    }

    private func flameLayer(frame: Int) -> some View {
        let xOffsets: [CGFloat] = [-size * 0.01, 0, size * 0.01, 0]
        let heights: [CGFloat] = [0.44, 0.46, 0.43, 0.45]
        let width: CGFloat = size * 0.24
        let height: CGFloat = size * heights[frame]

        return ZStack {
            Ellipse()
                .fill(Color(red: 1.0, green: 0.45, blue: 0.1).opacity(0.95))
                .frame(width: width, height: height)

            Ellipse()
                .fill(Color(red: 1.0, green: 0.82, blue: 0.38).opacity(0.95))
                .frame(width: width * 0.56, height: height * 0.62)
                .offset(y: height * 0.04)
        }
        .offset(x: xOffsets[frame], y: -size * 0.15)
        .rotationEffect(.degrees(frame.isMultiple(of: 2) ? -2 : 2))
    }

    private func sparksLayer(frame: Int) -> some View {
        let yShift: [CGFloat] = [-0.02, -0.05, -0.03, -0.06]

        return ZStack {
            spark(x: -0.14, y: -0.44 + yShift[frame], scale: 1)
            spark(x: -0.04, y: -0.54 + yShift[frame], scale: 0.8)
            spark(x: 0.08, y: -0.58 + yShift[frame], scale: 0.75)
            spark(x: 0.2, y: -0.46 + yShift[frame], scale: 0.95)
        }
        .opacity(0.75)
    }

    private func spark(x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.72, blue: 0.35))
            .frame(width: size * 0.045 * scale, height: size * 0.045 * scale)
            .offset(x: size * x, y: size * y)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CampfireNodeView(size: 56)
    }
}
