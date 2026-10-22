import Foundation

/// Ljudet ur en fil i bitar, klippta exakt vid `ClickDetector.segments`-proven
/// (S2_SPEC §4.2, §12 S2c). Appen läser filen i små buffertar som AVAssetReader ger
/// dem; segmenteraren samlar proven och lämnar ut en bit när den är hel. Proven
/// räknas från filens första ljudprov, så att PC:ns bitar (`tools/pc/klick.py`
/// `bitar()`) börjar på samma prov och får samma median. METOD MS4
public struct AudioSegmenter {
    /// En bit: proven [början, slut) räknat från filens första ljudprov, och om
    /// början och slutet är inre bitgränser (en grannbit överlappar där).
    public struct Segment: Equatable, Sendable {
        public var range: Range<Int>
        public var samples: [Float]
        public var innerStart: Bool
        public var innerEnd: Bool
    }

    public let sampleRate: Double
    let length: Int
    let step: Int
    /// Proven från `start` och framåt som ännu inte lämnats ut i sin helhet.
    var buffer: [Float] = []
    var start = 0
    /// Prov mottagna hittills.
    public private(set) var received = 0

    public init(sampleRate: Double = 48_000, segment: Double = ClickDetector.segmentSeconds,
                overlap: Double = ClickDetector.overlapSeconds) {
        self.sampleRate = sampleRate
        let s = ClickDetector.segmentSamples(sampleRate: sampleRate, segment: segment, overlap: overlap)
        length = s.length
        step = s.step
    }

    /// Lägger till prov. En bit lämnas ut först när minst ett prov finns efter den:
    /// annars vet segmenteraren inte om den är den sista (den sista har inget inre slut).
    public mutating func feed(_ samples: [Float], emit: (Segment) throws -> Void) rethrows {
        buffer.append(contentsOf: samples)
        received += samples.count
        guard length > 0, step > 0 else { return }          // ogiltiga bitar: allt i en (som segments)
        while received > start + length {
            try emit(Segment(range: start..<(start + length), samples: Array(buffer[0..<length]),
                             innerStart: start > 0, innerEnd: true))
            buffer.removeFirst(step)
            start += step
        }
    }

    /// Den sista biten, [start, slut). Anropas en gång när filen är slut.
    public mutating func finish(emit: (Segment) throws -> Void) rethrows {
        try emit(Segment(range: start..<received, samples: buffer, innerStart: start > 0, innerEnd: false))
        buffer = []
        start = received
    }
}

/// Klickjakten på ett ljud som läses i omgångar: `detect` per bit med de inre
/// gränserna och `merge` på slutet. Ger exakt samma klick som
/// `ClickDetector.detectSegmented` på hela signalen. METOD MS4
public struct ClickStream {
    public let params: ClickDetector.Params
    var segmenter: AudioSegmenter
    var parts: [(start: Double, clicks: [Click])] = []

    public init(sampleRate: Double = 48_000, params: ClickDetector.Params = .init(),
                segment: Double = ClickDetector.segmentSeconds, overlap: Double = ClickDetector.overlapSeconds) {
        self.params = params
        segmenter = AudioSegmenter(sampleRate: sampleRate, segment: segment, overlap: overlap)
    }

    /// Prov mottagna hittills.
    public var sampleCount: Int { segmenter.received }

    public mutating func feed(_ samples: [Float]) {
        var nya: [(start: Double, clicks: [Click])] = []
        let p = params
        let sr = segmenter.sampleRate
        segmenter.feed(samples) { s in nya.append(Self.run(s, sampleRate: sr, params: p)) }
        parts.append(contentsOf: nya)
    }

    /// Klicken med tiden från filens första ljudprov.
    public mutating func finish() -> [Click] {
        var nya: [(start: Double, clicks: [Click])] = []
        let p = params
        let sr = segmenter.sampleRate
        segmenter.finish { s in nya.append(Self.run(s, sampleRate: sr, params: p)) }
        parts.append(contentsOf: nya)
        return ClickDetector.merge(parts, minGap: params.minGap)
    }

    static func run(_ s: AudioSegmenter.Segment, sampleRate: Double,
                    params: ClickDetector.Params) -> (start: Double, clicks: [Click]) {
        (start: Double(s.range.lowerBound) / sampleRate,
         clicks: ClickDetector.detect(s.samples, sampleRate: sampleRate, params: params,
                                      innerStart: s.innerStart, innerEnd: s.innerEnd))
    }
}
