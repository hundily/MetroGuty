import Foundation
import Observation

struct SpeedTraining: Codable, Equatable {
    var enabled = false
    var totalMinutes = 5
    var startBpm = 80
    var endBpm = 90
    var stepBpm = 1
    var intervalSeconds = 20
}

private struct Preset: Codable {
    var bpm: Int
    var beatsPerBar: Int
    var accentDownBeat: Bool
    var soundIndex: Int
    var subdivisionIndex: Int
    var volume: Int
}

@MainActor
@Observable
final class MetronomeModel {
    @ObservationIgnored private let audio = AudioEngine()
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var secondTimer: Timer?
    @ObservationIgnored private var visualTimer: Timer?
    @ObservationIgnored private var tapHistory: [Date] = []
    @ObservationIgnored private var prevVolume = 80
    @ObservationIgnored private var speedSessionRunning = false

    // MARK: Estado principal

    private(set) var bpm = 120 { didSet { audio.update { $0.bpm = Double(bpm) } } }
    private(set) var isPlaying = false
    var beatsPerBar = 4 { didSet { audio.update { $0.beatsPerBar = beatsPerBar } } }
    var accentDownBeat = true { didSet { audio.update { $0.accent = accentDownBeat } } }
    var flashEnabled = false
    var soundIndex = 11 {
        didSet {
            audio.update { $0.soundIndex = soundIndex }
            defaults.set(soundIndex, forKey: "metronoguty_sound")
        }
    }
    var subdivisionIndex = 1 {
        didSet {
            audio.update { $0.subdivisionIndex = subdivisionIndex }
            defaults.set(subdivisionIndex, forKey: "metronoguty_subdivision")
        }
    }
    private(set) var volume = 100 {
        didSet {
            audio.update { $0.masterVolume = Float(volume) / 100 }
            defaults.set(volume, forKey: "metronoguty_volume")
        }
    }

    // Visual
    private(set) var activeBeat: Int?
    private(set) var activeIsDownbeat = false
    private(set) var flashOn = false
    private(set) var tapPulse = false

    // Cronômetro
    private(set) var stopwatchSeconds = 0

    // Speed Training
    var speed = SpeedTraining() {
        didSet {
            if let data = try? JSONEncoder().encode(speed) {
                defaults.set(data, forKey: "metronoguty_speed_training")
            }
        }
    }
    private(set) var speedElapsed = 0

    // Ritmo interno (Silent Bars)
    var silentBarsEnabled = false { didSet { audio.update { $0.silentEnabled = silentBarsEnabled } } }
    var playedBars = 3 { didSet { audio.update { $0.playedBars = playedBars } } }
    var silentBars = 1 { didSet { audio.update { $0.silentBars = silentBars } } }
    var silentRandom = false { didSet { audio.update { $0.silentRandom = silentRandom } } }

    // Presets
    private(set) var savedPresets: Set<Int> = []

    init() {
        if defaults.object(forKey: "metronoguty_volume") != nil {
            volume = min(100, max(0, defaults.integer(forKey: "metronoguty_volume")))
        }
        if let s = defaults.object(forKey: "metronoguty_sound") as? Int, Catalog.sounds.indices.contains(s) {
            soundIndex = s
        }
        if let s = defaults.object(forKey: "metronoguty_subdivision") as? Int, Catalog.subdivisions.indices.contains(s) {
            subdivisionIndex = s
        }
        if let data = defaults.data(forKey: "metronoguty_speed_training"),
           let cfg = try? JSONDecoder().decode(SpeedTraining.self, from: data) {
            speed = cfg
        }
        savedPresets = Set((1...4).filter { defaults.data(forKey: "metronoguty_p\($0)") != nil })

        audio.update {
            $0.bpm = Double(bpm)
            $0.beatsPerBar = beatsPerBar
            $0.accent = accentDownBeat
            $0.soundIndex = soundIndex
            $0.subdivisionIndex = subdivisionIndex
            $0.masterVolume = Float(volume) / 100
        }
        if speed.enabled { setBpm(speed.startBpm) }
    }

    // MARK: Andamento

    var tempoMarking: String { Catalog.tempoMarking(for: bpm) }

    func setBpm(_ value: Int) {
        bpm = min(300, max(10, value))
    }

    func stepBpm(_ delta: Int) {
        setBpm(bpm + delta)
    }

