import Foundation

/// Reads the CSV that Strong exports from Settings › Export Data.
enum StrongImport {
    enum ImportError: LocalizedError {
        case empty
        case notStrongExport

        var errorDescription: String? {
            switch self {
            case .empty: "That file is empty."
            case .notStrongExport: "That doesn't look like a Strong export. It needs Date, Exercise Name and Reps columns."
            }
        }
    }

    private static let poundsPerKilogram = 2.20462

    static func workouts(fromCSV text: String) throws -> [Workout] {
        var rows = CSV.rows(text)
        guard !rows.isEmpty else { throw ImportError.empty }
        let header = rows.removeFirst().map { $0.trimmingCharacters(in: .whitespaces) }

        func column(_ names: String...) -> Int? {
            names.lazy.compactMap { header.firstIndex(of: $0) }.first
        }

        guard let dateColumn = column("Date"),
              let exerciseColumn = column("Exercise Name"),
              let repsColumn = column("Reps") else {
            throw ImportError.notStrongExport
        }
        let nameColumn = column("Workout Name")
        let durationColumn = column("Duration")
        let setOrderColumn = column("Set Order")
        let poundsColumn = column("Weight", "Weight (lbs)", "Weight (lb)")
        let kilogramsColumn = column("Weight (kg)")
        let unitColumn = column("Weight Unit")

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        func field(_ row: [String], _ column: Int?) -> String {
            guard let column else { return "" }
            return row[safe: column] ?? ""
        }

        // Every row is one set; rows from the same workout share Date + Workout Name.
        struct Key: Hashable {
            let date: String
            let name: String
        }
        var order: [Key] = []
        var groups: [Key: [[String]]] = [:]
        for row in rows {
            if field(row, setOrderColumn) == "Rest Timer" { continue }
            let key = Key(date: field(row, dateColumn), name: field(row, nameColumn))
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(row)
        }

        var workouts: [Workout] = []
        for key in order {
            guard let start = dateFormatter.date(from: key.date), let rows = groups[key] else { continue }

            var exercises: [LoggedExercise] = []
            for row in rows {
                let name = field(row, exerciseColumn)
                let reps = Int(Double(field(row, repsColumn)) ?? 0)
                guard !name.isEmpty, reps > 0 else { continue }

                var weight: Double
                if let kilograms = Double(field(row, kilogramsColumn)) {
                    weight = kilograms * poundsPerKilogram
                } else {
                    weight = Double(field(row, poundsColumn)) ?? 0
                    if field(row, unitColumn).lowercased() == "kg" {
                        weight *= poundsPerKilogram
                    }
                }

                let set = LoggedSet(weight: (weight * 10).rounded() / 10, reps: reps, completedAt: start)
                if let index = exercises.firstIndex(where: { $0.name == name }) {
                    exercises[index].sets.append(set)
                } else {
                    exercises.append(LoggedExercise(name: name, sets: [set]))
                }
            }
            guard !exercises.isEmpty else { continue }

            let duration = parseDuration(field(rows[0], durationColumn)) ?? 3600
            workouts.append(Workout(
                name: cleanName(key.name),
                dayID: nil,
                startDate: start,
                endDate: start.addingTimeInterval(duration),
                source: .strong,
                exercises: exercises
            ))
        }
        return workouts
    }

    /// "1h 10m" or "35m" to seconds.
    static func parseDuration(_ text: String) -> TimeInterval? {
        var total: TimeInterval = 0
        var number = ""
        for character in text {
            if character.isNumber {
                number.append(character)
                continue
            }
            if let value = Double(number) {
                switch character {
                case "h": total += value * 3600
                case "m": total += value * 60
                case "s": total += value
                default: break
                }
            }
            number = ""
        }
        return total > 0 ? total : nil
    }

    /// Strong exports line breaks in names as a literal "\n".
    static func cleanName(_ name: String) -> String {
        let flattened = name
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        let words = flattened.split(separator: " ")
        return words.isEmpty ? "Workout" : words.joined(separator: " ")
    }
}

enum CSV {
    /// Splits CSV text into rows of fields, handling quotes, doubled quotes
    /// and line breaks inside quoted fields.
    static func rows(_ text: String) -> [[String]] {
        var scalars = Array(text.unicodeScalars)
        if scalars.first == "\u{FEFF}" { scalars.removeFirst() }

        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var i = 0

        func endField() {
            row.append(String(field))
            field = String.UnicodeScalarView()
        }

        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count && scalars[i + 1] == "\"" {
                        field.append(c)
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                endField()
            } else if c == "\n" || c == "\r" {
                if c == "\r" && i + 1 < scalars.count && scalars[i + 1] == "\n" { i += 1 }
                endField()
                rows.append(row)
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            endField()
            rows.append(row)
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}
