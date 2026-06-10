import Foundation

extension Int {
    var abbreviated: String {
        if self >= 1000 {
            let k = Double(self) / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))K"
                : String(format: "%.1fK", k)
        }
        return "\(self)"
    }
}
