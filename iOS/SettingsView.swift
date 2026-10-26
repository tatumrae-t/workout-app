import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var importing = false
    @State private var importKind = ImportKind.strong
    @State private var sharing: ShareItems?
    @State private var autoBackupFolder = AutoBackup.folderName
    @State private var lastBackup = AutoBackup.lastBackup
    @State private var confirmingDelete = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        pick(.strong)
                    } label: {
                        Label("Import Strong CSV", systemImage: "square.and.arrow.down")
                    }
                    if model.strongWorkoutCount > 0 {
                        LabeledContent("Imported workouts", value: "\(model.strongWorkoutCount)")
                    }
                } header: {
                    Text("Strong history")
                } footer: {
                    Text("In Strong, go to Settings › Export Data and save the file to Files. Importing again only adds workouts that are new.")
                }

                Section {
                    Button {
                        do {
                            sharing = ShareItems(urls: try Backup.exportFiles(for: model.workouts))
                        } catch {
                            message = error.localizedDescription
                        }
                    } label: {
                        Label("Export history", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.workouts.isEmpty)
                    Button {
                        pick(.backup)
                    } label: {
                        Label("Restore from backup", systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Export saves a backup (.json) you can restore from, plus a spreadsheet (.csv). Restoring only adds workouts that aren't already here.")
                }

                Section {
                    if let folder = autoBackupFolder {
                        LabeledContent("Saving to", value: folder)
                        if let lastBackup {
                            LabeledContent("Last backup", value: lastBackup.formatted(date: .abbreviated, time: .shortened))
                        }
                        Button("Change folder") { pick(.folder) }
                        Button("Turn off automatic backup", role: .destructive) {
                            AutoBackup.turnOff()
                            refreshAutoBackup()
                        }
                    } else {
                        Button {
                            pick(.folder)
                        } label: {
                            Label("Choose a backup folder", systemImage: "folder.badge.plus")
                        }
                    }
                } header: {
                    Text("Automatic backup")
                } footer: {
                    Text("Keeps \"\(AutoBackup.fileName)\" up to date in a folder you pick, after every workout. Pick one in iCloud Drive so your history survives deleting the app.")
                }

                Section {
                    Button {
                        model.pushToWatch()
                        message = "Sent your plan and latest weights to your Watch."
                    } label: {
                        Label("Send plan to Watch", systemImage: "applewatch")
                    }
                } footer: {
                    Text("This happens automatically. Use it if your Watch looks out of date.")
                }

                Section {
                    Button {
                        Beep.shared.play()
                    } label: {
                        Label("Test rest beep", systemImage: "speaker.wave.2")
                    }
                } footer: {
                    Text("The beep uses your media volume, the same as music and videos, not the ringer volume. It still plays with the silent switch on.")
                }

                if model.strongWorkoutCount > 0 {
                    Section {
                        Button("Delete imported Strong history", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $importing, allowedContentTypes: importKind.types) { result in
                switch result {
                case .success(let url):
                    handlePicked(url)
                case .failure(let error):
                    message = error.localizedDescription
                }
            }
            .sheet(item: $sharing) { items in
                ShareSheet(items: items.urls)
            }
            .onAppear(perform: refreshAutoBackup)
            .confirmationDialog("Delete imported history?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete \(model.strongWorkoutCount) workouts", role: .destructive) {
                    model.deleteStrongHistory()
                }
            } message: {
                Text("Workouts logged in this app are kept. You can import the CSV again any time.")
            }
            .alert(message ?? "", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func pick(_ kind: ImportKind) {
        importKind = kind
        importing = true
    }

    private func handlePicked(_ url: URL) {
        do {
            switch importKind {
            case .strong:
                let counts = try model.importStrong(from: url)
                message = counts.skipped > 0
                    ? "Imported \(counts.added) workouts. \(counts.skipped) were already here."
                    : "Imported \(counts.added) workouts."
            case .backup:
                let counts = try model.restoreBackup(from: url)
                message = counts.skipped > 0
                    ? "Restored \(counts.added) workouts. \(counts.skipped) were already here."
                    : "Restored \(counts.added) workouts."
            case .folder:
                try AutoBackup.setFolder(url)
                model.backUpNow()
                message = "Your history will be backed up to \(url.lastPathComponent)."
                // The first write runs in the background; show it once done.
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    refreshAutoBackup()
                }
            }
        } catch {
            message = error.localizedDescription
        }
        refreshAutoBackup()
    }

    private func refreshAutoBackup() {
        autoBackupFolder = AutoBackup.folderName
        lastBackup = AutoBackup.lastBackup
    }
}

private enum ImportKind {
    case strong, backup, folder

    var types: [UTType] {
        switch self {
        case .strong: [.commaSeparatedText, .plainText]
        case .backup: [.json]
        case .folder: [.folder]
        }
    }
}

private struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}
