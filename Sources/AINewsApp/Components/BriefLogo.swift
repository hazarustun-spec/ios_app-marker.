import SwiftUI

// Orbital logo from design (circle + ellipse + center dot)
struct BriefLogo: View {
    var size: CGFloat = 28
    var color: Color = .textPrimary

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width
            let lineWidth: CGFloat = 1.5

            // outer circle
            let circle = Path(ellipseIn: CGRect(x: lineWidth/2, y: lineWidth/2, width: s - lineWidth, height: s - lineWidth))
            ctx.stroke(circle, with: .color(color), lineWidth: lineWidth)

            // equatorial ellipse
            let ellipseH = s * 0.36
            let ellipse = Path(ellipseIn: CGRect(x: lineWidth/2, y: (s - ellipseH)/2, width: s - lineWidth, height: ellipseH))
            ctx.stroke(ellipse, with: .color(color), lineWidth: lineWidth)

            // center dot
            let dotR: CGFloat = 2.5
            let dot = Path(ellipseIn: CGRect(x: s/2 - dotR, y: s/2 - dotR, width: dotR*2, height: dotR*2))
            ctx.fill(dot, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        BriefLogo(size: 28)
        BriefLogo(size: 40)
        BriefLogo(size: 28, color: .white)
            .padding(8)
            .background(Color.textPrimary)
            .clipShape(Circle())
    }
    .padding()
}
