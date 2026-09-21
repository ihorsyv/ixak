import Foundation
import IOKit

struct BatteryInfo {
    let cycleCount: Int
    let designCapacity: Int
    let maxCapacity: Int
    let currentCapacity: Int
    let isCharging: Bool
    let temperatureCelsius: Double?
    let condition: BilingualText

    var healthPercent: Double {
        guard designCapacity > 0 else { return 0 }
        return (Double(maxCapacity) / Double(designCapacity)) * 100
    }

    var chargePercent: Double {
        guard maxCapacity > 0 else { return 0 }
        return (Double(currentCapacity) / Double(maxCapacity)) * 100
    }

    /// Reads live values from the AppleSmartBattery IOService.
    /// Returns nil on desktop Macs without a battery.
    static func read() -> BatteryInfo? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var propsUnmanaged: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &propsUnmanaged, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let props = propsUnmanaged?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        let cycleCount = props["CycleCount"] as? Int ?? 0
        let designCapacity = props["DesignCapacity"] as? Int ?? 0
        let maxCapacity = props["AppleRawMaxCapacity"] as? Int ?? props["MaxCapacity"] as? Int ?? 0
        let currentCapacity = props["AppleRawCurrentCapacity"] as? Int ?? props["CurrentCapacity"] as? Int ?? 0
        let isCharging = props["IsCharging"] as? Bool ?? false

        // Temperature is reported in tenths of a degree Celsius.
        let temperature: Double?
        if let raw = props["Temperature"] as? Int {
            temperature = Double(raw) / 100.0
        } else {
            temperature = nil
        }

        let permanentFailure = props["PermanentFailureStatus"] as? Int ?? 0
        let condition: BilingualText
        if permanentFailure != 0 {
            condition = BilingualText(en: "Service Recommended", ru: "Требуется обслуживание")
        } else if designCapacity > 0 && Double(maxCapacity) / Double(designCapacity) < 0.8 {
            condition = BilingualText(en: "Replace Soon", ru: "Скоро замена")
        } else {
            condition = BilingualText(en: "Normal", ru: "В норме")
        }

        return BatteryInfo(
            cycleCount: cycleCount,
            designCapacity: designCapacity,
            maxCapacity: maxCapacity,
            currentCapacity: currentCapacity,
            isCharging: isCharging,
            temperatureCelsius: temperature,
            condition: condition
        )
    }
}
