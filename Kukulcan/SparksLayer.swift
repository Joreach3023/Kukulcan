import SwiftUI

/// A simple spark particle layer used in `PackOpeningView` to create a burst effect.
///
/// The implementation is intentionally lightweight: it draws a set of small
/// yellow circles that radiate from the centre of the view. The number of
/// particles is driven by the `time` parameter so the caller can trigger a
/// stronger burst by increasing its value.
struct SparksLayer: View {
    /// Controls the intensity of the spark burst. Higher values produce more
    /// particles and a larger radius.
    var time: Double

    var body: some View {
        // `TimelineView` ensures the canvas is redrawn as part of the
        // animation loop without requiring explicit timers.
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let count = max(0, Int(time * 5))
                guard count > 0 else { return }

                let current = timeline.date.timeIntervalSinceReferenceDate
                let radius = CGFloat(time) * 8

                for i in 0..<count {
                    var spark = context
                    // Evenly distribute sparks in a circle and animate their rotation.
                    let angle = (Double(i) / Double(count) * .pi * 2) + current
                    let x = size.width / 2 + cos(angle) * radius
                    let y = size.height / 2 + sin(angle) * radius
                    let rect = CGRect(x: x, y: y, width: 3, height: 3)

                    spark.fill(Path(ellipseIn: rect), with: .color(.yellow))
                }
            }
        }
    }
}

#Preview {
    SparksLayer(time: 10)
        .frame(width: 100, height: 100)
}
