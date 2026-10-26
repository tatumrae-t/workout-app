import Foundation

enum Format {
    static func weight(_ pounds: Double) -> String {
        pounds.rounded() == pounds ? "\(Int(pounds))" : String(format: "%.1f", pounds)
    }

    static func set(_ set: LoggedSet) -> String {
        let text = set.weight == 0 ? "\(set.reps) reps" : "\(weight(set.weight)) lb × \(set.reps)"
        guard let rpe = set.rpe else { return text }
        return "\(text) @\(Effort.text(rpe))"
    }

    static func sets(_ sets: [LoggedSet]) -> String {
        sets.map { set($0) }.joined(separator: ", ")
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
