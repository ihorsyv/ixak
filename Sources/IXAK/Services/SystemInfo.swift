import AppKit
import Foundation
import IOKit

/// Everything shown on the "This Mac" tab. Gathered locally from sysctl,
/// IOKit, NSScreen and one `system_profiler` call — no admin rights and no
/// network access needed.
struct SystemInfo {
    struct Display {
        let name: String
        let points: String
        let pixels: String?
        let refreshHz: Int
        let isBuiltIn: Bool
    }

    struct SecurityStatus {
        let sip: Bool?
        let fileVault: Bool?
        let gatekeeper: Bool?
        let firewall: Bool?
    }

    // Overview
    let marketingName: String
    let modelIdentifier: String
    let modelNumber: String?
    let serialNumber: String?
    let macOSVersion: String
    let macOSName: String?
    let buildVersion: String

    // Processor & graphics
    let chip: String
    let totalCores: Int
    let performanceCores: Int?
    let efficiencyCores: Int?
    let gpuCores: Int?
    let metalSupport: String?
    let architecture: String
    let rosettaInstalled: Bool?

    // Memory
    let memoryBytes: UInt64
    let memoryType: String?
    let memoryManufacturer: String?
    let memoryUsedBytes: UInt64?
    let memoryFreePercent: Int?
    let swapUsedBytes: UInt64?

    // Storage (startup volume)
    let diskName: String?
    let diskSmartStatus: String?
    let volumeTotalBytes: Int64?
    let volumeFreeBytes: Int64?

    let displays: [Display]
    let security: SecurityStatus

    // System
    let computerName: String
    let userName: String
    let kernelVersion: String
    let firmwareVersion: String?
    let bootDate: Date?
    let thermalState: ProcessInfo.ThermalState
    let lowPowerMode: Bool

    var isAppleSilicon: Bool { architecture == "arm64" }

