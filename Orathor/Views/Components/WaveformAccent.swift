import SwiftUI

struct WaveformAccent: View {
    var amplitude: CGFloat = 3
    var wavelength: CGFloat = 12
    var lineWidth: CGFloat = 1.5
    var animated: Bool = false

    @State private var phase: CGFloat = 0

    var body: some View {
        WaveformShape(amplitude: amplitude, wavelength: wavelength, phase: phase)
            .stroke(
                LinearGradient(
                    colors: [.brand, .brandGradientEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(height: amplitude * 2 + lineWidth)
            .onAppear {
                if animated {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        phase = .pi * 2
                    }
                }
            }
    }
}

private struct WaveformShape: Shape {
    var amplitude: CGFloat
    var wavelength: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let steps = Int(rect.width / 2)

        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let angle = (x / wavelength) * .pi * 2 + phase
            let y = midY + sin(angle) * amplitude

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

struct WaveformDivider: View {
    var body: some View {
        WaveformAccent(amplitude: 1.5, wavelength: 10, lineWidth: 0.5)
            .opacity(0.3)
            .padding(.horizontal, Spacing.lg)
    }
}
