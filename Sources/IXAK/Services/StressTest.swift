import Foundation

/// Runs CPU, RAM and disk stress/benchmark passes. All work happens locally,
/// nothing is uploaded or compared against a remote service.
final class StressTest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelledFlag = false

    func cancel() {
        setCancelled(true)
    }

    private func setCancelled(_ value: Bool) {
        lock.lock(); cancelledFlag = value; lock.unlock()
    }

    private var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelledFlag
    }

    /// Busy-loops every core for `duration` seconds.
    ///
    /// Uses `DispatchQueue.concurrentPerform` rather than Swift's structured
    /// concurrency task group: a tight loop with no `await` inside never
    /// yields back to the cooperative thread pool, which caps how many such
    /// tasks the pool lets run in parallel (observed as load stuck around
    /// 20% instead of saturating all cores). GCD's concurrent-perform uses
    /// real OS threads sized for exactly this kind of CPU-bound fan-out.
    func runCPU(duration: TimeInterval) async {
        setCancelled(false)
        let deadline = Date().addingTimeInterval(duration)
        let cores = CPUMonitor.coreCount

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                DispatchQueue.concurrentPerform(iterations: cores) { _ in
                    var x: Double = 1
                    while Date() < deadline {
                        if self?.isCancelled == true { break }
                        for _ in 0..<50_000 {
                            x = x * 1.0000001 + 0.0000001
                            x = x.squareRoot()
                        }
                    }
                    _ = x
                }
                continuation.resume()
            }
        }
    }

    /// Allocates `megabytes` of RAM, fills it, then verifies the pattern.
    /// Returns true if every byte read back matches what was written.
    func runRAM(megabytes: Int) -> Bool {
        let byteCount = megabytes * 1024 * 1024
        var buffer = [UInt8](repeating: 0, count: byteCount)

        for i in 0..<byteCount {
            buffer[i] = UInt8(truncatingIfNeeded: i)
            if isCancelled { return false }
        }

        for i in 0..<byteCount {
            if buffer[i] != UInt8(truncatingIfNeeded: i) {
                return false
            }
        }
        return true
    }

    /// Writes then reads a temp file, returns (writeMBps, readMBps).
    func runDiskSpeed(megabytes: Int = 512) throws -> (writeMBps: Double, readMBps: Double) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ixak-disk-test-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }

        let chunkSize = 4 * 1024 * 1024
        let chunks = (megabytes * 1024 * 1024) / chunkSize
        var chunk = Data(count: chunkSize)
        chunk.withUnsafeMutableBytes { ptr in
            arc4random_buf(ptr.baseAddress, chunkSize)
        }

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let writeHandle = try FileHandle(forWritingTo: url)

        let writeStart = Date()
        for _ in 0..<chunks {
            writeHandle.write(chunk)
        }
        try writeHandle.synchronize()
        try writeHandle.close()
        let writeElapsed = Date().timeIntervalSince(writeStart)

        let readStart = Date()
        let readHandle = try FileHandle(forReadingFrom: url)
        while try readHandle.read(upToCount: chunkSize) != nil {}
        try readHandle.close()
        let readElapsed = Date().timeIntervalSince(readStart)

        let totalMB = Double(chunks * chunkSize) / (1024 * 1024)
        return (totalMB / writeElapsed, totalMB / readElapsed)
    }
}