    /// Runs the slow parts (system_profiler, security CLIs) — call off the
    /// main thread. Displays come from NSScreen, which is main-thread only.
    static func load(displays: [Display]) -> SystemInfo {
        let profile = SystemProfiler.read()
        let hardware = profile.first("SPHardwareDataType")
        let gpu = profile.first("SPDisplaysDataType")
        let memory = profile.first("SPMemoryDataType")
        let startupVolume = (profile.items("SPStorageDataType"))
            .first { $0["mount_point"] as? String == "/" }
        let drive = startupVolume?["physical_drive"] as? [String: Any]

        let os = ProcessInfo.processInfo.operatingSystemVersion
        let machine = sysctlString("hw.machine") ?? ""
        let rootValues = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ])
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let chip = hardware?["chip_type"] as? String
            ?? sysctlString("machdep.cpu.brand_string")
            ?? "?"

        return SystemInfo(
            marketingName: ioDeviceTreeProductName()
                ?? hardware?["machine_name"] as? String
                ?? "Mac",
            modelIdentifier: sysctlString("hw.model") ?? "?",
            modelNumber: hardware?["model_number"] as? String,
            serialNumber: platformSerialNumber(),
            macOSVersion: "\(os.majorVersion).\(os.minorVersion)" + (os.patchVersion > 0 ? ".\(os.patchVersion)" : ""),
            macOSName: macOSMarketingName(major: os.majorVersion),
            buildVersion: sysctlString("kern.osversion") ?? "?",
            chip: chip,
            totalCores: ProcessInfo.processInfo.processorCount,
            performanceCores: sysctlInt("hw.perflevel0.physicalcpu"),
            efficiencyCores: sysctlInt("hw.perflevel1.physicalcpu"),
            gpuCores: (gpu?["sppci_cores"] as? String).flatMap(Int.init),
            metalSupport: (gpu?["spdisplays_mtlgpufamilysupport"] as? String)
                .map { $0.replacingOccurrences(of: "spdisplays_metal", with: "Metal ") },
            architecture: machine,
            rosettaInstalled: machine == "arm64"
                ? FileManager.default.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
                : nil,
            memoryBytes: memoryBytes,
            memoryType: memory?["dimm_type"] as? String,
            memoryManufacturer: memory?["dimm_manufacturer"] as? String,
            memoryUsedBytes: usedMemoryBytes(),
            memoryFreePercent: sysctlInt("kern.memorystatus_level"),
            swapUsedBytes: swapUsedBytes(),
            diskName: drive?["device_name"] as? String,
            diskSmartStatus: drive?["smart_status"] as? String,
            volumeTotalBytes: rootValues?.volumeTotalCapacity.map(Int64.init),
            volumeFreeBytes: rootValues?.volumeAvailableCapacityForImportantUsage,
            displays: displays,
            security: SecurityStatus(
                sip: commandOutput("/usr/bin/csrutil", ["status"]).map { $0.contains("enabled") },
                fileVault: commandOutput("/usr/bin/fdesetup", ["status"]).map { $0.contains("is On") },
                gatekeeper: commandOutput("/usr/sbin/spctl", ["--status"]).map { $0.contains("assessments enabled") },
                firewall: commandOutput("/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"])
                    .map { $0.contains("enabled") }
            ),
            computerName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            userName: NSFullUserName().isEmpty ? NSUserName() : "\(NSFullUserName()) (\(NSUserName()))",
            kernelVersion: "Darwin " + (sysctlString("kern.osrelease") ?? "?"),
            firmwareVersion: hardware?["boot_rom_version"] as? String,
            bootDate: bootDate(),
            thermalState: ProcessInfo.processInfo.thermalState,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    // MARK: - Sources

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    private static func bootDate() -> Date? {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
    }

    private static func swapUsedBytes() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return usage.xsu_used
    }

    /// Approximates Activity Monitor's "Memory Used": app (active) + wired + compressed pages.
    private static func usedMemoryBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * UInt64(vm_kernel_page_size)
    }

    /// Full marketing name with year, e.g. "MacBook Pro (13-inch, M1, 2020)".
    /// Only exposed on Apple Silicon; Intel Macs fall back to the short name.
    private static func ioDeviceTreeProductName() -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        guard let data = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Data else { return nil }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
    }

    private static func platformSerialNumber() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }

    private static func macOSMarketingName(major: Int) -> String? {
        switch major {
        case 26: "Tahoe"
        case 15: "Sequoia"
        case 14: "Sonoma"
        case 13: "Ventura"
        case 12: "Monterey"
        case 11: "Big Sur"
        default: nil
        }
    }

    @MainActor
    static func currentDisplays() -> [Display] {
        NSScreen.screens.map(display(for:))
    }

    @MainActor
    private static func display(for screen: NSScreen) -> Display {
        let size = screen.frame.size
        let scale = screen.backingScaleFactor
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return Display(
            name: screen.localizedName,
            points: "\(Int(size.width)) × \(Int(size.height))",
            pixels: scale > 1 ? "\(Int(size.width * scale)) × \(Int(size.height * scale))" : nil,
            refreshHz: screen.maximumFramesPerSecond,
            isBuiltIn: id.map { CGDisplayIsBuiltin($0) != 0 } ?? false
        )
    }

    private static func commandOutput(_ executable: String, _ arguments: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}

/// One `system_profiler -json` call covering the data types that have no
/// public API (model number, GPU core count, RAM type, SSD model/SMART).
private struct SystemProfiler {
    let root: [String: Any]

    func items(_ type: String) -> [[String: Any]] {
        root[type] as? [[String: Any]] ?? []
    }

    func first(_ type: String) -> [String: Any]? {
        items(type).first
    }

    static func read() -> SystemProfiler {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = [
            "SPHardwareDataType", "SPDisplaysDataType", "SPMemoryDataType", "SPStorageDataType",
            "-json", "-detailLevel", "mini",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return SystemProfiler(root: [:]) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return SystemProfiler(root: json ?? [:])
    }
}
