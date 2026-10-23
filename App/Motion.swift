import CoreMotion
import Foundation
import Capture

/// Telefonens lodlinje under en serie (S6b, BESLUT B39): `CMDeviceMotion.gravity` i
/// `Plumb.sampleInterval` medan serien spelas in. Appen ger bara proven; medianen, spärren
/// för rörelse och vridningen till kamerans ram räknas i SwingLabKit (`Plumb`, Lodlinje.swift).
/// Inspelaren delas i appen: `start()` ger en token och `stop(_:)` stoppar bara för den
/// senaste, så att en gammal serie inte stoppar eller tar en nyare series prov.
/// Simulatorn har ingen rörelse: inga prov, och serien får ingen lodlinje. METOD MS17
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
    private var current = 0

    /// Börjar samla prov för en ny serie och svarar dess token. Provets tid är
    /// `CMLogItem.timestamp`, värdklockan.
    func start() -> Int {
        let token: Int = lock.withLock {
            current += 1
            samples = []
            return current
        }
        guard manager.isDeviceMotionAvailable else { return token }
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        manager.deviceMotionUpdateInterval = Plumb.sampleInterval
        manager.startDeviceMotionUpdates(to: queue) { [weak self] m, _ in
            guard let self, let m else { return }
            let g = m.gravity
            let s = GravitySample(host: m.timestamp, x: g.x, y: g.y, z: g.z)
            self.lock.withLock {
                if self.current == token { self.samples.append(s) }
            }
        }
        return token
    }

    /// Slutar och svarar seriens prov, bara när `token` är den senaste serien; annars
    /// rörs inget och svaret är tomt.
    func stop(_ token: Int) -> [GravitySample] {
        let s: [GravitySample]? = lock.withLock {
            guard token == current else { return nil }
            let s = samples
            samples = []
            current += 1                    // sena prov från den här serien hamnar ingenstans
            return s
        }
        guard let s else { return [] }
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        return s
    }
}
