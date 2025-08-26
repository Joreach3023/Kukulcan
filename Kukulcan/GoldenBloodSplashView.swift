import SwiftUI

struct GoldenBloodSplashView: View {
    var onFinish: () -> Void
    @State private var t: Double = 0                // temps d'animation
    @State private var opacityLogo: Double = 0
    @State private var scaleLogo: CGFloat = 0.9
    @State private var fadeOutAll: Double = 1

    // Durées (tu peux tweaker)
    private let introDuration: Double = 3
    private let fadeDuration: Double  = 0.35

    var body: some View {
        TimelineView(.animation) { context in
            let dt = context.date.timeIntervalSinceReferenceDate
            // vitesse de défilement
            let phase = dt * 0.8

            ZStack {
                // Ciel
                LinearGradient(
                    colors: [
                        Color(red: 8/255, green: 12/255, blue: 14/255),
                        Color(red: 20/255, green: 28/255, blue: 18/255)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Lointain : collines + pyramide (parallax léger)
                Group {
                    HillsLayer(offset: -phase * 20, base: 0.85)
                        .fill(Color(.sRGB, red: 0.10, green: 0.16, blue: 0.14, opacity: 1))
                        .offset(y: 110)

                    PyramidMaya()
                        .fill(Color(.sRGB, red: 0.14, green: 0.18, blue: 0.16, opacity: 1))
                        .frame(width: 240, height: 160)
                        .offset(y: 20)
                        .opacity(0.9)

                    HillsLayer(offset: -phase * 35, base: 0.65)
                        .fill(Color(.sRGB, red: 0.08, green: 0.12, blue: 0.11, opacity: 1))
                        .offset(y: 160)
                }
                .blur(radius: 1.5)

                // Rivières (Canvas)
                VStack {
                    Spacer()
                    RiverView(
                        colorTop: Color(red: 0.95, green: 0.78, blue: 0.18),     // Or
                        colorBottom: Color(red: 0.72, green: 0.47, blue: 0.08),
                        speed: 1.0, amplitude: 26, thickness: 90, noise: 0.8
                    )
                    .frame(height: 120)

                    RiverView(
                        colorTop: Color(red: 0.62, green: 0.05, blue: 0.08),     // Sang
                        colorBottom: Color(red: 0.32, green: 0.02, blue: 0.04),
                        speed: 1.2, amplitude: 34, thickness: 110, noise: 1.0
                    )
                    .frame(height: 140)
                }
                .offset(y: 40)

                // Étincelles dorées
                SparksLayer(time: phase)
                    .blendMode(.plusLighter)
                    .opacity(0.9)

                // Logo (le tien, centré)
                Image("LaunchLogo") // ou "LaunchLogo_KinichAhau"
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .scaleEffect(scaleLogo)
                    .opacity(opacityLogo)
            }
            .opacity(fadeOutAll)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    opacityLogo = 1.0; scaleLogo = 1.0
                }
                // Fin de l’intro → fondu
                DispatchQueue.main.asyncAfter(deadline: .now() + introDuration) {
                    withAnimation(.easeInOut(duration: fadeDuration)) { fadeOutAll = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) {
                        onFinish()
                    }
                }
            }
        }
    }
}

// MARK: - Silhouette pyramidale
struct PyramidMaya: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let stepH = h/6
        let baseY = rect.midY + h*0.25

        // 5 terrasses
        for i in 0..<5 {
            let yTop = baseY - CGFloat(i+1)*stepH
            let yBot = baseY - CGFloat(i)*stepH
            let left  = rect.midX - (w*0.5 - CGFloat(i)*w*0.08)
            let right = rect.midX + (w*0.5 - CGFloat(i)*w*0.08)
            p.addRect(CGRect(x: left, y: yTop, width: right-left, height: yBot - yTop))
        }
        // escalier central
        let stairW = w*0.18
        p.addRect(CGRect(x: rect.midX - stairW/2, y: baseY - h*0.95, width: stairW, height: h*0.9))
        return p
    }
}

// MARK: - Collines lointaines
struct HillsLayer: Shape {
    var offset: CGFloat
    var base: CGFloat // 0..1 (hauteur normalisée)
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let W = rect.width, H = rect.height
        let baseline = H * base
        p.move(to: .init(x: 0, y: H))
        p.addLine(to: .init(x: 0, y: baseline))
        let waves = 6
        for i in 0...waves {
            let x = CGFloat(i) / CGFloat(waves) * W
            // petites ondulations
            let y = baseline + sin((x + offset).toRad / 40) * 10
            p.addLine(to: .init(x: x, y: y))
        }
        p.addLine(to: .init(x: W, y: H))
        p.closeSubpath()
        return p
    }
}

