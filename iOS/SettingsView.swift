import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var importing = false
    @State private var confirmingDelete = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        importing = true
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
                        model.pushToWatch()
                        message = "Sent your plan and latest weights to your Watch."
                    } label: {
                        Label("Send plan to Watch", systemImage: "applewatch")
                    }
                } footer: {
                    Text("This happens automatically. Use it if your Watch looks out of date.")
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
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                switch result {
                case .success(let url):
                    do {
                        let counts = try model.importStrong(from: url)
                        message = counts.skipped > 0
                            ? "Imported \(counts.added) workouts. \(counts.skipped) were already here."
                            : "Imported \(counts.added) workouts."
                    } catch {
                        message = error.localizedDescription
                    }
                case .failure(let error):
                    message = error.localizedDescription
                }
            }
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
}