    func tap() {
        let now = Date()
        if let last = tapHistory.last, now.timeIntervalSince(last) > 2.5 {
            tapHistory.removeAll()
        }
        tapHistory.append(now)
        if tapHistory.count > 5 { tapHistory.removeFirst() }
        if tapHistory.count >= 2 {
            let total = tapHistory.last!.timeIntervalSince(tapHistory.first!)
            let avg = total / Double(tapHistory.count - 1)
            setBpm(Int((60 / avg).rounded()))
        }
        tapPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.tapPulse = false }
    }

    // MARK: Volume

    func setVolume(_ value: Int) {
        volume = min(100, max(0, value))
    }

    func toggleMute() {
        if volume > 0 {
            prevVolume = volume
            setVolume(0)
        } else {
            setVolume(prevVolume > 0 ? prevVolume : 80)
        }
    }

    var volumeIcon: String {
        volume == 0 ? "🔇" : volume < 40 ? "🔉" : "🔊"
    }

    // MARK: Transporte

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !isPlaying else { return }
        audio.start()
        isPlaying = true
        if speed.enabled { startSpeedSession() }

        secondTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.secondTick() }
        }
        let vt = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.visualTick() }
        }
        RunLoop.main.add(vt, forMode: .common)
        visualTimer = vt
    }

    func pause() {
        guard isPlaying else { return }
        audio.stop()
        isPlaying = false
        speedSessionRunning = false
        secondTimer?.invalidate()
        visualTimer?.invalidate()
        secondTimer = nil
        visualTimer = nil
        activeBeat = nil
        flashOn = false
    }

    /// Botão ⏹: para, zera o cronômetro e o Speed Training.
    func stopAndReset() {
        pause()
        resetStopwatch()
        resetSpeedSession()
    }

    func resetStopwatch() {
        stopwatchSeconds = 0
    }

    var stopwatchText: String {
        let s = stopwatchSeconds
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return (h > 0 ? String(format: "%02d:", h) : "") + String(format: "%02d:%02d", m, sec)
    }

    private func secondTick() {
        stopwatchSeconds += 1
        if speedSessionRunning { speedTick() }
    }

    private func visualTick() {
        guard let e = audio.latestDueEvent() else { return }
        activeBeat = e.beat
        activeIsDownbeat = e.isDownbeat
        if flashEnabled {
            flashOn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.flashOn = false }
        }
    }

    // MARK: Speed Training

    func setSpeedEnabled(_ on: Bool) {
        speed.enabled = on
        if on && !isPlaying { setBpm(speed.startBpm) }
        if on && isPlaying { startSpeedSession() }
        if !on { speedSessionRunning = false }
    }

    private func startSpeedSession() {
        if speedElapsed == 0 { setBpm(speed.startBpm) }
        speedSessionRunning = speedElapsed < speed.totalMinutes * 60
    }

    private func speedTick() {
        let total = speed.totalMinutes * 60
        speedElapsed += 1
        let interval = max(1, speed.intervalSeconds)
        if speed.endBpm - speed.startBpm > 0 {
            let steps = speedElapsed / interval
            let target = min(speed.endBpm, max(speed.startBpm, speed.startBpm + steps * speed.stepBpm))
            if target != bpm { setBpm(target) }
        }
        if total > 0 && speedElapsed >= total {
            setBpm(speed.endBpm)
            speedSessionRunning = false
        }
    }

    func resetSpeedSession() {
        speedElapsed = 0
        if speed.enabled { setBpm(speed.startBpm) }
        if isPlaying && speed.enabled { startSpeedSession() } else { speedSessionRunning = false }
    }

    enum SpeedStatus { case ready, running, paused, done }

    var speedStatus: SpeedStatus {
        let total = speed.totalMinutes * 60
        if total > 0 && speedElapsed >= total { return .done }
        if isPlaying && speed.enabled { return .running }
        if speedElapsed > 0 { return .paused }
        return .ready
    }

    var speedProgress: Double {
        let total = Double(speed.totalMinutes * 60)
        return total > 0 ? min(1, Double(speedElapsed) / total) : 0
    }

    var speedSecondsUntilNext: Int {
        let interval = max(1, speed.intervalSeconds)
        return interval - (speedElapsed % interval)
    }

    var speedIntervalSummary: String {
        let delta = speed.endBpm - speed.startBpm
        guard delta > 0 else { return "Alvo igual ou menor que o inicial" }
        let steps = Int((Double(delta) / Double(speed.stepBpm)).rounded(.up))
        let total = steps * max(1, speed.intervalSeconds)
        let m = total / 60, s = total % 60
        let str = m > 0 ? (s > 0 ? "\(m)m \(s)s" : "\(m) min") : "\(s)s"
        return "Atinge \(speed.endBpm) BPM em ~\(str)"
    }

    func setSpeedTotalMinutes(_ v: Int) { speed.totalMinutes = min(180, max(1, v)) }

    func setSpeedStart(_ v: Int, pillJump: Bool = false) {
        speed.startBpm = min(pillJump ? 300 : 299, max(20, v))
        if speed.startBpm >= speed.endBpm {
            speed.endBpm = min(300, speed.startBpm + (pillJump ? 20 : 1))
        }
        if speed.enabled && !isPlaying { setBpm(speed.startBpm) }
    }

    func setSpeedEnd(_ v: Int, pillJump: Bool = false, clampToStart: Bool = false) {
        if clampToStart {
            speed.endBpm = min(300, max(speed.startBpm + 1, v))
            return
        }
        speed.endBpm = min(300, max(20, v))
        if speed.endBpm <= speed.startBpm {
            speed.startBpm = pillJump ? max(30, speed.endBpm - 20) : max(20, speed.endBpm - 1)
        }
    }

    func setSpeedStep(_ v: Int) { speed.stepBpm = min(50, max(1, v)) }
    func setSpeedInterval(_ v: Int) { speed.intervalSeconds = min(600, max(1, v)) }

    // MARK: Presets

    func presetTapped(_ slot: Int) {
        savedPresets.contains(slot) ? loadPreset(slot) : savePreset(slot)
    }

    func savePreset(_ slot: Int) {
        let p = Preset(bpm: bpm, beatsPerBar: beatsPerBar, accentDownBeat: accentDownBeat,
                       soundIndex: soundIndex, subdivisionIndex: subdivisionIndex, volume: volume)
        if let data = try? JSONEncoder().encode(p) {
            defaults.set(data, forKey: "metronoguty_p\(slot)")
            savedPresets.insert(slot)
        }
    }

    private func loadPreset(_ slot: Int) {
        guard let data = defaults.data(forKey: "metronoguty_p\(slot)"),
              let p = try? JSONDecoder().decode(Preset.self, from: data) else { return }
        setBpm(p.bpm)
        beatsPerBar = p.beatsPerBar
        setVolume(p.volume)
        accentDownBeat = p.accentDownBeat
        if Catalog.sounds.indices.contains(p.soundIndex) { soundIndex = p.soundIndex }
        if Catalog.subdivisions.indices.contains(p.subdivisionIndex) { subdivisionIndex = p.subdivisionIndex }
    }
}
