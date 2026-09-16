import SwiftUI

struct DiagnosticsView: View {
    @State private var stressTest = StressTest()
    @State private var cpuLoad: Double = 0
    @State private var isRunningCPU = false
    @State private var cpuDuration: Double = 30
    @State private var monitorTimer: Timer?

    @State private var isRunningRAM = false
    @State private var ramResult: String?

    @State private var isRunningDisk = false
    @State private var diskResult: String?
    @State private var diskError: String?

    var body: some View {
        Form {
            Section("CPU Stress Test / Нагрузочный тест CPU") {
                HStack {
                    Text("Load / Загрузка: \(Int(cpuLoad))%")
                    ProgressView(value: cpuLoad, total: 100)
                }
                Stepper("Duration / Длительность: \(Int(cpuDuration))s", value: $cpuDuration, in: 5...300, step: 5)
                Button(isRunningCPU ? "Stop / Остановить" : "Run CPU Test / Запустить тест CPU") {
                    if isRunningCPU {
                        stressTest.cancel()
                    } else {
                        runCPUTest()
                    }
                }
            }

            Section("RAM Test / Тест памяти") {
                Button("Run RAM Test (1 GB) / Запустить тест RAM (1 ГБ)") {
                    runRAMTest()
                }
                .disabled(isRunningRAM)
                if isRunningRAM {
                    ProgressView()
                }
                if let ramResult {
                    Text(ramResult)
                }
            }

            Section("Disk Speed / Скорость диска") {
                Button("Run Disk Test (512 MB) / Запустить тест диска (512 МБ)") {
                    runDiskTest()
                }
                .disabled(isRunningDisk)
                if isRunningDisk {
                    ProgressView()
                }
                if let diskResult {
                    Text(diskResult)
                }
                if let diskError {
                    Text(diskError).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onDisappear { monitorTimer?.invalidate() }
    }

    private func startMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cpuLoad = CPUMonitor.currentLoadPercent()
        }
    }

    private func runCPUTest() {
        isRunningCPU = true
        startMonitoring()
        Task {
            await stressTest.runCPU(duration: cpuDuration)
            await MainActor.run {
                isRunningCPU = false
                monitorTimer?.invalidate()
                cpuLoad = CPUMonitor.currentLoadPercent()
            }
        }
    }

    private func runRAMTest() {
        isRunningRAM = true
        ramResult = nil
        let test = stressTest
        Task {
            let passed = await Task.detached { test.runRAM(megabytes: 1024) }.value
            await MainActor.run {
                ramResult = passed
                    ? "Passed / Пройден ✓"
                    : "FAILED — data mismatch / ОШИБКА — несовпадение данных"
                isRunningRAM = false
            }
        }
    }

    private func runDiskTest() {
        isRunningDisk = true
        diskResult = nil
        diskError = nil
        let test = stressTest
        Task {
            do {
                let (write, read) = try await Task.detached { try test.runDiskSpeed() }.value
                await MainActor.run {
                    diskResult = String(format: "Write / Запись: %.0f MB/s, Read / Чтение: %.0f MB/s", write, read)
                    isRunningDisk = false
                }
            } catch {
                await MainActor.run {
                    diskError = error.localizedDescription
                    isRunningDisk = false
                }
            }
        }
    }
}

#Preview {
    DiagnosticsView()
}
