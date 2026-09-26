import AppKit
import SwiftUI

struct ThisMacView: View {
    @AppStorage("ixak.language") private var language: AppLanguage = .ru
    @State private var info: SystemInfo?
    @State private var isLoading = false
    @State private var showSerial = false
    @State private var copied = false

    var body: some View {
        Form {
            if let info {
                overview(info)
                processor(info)
                memory(info)
                storage(info)
                displays(info)
                security(info)
                system(info)
            } else {
                HStack {
                    ProgressView().controlSize(.small)
                    BilingualLabel(en: "Collecting system information…", ru: "Собираем информацию о системе…")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button {
                    load()
                } label: {
                    BilingualLabel(en: "Refresh", ru: "Обновить")
                }
                .disabled(isLoading)
                Button {
                    copyReport()
                } label: {
                    BilingualLabel(en: "Copy Report", ru: "Скопировать отчёт")
                }
                .disabled(info == nil)
                if isLoading, info != nil {
                    ProgressView().controlSize(.small)
                } else if copied {
                    BilingualLabel(
                        en: showSerial ? "Copied" : "Copied (serial number hidden)",
                        ru: showSerial ? "Скопировано" : "Скопировано (серийный номер скрыт)"
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { if info == nil { load() } }
    }

    // MARK: - Sections

    private func overview(_ info: SystemInfo) -> some View {
        Section {
            row("Model", "Модель", info.marketingName)
            row("Model Identifier", "Идентификатор модели", info.modelIdentifier)
            if let number = info.modelNumber {
                row("Model Number", "Номер модели", number)
            }
            if let serial = info.serialNumber {
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(showSerial ? serial : masked(serial))
                            .textSelection(.enabled)
                            .monospaced()
                        Button {
                            showSerial.toggle()
                        } label: {
                            Image(systemName: showSerial ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(language == .en ? "Show / hide" : "Показать / скрыть")
                    }
                } label: {
                    BilingualLabel(en: "Serial Number", ru: "Серийный номер")
                }
            }
            row("macOS", "macOS", [info.macOSName, info.macOSVersion, "(\(info.buildVersion))"]
                .compactMap { $0 }.joined(separator: " "))
        } header: {
            BilingualLabel(en: "Overview", ru: "Обзор")
        }
    }

    private func processor(_ info: SystemInfo) -> some View {
        Section {
            row("Chip", "Чип", info.chip)
            row("CPU Cores", "Ядра CPU", coresDescription(info))
            if let gpu = info.gpuCores {
                row("GPU Cores", "Ядра GPU", "\(gpu)")
            }
            if let metal = info.metalSupport {
                row("Graphics API", "Графика", metal)
            }
            row("Architecture", "Архитектура", info.isAppleSilicon ? "Apple Silicon (arm64)" : "Intel (\(info.architecture))")
            if let rosetta = info.rosettaInstalled {
                row("Rosetta 2", "Rosetta 2", rosetta ? yes : BilingualText(en: "Not installed", ru: "Не установлена"))
            }
        } header: {
            BilingualLabel(en: "Processor & Graphics", ru: "Процессор и графика")
        }
    }

    private func memory(_ info: SystemInfo) -> some View {
        Section {
            row("Installed", "Установлено", [bytes(Int64(info.memoryBytes)), info.memoryType, info.memoryManufacturer.map { "(\($0))" }]
                .compactMap { $0 }.joined(separator: " "))
            if let used = info.memoryUsedBytes {
                row("In Use Now", "Используется сейчас", bytes(Int64(used)))
            }
            if let free = info.memoryFreePercent {
                LabeledContent {
                    Text("\(free)%")
                        .foregroundStyle(free < 20 ? .orange : .secondary)
                } label: {
                    BilingualLabel(en: "Available (memory pressure)", ru: "Свободно (по давлению памяти)")
                }
            }
            if let swap = info.swapUsedBytes {
                row("Swap Used", "Файл подкачки", bytes(Int64(swap)))
            }
            if let hint = memoryHint(info) {
                BilingualLabel(hint)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        } header: {
            BilingualLabel(en: "Memory", ru: "Память")
        }
    }

    private func storage(_ info: SystemInfo) -> some View {
        Section {
            if let disk = info.diskName {
                row("Drive", "Накопитель", disk)
            }
            if let total = info.volumeTotalBytes, let free = info.volumeFreeBytes, total > 0 {
                let used = total - free
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        BilingualLabel(en: "Macintosh HD", ru: "Macintosh HD")
                        Spacer()
                        BilingualLabel(
                            en: "\(bytes(free)) free of \(bytes(total))",
                            ru: "свободно \(bytes(free)) из \(bytes(total))"
                        )
                        .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(used), total: Double(total))
                        .tint(Double(free) / Double(total) < 0.1 ? .orange : .accentColor)
                }
                if Double(free) / Double(total) < 0.1 {
                    BilingualLabel(
                        en: "Less than 10% free — macOS slows down and updates may fail. Check the Storage and Cleanup tabs.",
                        ru: "Свободно меньше 10% — macOS начинает тормозить, обновления могут не установиться. Загляните во вкладки «Хранилище» и «Чистка»."
                    )
                    .font(.callout)
                    .foregroundStyle(.orange)
                }
            }
            if let smart = info.diskSmartStatus {
                LabeledContent {
                    Text(smart)
                        .foregroundStyle(smart == "Verified" ? Color.secondary : Color.red)
                } label: {
                    BilingualLabel(en: "S.M.A.R.T. Status", ru: "Статус S.M.A.R.T.")
                }
            }
        } header: {
            BilingualLabel(en: "Storage", ru: "Накопитель")
        }
    }

    private func displays(_ info: SystemInfo) -> some View {
        Section {
            ForEach(Array(info.displays.enumerated()), id: \.offset) { _, display in
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(display.points) @ \(display.refreshHz) Hz")
                        if let pixels = display.pixels {
                            BilingualLabel(en: "Retina, \(pixels) px", ru: "Retina, \(pixels) пикс.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(display.name)
                        BilingualLabel(en: display.isBuiltIn ? "Built-in" : "External", ru: display.isBuiltIn ? "Встроенный" : "Внешний")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            BilingualLabel(en: "Displays", ru: "Дисплеи")
        }
    }

    private func security(_ info: SystemInfo) -> some View {
        Section {
            securityRow("System Integrity Protection", "Защита целостности (SIP)", info.security.sip)
            securityRow("FileVault Disk Encryption", "Шифрование FileVault", info.security.fileVault)
            securityRow("Gatekeeper", "Gatekeeper", info.security.gatekeeper)
            securityRow("Firewall", "Брандмауэр", info.security.firewall)
            if [info.security.sip, info.security.fileVault, info.security.gatekeeper].contains(false) {
                BilingualLabel(
                    en: "Some core protections are off. Unless you disabled them on purpose, turn them back on in System Settings → Privacy & Security.",
                    ru: "Часть базовой защиты выключена. Если вы не отключали её намеренно, включите в «Системные настройки» → «Конфиденциальность и безопасность»."
                )
                .font(.callout)
                .foregroundStyle(.orange)
            }
        } header: {
            BilingualLabel(en: "Security", ru: "Безопасность")
        }
    }

    private func system(_ info: SystemInfo) -> some View {
        Section {
            row("Computer Name", "Имя компьютера", info.computerName)
            row("User", "Пользователь", info.userName)
            row("Kernel", "Ядро", info.kernelVersion)
            if let firmware = info.firmwareVersion {
                row("Firmware", "Прошивка", firmware)
            }
            if let boot = info.bootDate {
                row("Uptime", "Время работы", uptime(since: boot))
            }
            LabeledContent {
                BilingualLabel(thermal(info.thermalState))
                    .foregroundStyle(info.thermalState == .nominal ? Color.secondary : Color.orange)
            } label: {
                BilingualLabel(en: "Thermal State", ru: "Температурный режим")
            }
            row("Low Power Mode", "Режим энергосбережения", info.lowPowerMode ? yes : no)
        } header: {
            BilingualLabel(en: "System", ru: "Система")
        }
    }

    // MARK: - Rows & formatting

    private var yes: BilingualText { BilingualText(en: "Yes", ru: "Да") }
    private var no: BilingualText { BilingualText(en: "No", ru: "Нет") }

    private func row(_ en: String, _ ru: String, _ value: String) -> some View {
        LabeledContent {
            Text(value).textSelection(.enabled)
        } label: {
            BilingualLabel(en: en, ru: ru)
        }
    }

    private func row(_ en: String, _ ru: String, _ value: BilingualText) -> some View {
        LabeledContent {
            BilingualLabel(value)
        } label: {
            BilingualLabel(en: en, ru: ru)
        }
    }

    private func securityRow(_ en: String, _ ru: String, _ enabled: Bool?) -> some View {
        LabeledContent {
            if let enabled {
                Label {
                    BilingualLabel(en: enabled ? "On" : "Off", ru: enabled ? "Включено" : "Выключено")
                } icon: {
                    Image(systemName: enabled ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(enabled ? .green : .orange)
                }
            } else {
                BilingualLabel(en: "Unknown", ru: "Неизвестно").foregroundStyle(.secondary)
            }
        } label: {
            BilingualLabel(en: en, ru: ru)
        }
    }

    private func coresDescription(_ info: SystemInfo) -> String {
        guard let p = info.performanceCores, let e = info.efficiencyCores, info.isAppleSilicon else {
            return "\(info.totalCores)"
        }
        return language == .en
            ? "\(info.totalCores) (\(p) performance + \(e) efficiency)"
            : "\(info.totalCores) (\(p) производительных + \(e) энергоэффективных)"
    }

    private func memoryHint(_ info: SystemInfo) -> BilingualText? {
        let swapHeavy = (info.swapUsedBytes ?? 0) > info.memoryBytes / 4
        guard (info.memoryFreePercent ?? 100) < 20 || swapHeavy else { return nil }
        return BilingualText(
            en: "Memory is under pressure and macOS is swapping to disk — close heavy apps or browser tabs. If this is constant, the Mac needs more RAM than it has.",
            ru: "Памяти не хватает, macOS активно использует файл подкачки — закройте тяжёлые приложения или вкладки браузера. Если так постоянно, этому Mac не хватает оперативной памяти."
        )
    }

    private func masked(_ serial: String) -> String {
        String(repeating: "•", count: max(0, serial.count - 3)) + serial.suffix(3)
    }

    private func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: count > 0 && count % (1 << 30) == 0 ? .memory : .file)
    }

    private func uptime(since boot: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: language == .en ? "en_US" : "ru_RU")
        formatter.calendar = calendar
        return formatter.string(from: boot, to: Date()) ?? "?"
    }

    private func thermal(_ state: ProcessInfo.ThermalState) -> BilingualText {
        switch state {
        case .nominal: BilingualText(en: "Normal", ru: "Нормальный")
        case .fair: BilingualText(en: "Warm", ru: "Повышенный")
        case .serious: BilingualText(en: "Hot — throttling", ru: "Горячо — снижение частот")
        case .critical: BilingualText(en: "Critical", ru: "Критический")
        @unknown default: BilingualText(en: "Unknown", ru: "Неизвестно")
        }
    }

    // MARK: - Actions

    private func load() {
        isLoading = true
        copied = false
        let displays = SystemInfo.currentDisplays()
        Task {
            let loaded = await Task.detached { SystemInfo.load(displays: displays) }.value
            info = loaded
            isLoading = false
        }
    }

    /// Plain-text summary for pasting into a support chat or a sale listing.
    /// The serial number is only included while it's revealed on screen.
    private func copyReport() {
        guard let info else { return }
        let en = language == .en
        var lines: [String] = [
            info.marketingName,
            "\(en ? "Model Identifier" : "Идентификатор модели"): \(info.modelIdentifier)",
        ]
        if let number = info.modelNumber { lines.append("\(en ? "Model Number" : "Номер модели"): \(number)") }
        if showSerial, let serial = info.serialNumber { lines.append("\(en ? "Serial Number" : "Серийный номер"): \(serial)") }
        lines.append("macOS: \([info.macOSName, info.macOSVersion, "(\(info.buildVersion))"].compactMap { $0 }.joined(separator: " "))")
        lines.append("\(en ? "Chip" : "Чип"): \(info.chip), \(coresDescription(info))\(info.gpuCores.map { ", GPU \($0)" } ?? "")")
        lines.append("\(en ? "Memory" : "Память"): \([bytes(Int64(info.memoryBytes)), info.memoryType].compactMap { $0 }.joined(separator: " "))")
        if let disk = info.diskName, let total = info.volumeTotalBytes, let free = info.volumeFreeBytes {
            lines.append("\(en ? "Storage" : "Накопитель"): \(disk), \(bytes(total)) (\(en ? "free" : "свободно") \(bytes(free)))")
        }
        for display in info.displays {
            lines.append("\(en ? "Display" : "Дисплей"): \(display.name), \(display.pixels ?? display.points) @ \(display.refreshHz) Hz")
        }
        func flag(_ value: Bool?) -> String {
            guard let value else { return "?" }
            return value ? (en ? "on" : "вкл") : (en ? "off" : "выкл")
        }
        lines.append("SIP: \(flag(info.security.sip)), FileVault: \(flag(info.security.fileVault)), Gatekeeper: \(flag(info.security.gatekeeper)), \(en ? "Firewall" : "Брандмауэр"): \(flag(info.security.firewall))")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        copied = true
    }
}

#Preview {
    ThisMacView()
}
