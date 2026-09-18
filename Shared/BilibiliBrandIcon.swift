import SwiftUI

/// The recognizable bilibili television mark, drawn as a resolution-independent
/// SwiftUI vector so it stays crisp in both the app and every widget size.
struct BilibiliBrandIcon: View {
    var color: Color = .pink

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / 24
            let originX = (proxy.size.width - 24 * unit) / 2
            let originY = (proxy.size.height - 24 * unit) / 2

            ZStack {
                Path { path in
                    path.move(to: point(6.4, 5.8, unit: unit, x: originX, y: originY))
                    path.addLine(to: point(4.5, 3.8, unit: unit, x: originX, y: originY))
                    path.move(to: point(17.6, 5.8, unit: unit, x: originX, y: originY))
                    path.addLine(to: point(19.5, 3.8, unit: unit, x: originX, y: originY))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5 * unit, lineCap: .round, lineJoin: .round))

                RoundedRectangle(cornerRadius: 4 * unit, style: .continuous)
                    .stroke(color, lineWidth: 2.5 * unit)
                    .frame(width: 21.5 * unit, height: 16.2 * unit)
                    .position(x: originX + 12 * unit, y: originY + 14.2 * unit)

                Capsule()
                    .fill(color)
                    .frame(width: 2.6 * unit, height: 4 * unit)
                    .position(x: originX + 8 * unit, y: originY + 13.5 * unit)

                Capsule()
                    .fill(color)
                    .frame(width: 2.6 * unit, height: 4 * unit)
                    .position(x: originX + 16 * unit, y: originY + 13.5 * unit)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func point(_ x: CGFloat, _ y: CGFloat, unit: CGFloat, x originX: CGFloat, y originY: CGFloat) -> CGPoint {
        CGPoint(x: originX + x * unit, y: originY + y * unit)
    }
}
