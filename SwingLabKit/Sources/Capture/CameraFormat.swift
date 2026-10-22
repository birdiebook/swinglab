import Foundation

/// Ett `AVCaptureDevice.Format` som värde (S2_SPEC §2.2). App/Camera.swift fyller i det
/// ur `device.formats`; valet görs här, ur det telefonen själv rapporterar och
/// aldrig ur en modellista (iPhone 17 och iPhone 13 ger olika listor).
public struct CameraFormat: Codable, Equatable, Sendable {
    /// Plats i device.formats.
    public var index: Int
    /// Lagrad storlek (liggande), CMVideoFormatDescriptionGetDimensions.
    public var width: Int
    public var height: Int
    /// Högsta maxFrameRate över videoSupportedFrameRateRanges.
    public var maxFrameRate: Double
    /// videoFieldOfView: vågrätt i grader i sensorns liggande läge. 0 = okänt.
    public var fieldOfView: Double
    /// isVideoBinned.
    public var binned: Bool
    public var minISO: Double
    public var maxISO: Double
    /// minExposureDuration och maxExposureDuration, s.
    public var minExposure: Double
    public var maxExposure: Double
    /// Pixelformatet är 10-bitars ('x420' eller 'x422').
    public var tenBit: Bool
    /// isVideoHDRSupported.
    public var hdrSupported: Bool

    public init(index: Int, width: Int, height: Int, maxFrameRate: Double, fieldOfView: Double, binned: Bool,
                minISO: Double, maxISO: Double, minExposure: Double, maxExposure: Double,
                tenBit: Bool, hdrSupported: Bool) {
        self.index = index
        self.width = width
        self.height = height
        self.maxFrameRate = maxFrameRate
        self.fieldOfView = fieldOfView
        self.binned = binned
        self.minISO = minISO
        self.maxISO = maxISO
        self.minExposure = minExposure
        self.maxExposure = maxExposure
        self.tenBit = tenBit
        self.hdrSupported = hdrSupported
    }
}

/// Formatvalet. METOD MS1
public enum FormatChoice {
    /// Storleken som krävs (lagrad, liggande). METOD MS1
    public static let width = 1920
    public static let height = 1080
    /// Lägsta frekvens när inget format når den önskade. METOD MS1
    public static let fallbackMinRate = 120.0
    /// Frekvensen räknas som nådd inom så mycket (flyttal i rapporten). METOD MS1
    public static let rateSlack = 0.5

    /// Formatet når den önskade frekvensen. Annars visar vyn frekvensen i gult.
    public static func reaches(_ f: CameraFormat, wantedRate: Double = 240) -> Bool {
        f.maxFrameRate >= wantedRate - rateSlack
    }

    /// Ordningen bland format med samma frekvenskrav: störst synfält, sedan binnat
    /// (mer ljuskänsligt), sedan 8-bitars före 10-bitars, sedan lägst index.
    static func battre(_ a: CameraFormat, _ b: CameraFormat) -> Bool {
        if a.fieldOfView != b.fieldOfView { return a.fieldOfView > b.fieldOfView }
        if a.binned != b.binned { return a.binned }
        if a.tenBit != b.tenBit { return !a.tenBit }
        return a.index < b.index
    }

    /// Det valda formatets `index` (platsen i device.formats), eller nil. Exakt
    /// 1920 × 1080 och minst wantedRate; finns inget, högst frekvens ≥ 120 i 1080p
    /// (samma ordning vid lika frekvens). METOD MS1
    public static func choose(_ formats: [CameraFormat], wantedRate: Double = 240) -> Int? {
        let hd = formats.filter { $0.width == width && $0.height == height && $0.maxFrameRate.isFinite }
        let nar = hd.filter { reaches($0, wantedRate: wantedRate) }
        if let b = nar.min(by: battre) { return b.index }
        let reserv = hd.filter { $0.maxFrameRate >= fallbackMinRate - rateSlack }
        let bast = reserv.min { a, b in
            a.maxFrameRate != b.maxFrameRate ? a.maxFrameRate > b.maxFrameRate : battre(a, b)
        }
        return bast?.index
    }
}
