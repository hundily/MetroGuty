import AVFoundation
import os

/// Evento visual de tempo, com o instante (host time) em que o som sai no alto-falante.
struct BeatEvent {
    var beat: Int
    var isDownbeat: Bool
    var hostTime: UInt64
}

/// Motor de áudio do MetroGuty.
///
/// Diferente do site (Web Audio + lookahead com setTimeout), aqui o sequenciador roda
/// dentro do callback de render, então cada clique cai no sample exato.
final class AudioEngine: @unchecked Sendable {
    struct Params {
        var bpm: Double = 120
        var beatsPerBar = 4
        var accent = true
        var soundIndex = 11
        var subdivisionIndex = 1
        var masterVolume: Float = 1
        var silentEnabled = false
        var playedBars = 3
        var silentBars = 1
        var silentRandom = false
    }

    private struct Sample {
        var left: [Float]
        var right: [Float]
    }

    private struct Voice {
        var sample = -1
        var pos = 0
        var gain: Float = 0
    }

    // Mesmos ganhos do site: downbeat 1.0, tempos 0.85, subdivisões 0.5.
    private let downbeatGain: Float = 1.0
    private let beatsGain: Float = 0.85
    private let divGain: Float = 0.5

    private let sampleRate: Double = 44_100
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    private let lock = OSAllocatedUnfairLock()

    private var samples: [Sample] = []
    private var banks: [(downbeat: Int, beats: Int, div: Int)] = []
    private let patterns: [[Bool]] = Catalog.subdivisions.map { $0.pattern.map { $0 == 1 } }
    private let divTakesBeatVolume: [Bool] = Catalog.subdivisions.map(\.divTakesBeatVolume)

    // Estado protegido por `lock` (compartilhado com o thread de áudio).
    private var params = Params()
    private var playing = false
    private var renderedFrames: Int64 = 0
    private var nextNoteFrame: Double = 0
    private var subSlot = 0
    private var currentBeat = 0
    private var currentBar = 1
    private var barSilent = false
    private var voices = [Voice](repeating: Voice(), count: 64)
    private var events: [BeatEvent] = []

    private let ticksPerSecond: Double
    private var latencyTicks: UInt64 = 0

