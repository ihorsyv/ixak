import SwiftUI

/// Owns diagnostics state outside the view so a running test keeps
/// updating (and keeps its results) when the user switches tabs — macOS
/// TabView fires onDisappear on the hidden tab, which previously killed
/// the progress timer mid-test.
@MainActor
final class DiagnosticsModel: ObservableObject {
    let stressTest = StressTest()

    @Published var cpuLoad: Double = 0
    @Published var isRunningCPU = false
    @Published var cpuDuration: Double = 30
    @Published var testStart: Date?
    @Published var lastAverageLoad: Double?
    private var loadSamples: [Double] = []
    private var monitorTimer: Timer?

    @Published var isRunningRAM = false
    @Published var ramResult: BilingualText?
    @Published var ramPassed: Bool?

    @Published var isRunningDisk = false
    @Published var diskResult: BilingualText?
    @Published var diskError: String?
    @Published var lastWriteMBps: Double?
    @Published var lastReadMBps: Double?

    var elapsedFraction: Double {
        guard let testStart, isRunningCPU else { return 0 }
        return min(1, Date().timeIntervalSince(testStart) / cpuDuration)
    }

    private func startMonitoring() {
        monitorTimer?.invalidate()
        loadSamples = []
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let load = CPUMonitor.currentLoadPercent()
                self.cpuLoad = load
                self.loadSamples.append(load)
            }
        }
        // .common keeps it firing while a menu or tab control is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        monitorTimer = timer
    }

    func runCPUTest() {
        isRunningCPU = true
        testStart = Date()
        lastAverageLoad = nil
        startMonitoring()
        let test = stressTest
        let duration = cpuDuration
        Task {
            await test.runCPU(duration: duration)
            isRunningCPU = false
            monitorTimer?.invalidate()
            monitorTimer = nil
            if !loadSamples.isEmpty {
                lastAverageLoad = loadSamples.reduce(0, +) / Double(loadSamples.count)
            }
            cpuLoad = 0
        }
    }

    func stopCPUTest() {
        stressTest.cancel()
    }

    func runRAMTest() {
        isRunningRAM = true
        ramResult = nil
        ramPassed = nil
        let test = stressTest
        Task {
            let passed = await Task.detached { test.runRAM(megabytes: 1024) }.value
            ramPassed = passed
            ramResult = passed
                ? BilingualText(en: "Passed ✓", ru: "Пройден ✓")
                : BilingualText(en: "FAILED — data mismatch", ru: "ОШИБКА — несовпадение данных")
            isRunningRAM = false
        }
    }

    func runDiskTest() {
        isRunningDisk = true
        diskResult = nil
        diskError = nil
        lastWriteMBps = nil
        lastReadMBps = nil
        let test = stressTest
        Task {
            do {
                let (write, read) = try await Task.detached { try test.runDiskSpeed() }.value
                diskResult = BilingualText(
                    en: String(format: "Write: %.0f MB/s, Read: %.0f MB/s", write, read),
                    ru: String(format: "Запись: %.0f МБ/с, Чтение: %.0f МБ/с", write, read)
                )
                lastWriteMBps = write
                lastReadMBps = read
            } catch {
                diskError = error.localizedDescription
            }
            isRunningDisk = false
        }
    }
}

struct DiagnosticsView: View {
    @ObservedObject var model: DiagnosticsModel

    var body: some View {
        Form {
            Section {
                if model.isRunningCPU {
                    BilingualLabel(en: "Progress: \(Int(model.elapsedFraction * 100))%", ru: "Прогресс: \(Int(model.elapsedFraction * 100))%")
                    ProgressView(value: model.elapsedFraction, total: 1)
                    BilingualLabel(en: "Live load: \(Int(model.cpuLoad))%", ru: "Текущая загрузка: \(Int(model.cpuLoad))%")
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $model.cpuDuration, in: 5...300, step: 5) {
                    BilingualLabel(en: "Duration: \(Int(model.cpuDuration))s", ru: "Длительность: \(Int(model.cpuDuration))s")
                }
                Button {
                    if model.isRunningCPU {
                        model.stopCPUTest()
                    } else {
                        model.runCPUTest()
                    }
                } label: {
                    if model.isRunningCPU {
                        BilingualLabel(en: "Stop", ru: "Остановить")
                    } else {
                        BilingualLabel(en: "Run CPU Test", ru: "Запустить тест CPU")
                    }
                }
                if let lastAverageLoad = model.lastAverageLoad {
                    BilingualLabel(en: "Average load: \(Int(lastAverageLoad))%", ru: "Средняя загрузка: \(Int(lastAverageLoad))%")
                    if let hint = cpuRecommendation(averageLoad: lastAverageLoad) {
                        BilingualLabel(hint)
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                BilingualLabel(en: "CPU Stress Test", ru: "Нагрузочный тест CPU")
            }

            Section {
                Button {
                    model.runRAMTest()
                } label: {
                    BilingualLabel(en: "Run RAM Test (1 GB)", ru: "Запустить тест RAM (1 ГБ)")
                }
                .disabled(model.isRunningRAM)
                if model.isRunningRAM {
                    ProgressView()
                }
                if let ramResult = model.ramResult {
                    BilingualLabel(ramResult)
                }
                if model.ramPassed == false {
                    BilingualLabel(
                        en: "Recommendation: back up your data and run Apple Diagnostics (restart, hold D). Repeated failures suggest a hardware RAM fault.",
                        ru: "Рекомендация: сделайте бэкап данных и запустите Apple Diagnostics (перезагрузка с зажатой D). Повторяющиеся сбои указывают на аппаратную неисправность памяти."
                    )
                    .font(.callout)
                    .foregroundStyle(.red)
                }
            } header: {
                BilingualLabel(en: "RAM Test", ru: "Тест памяти")
            }

            Section {
                Button {
                    model.runDiskTest()
                } label: {
                    BilingualLabel(en: "Run Disk Test (512 MB)", ru: "Запустить тест диска (512 МБ)")
                }
                .disabled(model.isRunningDisk)
                if model.isRunningDisk {
                    ProgressView()
                }
                if let diskResult = model.diskResult {
                    BilingualLabel(diskResult)
                }
                if let diskError = model.diskError {
                    Text(diskError).foregroundStyle(.red)
                }
                if let hint = diskRecommendation() {
                    BilingualLabel(hint)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } header: {
                BilingualLabel(en: "Disk Speed", ru: "Скорость диска")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func cpuRecommendation(averageLoad: Double) -> BilingualText? {
        guard averageLoad < 70 else { return nil }
        return BilingualText(
            en: "Average load stayed below 70% — likely other apps competing for CPU, or thermal throttling. Close background apps and retry.",
            ru: "Средняя загрузка ниже 70% — вероятно, другие приложения тоже используют CPU, либо тротлинг по температуре. Закройте фоновые приложения и повторите тест."
        )
    }

    private func diskRecommendation() -> BilingualText? {
        guard let write = model.lastWriteMBps, let read = model.lastReadMBps else { return nil }
        guard write < 300 || read < 300 else { return nil }
        return BilingualText(
            en: "Speeds below 300 MB/s are slow for an internal SSD — check free disk space, run Disk Utility First Aid, or confirm this isn't an external/network drive.",
            ru: "Скорость ниже 300 МБ/с — это медленно для внутреннего SSD. Проверьте свободное место, запустите First Aid в Disk Utility, либо убедитесь, что это не внешний/сетевой диск."
        )
    }
}

#Preview {
    DiagnosticsView(model: DiagnosticsModel())
}