// MARK: - Rivière (Canvas + bruit simple)
import SwiftUI

struct RiverView: View {
    var colorTop: Color
    var colorBottom: Color
    var speed: Double
    var amplitude: CGFloat
    var thickness: CGFloat
    var noise: CGFloat

    @State private var t: CGFloat = 0

    var body: some View {
        Canvas { ctx, size in
            let W: CGFloat = size.width
            let H: CGFloat = size.height
            let midY: CGFloat = H * 0.40
            let steps: Int = 100

            // Helpers locaux (évite la complexité dans les formules)
            func mix(_ a: CGFloat, _ b: CGFloat, _ tt: CGFloat) -> CGFloat { a + (b - a) * tt }
            func smoothstep(_ x: CGFloat) -> CGFloat { x * x * (3 - 2 * x) }
            func hash01(_ x: Int) -> CGFloat {
                var n = UInt32(bitPattern: Int32(x))
                n = (n << 13) ^ n
                let res = 1.0 - Double((n &* (n &* n &* 15731 &+ 789221) &+ 1376312589) & 0x7fffffff) / 1073741824.0
                return CGFloat(res * 0.5 + 0.5)
            }
            func noise1D(_ x: CGFloat) -> CGFloat {
                let x0 = floor(x)
                let x1 = x0 + 1
                let r0 = hash01(Int(x0))
                let r1 = hash01(Int(x1))
                let f = x - x0
                return mix(r0, r1, smoothstep(f))
            }

            // Construit les bords haut/bas en sous-étapes (évite les grosses expressions)
            var topPts: [CGPoint] = []
            topPts.reserveCapacity(steps + 1)
            for i in 0...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let x = frac * W
                let sinTerm = sin((x * 0.018) + (t * 0.9))
                let noiseTerm = (noise1D(x * 0.12 + t) - 0.5)
                let y = midY
                    + sinTerm * amplitude * 0.55
                    + noiseTerm * amplitude * noise
                topPts.append(CGPoint(x: x, y: y))
            }

            var botPts: [CGPoint] = []
            botPts.reserveCapacity(steps + 1)
            for i in 0...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let x = frac * W
                let sinTerm = sin((x * 0.016) - (t * 0.8))
                let noiseTerm = (noise1D(x * 0.10 - t * 0.7) - 0.5)
                let y = midY + thickness
                    + sinTerm * amplitude * 0.35
                    + noiseTerm * amplitude * noise * 0.8
                botPts.append(CGPoint(x: x, y: y))
            }

            // Path du polygone rivière
            var path = Path()
            if let first = topPts.first {
                path.move(to: first)
                for pt in topPts { path.addLine(to: pt) }
                for pt in botPts.reversed() { path.addLine(to: pt) }
                path.closeSubpath()
            }

            // ✅ Dégradé compatible iOS 17 (remplace GraphicsGradient)
            let grad = Gradient(colors: [colorTop, colorBottom])
            ctx.fill(
                path,
                with: .linearGradient(
                    grad,
                    startPoint: CGPoint(x: W * 0.5, y: 0),
                    endPoint:   CGPoint(x: W * 0.5, y: H)
                )
            )

            // Liseré doux (évite autre énorme expression)
            let stroked = path.strokedPath(.init(lineWidth: 1.2, lineCap: .round))
            ctx.stroke(stroked, with: .color(.white.opacity(0.05)))
        }
        .onAppear {
            // Fait "couler" la rivière : on incrémente t en continu
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                t = 800   // une grande valeur suffit pour décaler la phase
            }
        }
    }
}


// MARK: - Étincelles dorées
struct SparksLayer: View {
    let time: Double
    var body: some View {
        Canvas { ctx, size in
            let W = size.width, H = size.height
            let count = 26
            for i in 0..<count {
                // position pseudo-aléatoire stable par i
                let px = (Double((i*137) % 997) / 997.0) * Double(W)
                let baseY = (Double((i*67) % 829) / 829.0) * Double(H*0.6) + Double(H*0.2)
                // légère dérive verticale
                let y = baseY + sin(time * (0.6 + Double(i%5)*0.07) + Double(i)) * 8.0
                let r: CGFloat = CGFloat((Double((i*19)%17)+6)/22.0) * 2.4
                let alpha = 0.18 + 0.12 * sin(time*1.7 + Double(i))
                let circle = Path(ellipseIn: CGRect(x: px-Double(r),
                                                    y: y-Double(r),
                                                    width: Double(r*2), height: Double(r*2)))
                ctx.fill(circle, with: .color(.yellow.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }
}

// utils
private extension CGFloat {
    var toRad: CGFloat { self * .pi / 180 }
}