    init() {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        ticksPerSecond = 1e9 * Double(tb.denom) / Double(tb.numer)
        events.reserveCapacity(256)

        loadSamples()

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        sourceNode = AVAudioSourceNode(format: format) { [unowned self] _, timestamp, frameCount, abl in
            self.render(frameCount: Int(frameCount), timestamp: timestamp, abl: abl)
            return noErr
        }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            self?.startEngine()
        }
        startEngine()
    }

    private func startEngine() {
        engine.prepare()
        do {
            try engine.start()
        } catch {
            NSLog("MetroGuty: falha ao iniciar áudio: \(error)")
        }
        let latency = engine.outputNode.presentationLatency
        lock.withLock { latencyTicks = UInt64(max(0, latency) * ticksPerSecond) }
    }

    // MARK: - Amostras

    private func loadSamples() {
        var cache: [String: Int] = [:]
        func load(_ name: String) -> Int {
            if let idx = cache[name] { return idx }
            let sample = Self.decode(name) ?? Sample(left: [], right: [])
            samples.append(sample)
            cache[name] = samples.count - 1
            return samples.count - 1
        }
        banks = Catalog.sounds.map { s in
            let beats = load(s.beats)
            return (load(s.downbeat), beats, s.div.map(load) ?? beats)
        }
    }

    private static func decode(_ name: String) -> Sample? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "mp3")
                ?? Bundle.main.url(forResource: name, withExtension: "mp3"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let data = buffer.floatChannelData
        else {
            NSLog("MetroGuty: erro ao carregar amostra \(name)")
            return nil
        }
        let n = Int(buffer.frameLength)
        let left = Array(UnsafeBufferPointer(start: data[0], count: n))
        let right = buffer.format.channelCount > 1
            ? Array(UnsafeBufferPointer(start: data[1], count: n))
            : left
        return Sample(left: left, right: right)
    }

    // MARK: - Controle (thread principal)

    func update(_ change: (inout Params) -> Void) {
        lock.withLock {
            let oldSub = params.subdivisionIndex
            change(&params)
            params.bpm = min(300, max(10, params.bpm))
            if params.subdivisionIndex != oldSub { subSlot = 0 }
        }
    }

    func start() {
        lock.withLock {
            playing = true
            currentBeat = 0
            subSlot = 0
            currentBar = 1
            barSilent = false
            nextNoteFrame = Double(renderedFrames) + 0.05 * sampleRate
            events.removeAll(keepingCapacity: true)
        }
    }

    func stop() {
        lock.withLock {
            playing = false
            events.removeAll(keepingCapacity: true)
        }
    }

    /// Retorna o evento de tempo mais recente que já soou.
    func latestDueEvent() -> BeatEvent? {
        let now = mach_absolute_time()
        return lock.withLock {
            var last: BeatEvent?
            var keep = 0
            for e in events {
                if e.hostTime + latencyTicks <= now {
                    last = e
                } else {
                    events[keep] = e
                    keep += 1
                }
            }
            events.removeLast(events.count - keep)
            return last
        }
    }

    // MARK: - Thread de áudio

    private func render(frameCount: Int, timestamp: UnsafePointer<AudioTimeStamp>,
                        abl: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard buffers.count >= 2,
              let l = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let r = buffers[1].mData?.assumingMemoryBound(to: Float.self)
        else { return }
        l.update(repeating: 0, count: frameCount)
        r.update(repeating: 0, count: frameCount)

        let hostValid = timestamp.pointee.mFlags.contains(.hostTimeValid)
        let hostBase = hostValid ? timestamp.pointee.mHostTime : mach_absolute_time()

        lock.lock()
        defer { lock.unlock() }

        var f = 0
        while f < frameCount {
            var n = frameCount - f
            if playing {
                let now = Double(renderedFrames + Int64(f))
                while nextNoteFrame < now + 1 {
                    processSlot(hostTime: hostBase + UInt64(Double(f) / sampleRate * ticksPerSecond))
                }
                n = min(n, max(1, Int((nextNoteFrame - now).rounded(.up))))
            }
            mix(l + f, r + f, frames: n)
            f += n
        }
        renderedFrames += Int64(frameCount)

        let vol = params.masterVolume
        if vol != 1 {
            for i in 0..<frameCount {
                l[i] *= vol
                r[i] *= vol
            }
        }
    }

    private func processSlot(hostTime: UInt64) {
        let slots = patterns[params.subdivisionIndex]
        if subSlot >= slots.count { subSlot = 0 }

        let isMainBeat = subSlot == 0
        let muted = params.silentEnabled && barSilent

        if slots[subSlot] && !muted {
            let bank = banks[params.soundIndex]
            if isMainBeat {
                if currentBeat == 0 && params.accent {
                    trigger(bank.downbeat, gain: downbeatGain)
                } else {
                    trigger(bank.beats, gain: beatsGain)
                }
            } else {
                let gain = divTakesBeatVolume[params.subdivisionIndex] ? beatsGain : divGain
                trigger(bank.div, gain: gain)
            }
        }

        if isMainBeat && events.count < 256 {
            events.append(BeatEvent(beat: currentBeat, isDownbeat: currentBeat == 0, hostTime: hostTime))
        }

        nextNoteFrame += (60.0 / params.bpm) / Double(slots.count) * sampleRate
        subSlot += 1

        if subSlot >= slots.count {
            subSlot = 0
            currentBeat += 1
            if currentBeat >= params.beatsPerBar {
                currentBeat = 0
                onBarComplete()
            }
        }
    }

    private func onBarComplete() {
        currentBar += 1
        if params.silentEnabled {
            let cycle = params.playedBars + params.silentBars
            let pos = ((currentBar - 1) % cycle) + 1
            barSilent = params.silentRandom ? Double.random(in: 0..<1) < 0.35 : pos > params.playedBars
        } else {
            barSilent = false
        }
    }

    private func trigger(_ sample: Int, gain: Float) {
        guard !samples[sample].left.isEmpty else { return }
        var slot = 0
        var oldest = -1
        for i in voices.indices {
            if voices[i].sample < 0 { slot = i; oldest = -1; break }
            if voices[i].pos > oldest { oldest = voices[i].pos; slot = i }
        }
        voices[slot] = Voice(sample: sample, pos: 0, gain: gain)
    }

    private func mix(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, frames: Int) {
        for v in voices.indices where voices[v].sample >= 0 {
            let voice = voices[v]
            samples[voice.sample].left.withUnsafeBufferPointer { sl in
                samples[voice.sample].right.withUnsafeBufferPointer { sr in
                    let m = min(frames, sl.count - voice.pos)
                    for i in 0..<m {
                        l[i] += sl[voice.pos + i] * voice.gain
                        r[i] += sr[voice.pos + i] * voice.gain
                    }
                    if voice.pos + m >= sl.count {
                        voices[v].sample = -1
                    } else {
                        voices[v].pos += m
                    }
                }
            }
        }
    }
}
