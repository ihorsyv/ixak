import SwiftUI

struct DiagnosticsView: View {
    @State private var stressTest = StressTest()

    @State private var cpuLoad: Double = 0
    @State private var isRunningCPU = false
    @State private var cpuDuration: Double = 30
    @State private var monitorTimer: Timer?
    @State private var testStart: Date?
    @State private var loadSamples: [Double] = []
    @State private var lastAverageLoad: Double?

    @State private var isRunningRAM = false
    @State private var ramResult: BilingualText?
    @State private var ramPassed: Bool?

    @State private var isRunningDisk = false
    @State private var diskResult: BilingualText?
    @State private var diskError: String?
    @State private var lastWriteMBps: Double?
    @State private var lastReadMBps: Double?

    private var elapsedFraction: Double {
        guard let testStart, isRunningCPU else { return 0 }
        return min(1, Date().timeIntervalSince(testStart) / cpuDuration)
    }

    var body: some View {
        Form {
            Section {
                if isRunningCPU {
                    BilingualLabel(en: "Progress: \(Int(elapsedFraction * 100))%", ru: "Прогресс: \(Int(elapsedFraction * 100))%")
                    ProgressView(value: elapsedFraction, total: 1)
                    BilingualLabel(en: "Live load: \(Int(cpuLoad))%", ru: "Текущая загрузка: \(Int(cpuLoad))%")
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $cpuDuration, in: 5...300, step: 5) {
                    BilingualLabel(en: "Duration: \(Int(cpuDuration))s", ru: "Длительность: \(Int(cpuDuration))s")
                }
                Button {
                    if isRunningCPU {
                        stressTest.cancel()
                    } else {
                        runCPUTest()
                    }
                } label: {
                    if isRunningCPU {
                        BilingualLabel(en: "Stop", ru: "Остановить")
                    } else {
                        BilingualLabel(en: "Run CPU Test", ru: "Запустить тест CPU")
                    }
                }
                if let lastAverageLoad {
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
                    runRAMTest()
                } label: {
                    BilingualLabel(en: "Run RAM Test (1 GB)", ru: "Запустить тест RAM (1 ГБ)")
                }
                .disabled(isRunningRAM)
                if isRunningRAM {
                    ProgressView()
                }
                if let ramResult {
                    BilingualLabel(ramResult)
                }
                if ramPassed == false {
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
                    runDiskTest()
                } label: {
                    BilingualLabel(en: "Run Disk Test (512 MB)", ru: "Запустить тест диска (512 МБ)")
                }
                .disabled(isRunningDisk)
                if isRunningDisk {
                    ProgressView()
                }
                if let diskResult {
                    BilingualLabel(diskResult)
                }
                if let diskError {
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
        .onDisappear { monitorTimer?.invalidate() }
    }

    private func cpuRecommendation(averageLoad: Double) -> BilingualText? {
        guard averageLoad < 70 else { return nil }
        return BilingualText(
            en: "Average load stayed below 70% — likely other apps competing for CPU, or thermal throttling. Close background apps and retry.",
            ru: "Средняя загрузка ниже 70% — вероятно, другие приложения тоже используют CPU, либо тротлинг по температуре. Закройте фоновые приложения и повторите тест."
        )
    }

    private func diskRecommendation() -> BilingualText? {
        guard let write = lastWriteMBps, let read = lastReadMBps else { return nil }
        guard write < 300 || read < 300 else { return nil }
        return BilingualText(
            en: "Speeds below 300 MB/s are slow for an internal SSD — check free disk space, run Disk Utility First Aid, or confirm this isn't an external/network drive.",
            ru: "Скорость ниже 300 МБ/с — это медленно для внутреннего SSD. Проверьте свободное место, запустите First Aid в Disk Utility, либо убедитесь, что это не внешний/сетевой диск."
        )
    }

    private func startMonitoring() {
        monitorTimer?.invalidate()
        loadSamples = []
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let load = CPUMonitor.currentLoadPercent()
            cpuLoad = load
            loadSamples.append(load)
        }
    }

    private func runCPUTest() {
        isRunningCPU = true
        testStart = Date()
        lastAverageLoad = nil
        startMonitoring()
        Task {
            await stressTest.runCPU(duration: cpuDuration)
            await MainActor.run {
                isRunningCPU = false
                monitorTimer?.invalidate()
                if !loadSamples.isEmpty {
                    lastAverageLoad = loadSamples.reduce(0, +) / Double(loadSamples.count)
                }
                cpuLoad = 0
            }
        }
    }

    private func runRAMTest() {
        isRunningRAM = true
        ramResult = nil
        ramPassed = nil
        let test = stressTest
        Task {
            let passed = await Task.detached { test.runRAM(megabytes: 1024) }.value
            await MainActor.run {
                ramPassed = passed
                ramResult = passed
                    ? BilingualText(en: "Passed ✓", ru: "Пройден ✓")
                    : BilingualText(en: "FAILED — data mismatch", ru: "ОШИБКА — несовпадение данных")
                isRunningRAM = false
            }
        }
    }

    private func runDiskTest() {
        isRunningDisk = true
        diskResult = nil
        diskError = nil
        lastWriteMBps = nil
        lastReadMBps = nil
        let test = stressTest
        Task {
            do {
                let (write, read) = try await Task.detached { try test.runDiskSpeed() }.value
                await MainActor.run {
                    diskResult = BilingualText(
                        en: String(format: "Write: %.0f MB/s, Read: %.0f MB/s", write, read),
                        ru: String(format: "Запись: %.0f МБ/с, Чтение: %.0f МБ/с", write, read)
                    )
                    lastWriteMBps = write
                    lastReadMBps = read
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
