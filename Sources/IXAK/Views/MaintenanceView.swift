import SwiftUI

struct MaintenanceView: View {
    @State private var isRunning: UUID?
    @State private var results: [UUID: String] = [:]

    var body: some View {
        Form {
            ForEach(MaintenanceActions.all) { action in
                Section(action.title) {
                    Text(action.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Run / Запустить") { run(action) }
                        .disabled(isRunning != nil)
                    if isRunning == action.id {
                        ProgressView()
                    }
                    if let result = results[action.id] {
                        Text(result)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func run(_ action: MaintenanceAction) {
        isRunning = action.id
        results[action.id] = nil
        Task {
            do {
                let output = try await Task.detached { try action.run() }.value
                await MainActor.run {
                    results[action.id] = output
                    isRunning = nil
                }
            } catch {
                await MainActor.run {
                    results[action.id] = error.localizedDescription
                    isRunning = nil
                }
            }
        }
    }
}

#Preview {
    MaintenanceView()
}
