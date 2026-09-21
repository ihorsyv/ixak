import SwiftUI

struct MaintenanceView: View {
    @State private var isRunning: UUID?
    @State private var results: [UUID: BilingualText] = [:]

    var body: some View {
        Form {
            ForEach(MaintenanceActions.all) { action in
                Section {
                    BilingualLabel(action.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button {
                        run(action)
                    } label: {
                        BilingualLabel(en: "Run", ru: "Запустить")
                    }
                    .disabled(isRunning != nil)
                    if isRunning == action.id {
                        ProgressView()
                    }
                    if let result = results[action.id] {
                        BilingualLabel(result)
                            .bold()
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.tertiary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                    }
                } header: {
                    BilingualLabel(action.title)
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
                    let message = error.localizedDescription
                    results[action.id] = BilingualText(en: message, ru: message)
                    isRunning = nil
                }
            }
        }
    }
}

#Preview {
    MaintenanceView()
}
