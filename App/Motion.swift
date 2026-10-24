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
    /// En serie samlar prov (`start` till `stop`).
    private var recording = false
    /// Uppställningens lutning (S6c-2, `LutningVy`): hur många som vill se den, och det senaste provet.
    private var live = 0
    private var latestSample: GravitySample?

    /// Det senaste provet, för uppställningens lutning (METOD MS19); nil utan rörelse (simulatorn).
    var latest: GravitySample? { lock.withLock { latestSample } }

    /// Uppställningens lutning vill ha prov (S6c-2): rörelsen startas om den inte går.
    func startLive() {
        let starta: Bool = lock.withLock {
            live += 1
            return !recording
        }
        if starta { run(token: nil) }
    }

    /// Lutningen syns inte längre: rörelsen stoppas om ingen serie samlar.
    func stopLive() {
        let stoppa: Bool = lock.withLock {
            live = max(0, live - 1)
            if live == 0 { latestSample = nil }
            return live == 0 && !recording
        }
        if stoppa, manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
    }

    /// Rörelsen med serien `token` (nil = bara lutningen).
    private func run(token: Int?) {
        guard manager.isDeviceMotionAvailable else { return }
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        manager.deviceMotionUpdateInterval = Plumb.sampleInterval
        manager.startDeviceMotionUpdates(to: queue) { [weak self] m, _ in
            guard let self, let m else { return }
            let g = m.gravity
            let s = GravitySample(host: m.timestamp, x: g.x, y: g.y, z: g.z)
            self.lock.withLock {
                self.latestSample = s
                if let token, self.current == token { self.samples.append(s) }
            }
        }
    }

    /// Börjar samla prov för en ny serie och svarar dess token. Provets tid är
    /// `CMLogItem.timestamp`, värdklockan.
    func start() -> Int {
        let token: Int = lock.withLock {
            current += 1
            samples = []
            recording = true
            return current
        }
        run(token: token)
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
            recording = false
            return s
        }
        guard let s else { return [] }
        // Lutningen i uppställningen syns fortfarande: rörelsen fortsätter utan serie.
        let liveKvar = lock.withLock { live > 0 }
        if liveKvar { run(token: nil) } else if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        return s
    }
}
