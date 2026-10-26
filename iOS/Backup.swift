import Foundation
import SwiftUI
import UIKit

/// Everything in your history, as one JSON file you can restore from.
struct Backup: Codable {
    var version = 1
    var exportedAt: Date
    var workouts: [Workout]

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    enum RestoreError: LocalizedError {
        case unreadable

        var errorDescription: String? {
            "That file isn't a Workouts backup. Pick the .json file the app exported."
        }
    }

    static func data(for workouts: [Workout]) throws -> Data {
        try encoder.encode(Backup(exportedAt: Date(), workouts: workouts))
    }

    static func workouts(from data: Data) throws -> [Workout] {
        if let backup = try? decoder.decode(Backup.self, from: data) {
            return backup.workouts
        }
        throw RestoreError.unreadable
    }

    /// One row per set, with Strong's column names, so spreadsheets (and
    /// this app's Strong import) can read it.
    static func csv(for workouts: [Workout]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var lines = ["Date,Workout Name,Duration,Exercise Name,Set Order,Weight (lbs),Reps,RPE,Source"]
        for workout in workouts.sorted(by: { $0.startDate < $1.startDate }) {
            for exercise in workout.exercises {
                for (number, set) in exercise.sets.enumerated() {
                    lines.append([
                        formatter.string(from: workout.startDate),
                        workout.name,
                        Format.duration(workout.duration),
                        exercise.name,
                        "\(number + 1)",
                        Format.weight(set.weight),
                        "\(set.reps)",
                        set.rpe.map(Effort.text) ?? "",
                        workout.source.rawValue,
                    ].map(escape).joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Writes both files to a temporary folder for the share sheet.
    static func exportFiles(for workouts: [Workout]) throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day())
        let json = folder.appendingPathComponent("Workouts Backup \(stamp).json")
        let csv = folder.appendingPathComponent("Workouts \(stamp).csv")
        try data(for: workouts).write(to: json, options: .atomic)
        try Self.csv(for: workouts).write(to: csv, atomically: true, encoding: .utf8)
        return [json, csv]
    }
}

/// Keeps a copy of your history in a folder you pick in Files, such as
/// iCloud Drive, updated whenever your history changes. A file there
/// outlives deleting the app, and needs no iCloud entitlement.
enum AutoBackup {
    static let fileName = "Workouts Backup.json"
    private static let bookmarkKey = "autoBackupFolder"
    private static let lastKey = "autoBackupLast"

    static var isOn: Bool { UserDefaults.standard.data(forKey: bookmarkKey) != nil }

    static var lastBackup: Date? {
        UserDefaults.standard.object(forKey: lastKey) as? Date
    }

    static var folderName: String? {
        folderURL()?.lastPathComponent
    }

    /// Remembers the folder (picked with the file importer) for later writes.
    static func setFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData()
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }

    static func turnOff() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: lastKey)
    }

    static func save(_ workouts: [Workout]) {
        guard isOn, let folder = folderURL(), let data = try? Backup.data(for: workouts) else { return }
        Task.detached(priority: .background) {
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var wrote = false
            NSFileCoordinator().coordinate(
                writingItemAt: folder.appendingPathComponent(fileName),
                options: .forReplacing,
                error: &coordinationError
            ) { url in
                wrote = (try? data.write(to: url, options: .atomic)) != nil
            }
            if wrote {
                UserDefaults.standard.set(Date(), forKey: lastKey)
            }
        }
    }

    private static func folderURL() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else { return nil }
        if stale { try? setFolder(url) }
        return url
    }
}

/// The system share sheet, for handing off several files at once.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
