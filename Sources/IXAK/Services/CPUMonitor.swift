import Foundation

/// Reads system-wide CPU load via the Mach host_processor_info API.
enum CPUMonitor {
    static func currentLoadPercent() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )
        guard result == KERN_SUCCESS else { return 0 }

        defer {
            let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        var totalUsed: UInt32 = 0
        var totalTicks: UInt32 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt32(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = UInt32(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let nice = UInt32(cpuInfo[offset + Int(CPU_STATE_NICE)])
            let idle = UInt32(cpuInfo[offset + Int(CPU_STATE_IDLE)])

            totalUsed += user + system + nice
            totalTicks += user + system + nice + idle
        }

        guard totalTicks > 0 else { return 0 }
        return (Double(totalUsed) / Double(totalTicks)) * 100
    }

    static var coreCount: Int {
        ProcessInfo.processInfo.activeProcessorCount
    }
}
