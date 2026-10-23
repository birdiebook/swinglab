import CoreMotion
import Foundation
import Capture

/// Telefonens lodlinje under en serie (S6b, BESLUT B39): `CMDeviceMotion.gravity` i
/// `Plumb.sampleInterval` medan serien spelas in. Appen ger bara proven; medianen, spärren
/// för rörelse och vridningen till kamerans ram räknas i SwingLabKit (`Plumb`, Lodlinje.swift).
/// `CMMotionManager` kräver ingen tillåtelse (NSMotionUsageDescription gäller rörelse-
/// aktiviteten och stegen, inte gravitationen). Simulatorn har ingen rörelse: inga prov, och
/// serien får ingen lodlinje. METOD MS17
final class GravityRecorder: @unchecked Sendable {
    /// En CMMotionManager i appen (Apples råd).
    static let shared = GravityRecorder()

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    private let lock = NSLock()
    private var samples: [GravitySample] = []

    /// Börjar samla prov (en ny serie). Provets tid är `CMLogItem.timestamp`, värdklockan.
    func start() {
        lock.withLock { samples = [] }
        guard manager.isDeviceMotionAvailable else { return }
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        manager.deviceMotionUpdateInterval = Plumb.sampleInterval
        manager.startDeviceMotionUpdates(to: queue) { [weak self] m, _ in
            guard let self, let m else { return }
            let g = m.gravity
            let s = GravitySample(host: m.timestamp, x: g.x, y: g.y, z: g.z)
            self.lock.withLock { self.samples.append(s) }
        }
    }

    /// Slutar och svarar seriens prov.
    func stop() -> [GravitySample] {
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        return lock.withLock {
            let s = samples
            samples = []
            return s
        }
    }
}
