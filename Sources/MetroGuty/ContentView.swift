import SwiftUI

struct ContentView: View {
    @Environment(MetronomeModel.self) private var m

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                MainColumn()
                    .padding(24)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)

            // Flash de tela cheia
            Color.white.opacity(m.flashOn ? 0.12 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.linear(duration: 0.05), value: m.flashOn)
        }
        .preferredColorScheme(.dark)
    }
}

struct MainColumn: View {
    @Environment(MetronomeModel.self) private var m

    var body: some View {
        VStack(spacing: 18) {
            HeaderView()
            HStack(alignment: .top, spacing: 18) {
                RadarCard()
                ControlsCard()
            }
            SpeedTrainingCard()
            HStack(alignment: .top, spacing: 18) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Banco de Timbres (12 Timbres Reais)")
                        ChipGrid {
                            ForEach(Catalog.sounds.indices, id: \.self) { i in
                                GridChip(name: Catalog.sounds[i].name, svg: Icons.sounds[i],
                                         active: m.soundIndex == i) { m.soundIndex = i }
                            }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Subdivisões Rítmicas (16 Padrões com Notação Musical)")
                        ChipGrid {
                            ForEach(Catalog.subdivisions.indices, id: \.self) { i in
                                let sub = Catalog.subdivisions[i]
                                GridChip(name: sub.name, svg: Icons.subdivisions[i], desc: sub.desc,
                                         active: m.subdivisionIndex == i) { m.subdivisionIndex = i }
                            }
                        }
                    }
                }
            }
            TrainingTabsCard()
            Text("METROGUTY • Motor de Áudio Nativo (AVAudioEngine) • 100% Offline • Atalho: Barra de Espaço (Play/Pause), Setas (BPM), Tecla T (Tap)")
                .font(.system(size: 11))
                .foregroundStyle(Theme.labelTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
}

private struct ChipGrid<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) { content }
    }
}

// MARK: - Header

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: Logo.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 1) {
                Text("MetroGuty")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.3)
                Text("Motor Rítmico de Alta Precisão")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.labelSecondary)
            }
            Spacer()
        }
        .foregroundStyle(Theme.labelPrimary)
    }
}

// MARK: - Radar

private struct RadarCard: View {
    @Environment(MetronomeModel.self) private var m

    var body: some View {
        Card {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.02), .clear],
                                             center: .center, startRadius: 0, endRadius: 90))
                    Circle().stroke(Theme.separator, lineWidth: 1.5)
                    ForEach(0..<m.beatsPerBar, id: \.self) { i in
                        tick(i)
                    }
                    tempoDisplay
                }
                .frame(width: 250, height: 250)

                HStack(spacing: 8) {
                    ForEach([-5, -1, 1, 5], id: \.self) { d in
                        FillButton(height: 34, action: { m.stepBpm(d) }) {
                            Text(d > 0 ? "+\(d)" : "\(d)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        }
                    }
                }
                .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity, minHeight: 360)
        }
        .frame(maxWidth: .infinity)
    }

    private func tick(_ i: Int) -> some View {
        let angle = Double(i) / Double(m.beatsPerBar) * 2 * .pi - .pi / 2
        let active = m.activeBeat == i
        let down = active && m.activeIsDownbeat
        return Circle()
            .fill(down ? Theme.red : active ? Theme.cyan : Color.white.opacity(0.2))
            .overlay(Circle().stroke(active ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5))
            .frame(width: 12, height: 12)
            .scaleEffect(down ? 1.6 : active ? 1.4 : 1)
            .animation(.easeOut(duration: 0.12), value: active)
            .offset(x: 120 * cos(angle), y: 120 * sin(angle))
    }

    private var tempoDisplay: some View {
        EditableNumber(value: m.bpm, onCommit: { m.setBpm($0) },
                       fieldFont: .system(size: 54, weight: .bold, design: .monospaced),
                       fieldWidth: 150) {
            TempoReadout()
        }
    }
}

private struct TempoReadout: View {
    @Environment(MetronomeModel.self) private var m
    @State private var hover = false

    var body: some View {
        VStack(spacing: 2) {
            Text("\(m.bpm)")
                .font(.system(size: 80, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .tracking(-3)
                .foregroundStyle(hover ? Theme.cyan : Theme.labelPrimary)
                .contentTransition(.numericText())
            Text("BPM")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.labelSecondary)
            Text(m.tempoMarking)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.cyan)
                .padding(.top, 4)
            Text("2 cliques para editar")
                .font(.system(size: 10))
                .foregroundStyle(Theme.labelTertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(hover ? Theme.fill : .clear, in: RoundedRectangle(cornerRadius: Theme.radiusControl))
        .onHover { hover = $0 }
    }
}

// MARK: - Controles

private struct ControlsCard: View {
    @Environment(MetronomeModel.self) private var m

    var body: some View {
        @Bindable var m = m
        Card {
            VStack(spacing: 16) {
                // Tempo
                VStack(spacing: 8) {
                    labelRow("Tempo", "10 - 300 BPM")
                    HStack(spacing: 8) {
                        FillButton(width: 36, height: 36, action: { m.setBpm(120) }) {
                            SVGIcon(svg: Catalog.tempoIconSvg).foregroundStyle(Theme.cyan)
                        }
                        .help("Andamento / BPM (Clique para redefinir a 120)")
                        stepButton("−") { m.stepBpm(-1) }
                        Slider(value: Binding(get: { Double(m.bpm) }, set: { m.setBpm(Int($0.rounded())) }),
                               in: 10...300)
                            .tint(Theme.blue)
                        stepButton("+") { m.stepBpm(1) }
                    }
                }
                // Volume
                VStack(spacing: 8) {
                    labelRow("Volume", "\(m.volume)%")
                    HStack(spacing: 8) {
                        FillButton(width: 36, height: 36, action: m.toggleMute) {
                            Text(m.volumeIcon).font(.system(size: 15))
                        }
                        .help("Mutar / Ativar som")
                        stepButton("−") { m.setVolume(m.volume - 5) }
                        Slider(value: Binding(get: { Double(m.volume) }, set: { m.setVolume(Int($0.rounded())) }),
                               in: 0...100)
                            .tint(Theme.blue)
                        stepButton("+") { m.setVolume(m.volume + 5) }
                    }
                }

                // Compasso + Acento + Flash
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        meterPicker
                        Spacer(minLength: 0)
                        barToggles
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        meterPicker
                        barToggles
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Tempo decorrido
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TEMPO DECORRIDO")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.labelSecondary)
                        Text(m.stopwatchText)
                            .font(.system(size: 23, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                    }
                    Spacer()
                    FillButton(radius: 999, width: 90, height: 32, action: {
                        m.resetStopwatch()
                        m.resetSpeedSession()
                    }) {
                        Text("↺ Zerar").font(.system(size: 12, weight: .semibold))
                    }
                    .help("Zerar tempo decorrido")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: Theme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl).stroke(Theme.separatorSubtle))

                // Tap + transporte
                VStack(spacing: 10) {
                    FillButton(radius: Theme.radiusControl, height: 48, action: m.tap) {
                        Text("🔘  TAP TEMPO (Toque no ritmo)").font(.system(size: 14, weight: .semibold))
                    }
                    .scaleEffect(m.tapPulse ? 0.96 : 1)
                    .animation(.easeOut(duration: 0.1), value: m.tapPulse)

                    HStack(spacing: 10) {
                        PlayButton()
                        FillButton(radius: 999, width: 52, height: 52, action: m.stopAndReset) {
                            Text("⏹").font(.system(size: 17))
                        }
                        .help("Resetar")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var meterPicker: some View {
        HStack(spacing: 10) {
            Text("Compasso:")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.labelSecondary)
                .fixedSize()
            SegmentedChips(items: [2, 3, 4, 6], selected: m.beatsPerBar,
                           title: { $0 == 6 ? "6/8" : "\($0)/4" }) { m.beatsPerBar = $0 }
        }
    }

    private var barToggles: some View {
        @Bindable var m = m
        return HStack(spacing: 14) {
            GutyToggle(label: "Acento", isOn: $m.accentDownBeat)
                .help("Acentuar o primeiro tempo do compasso")
            GutyToggle(label: "Flash", isOn: $m.flashEnabled)
                .help("Piscar tela no tempo")
        }
    }

    private func labelRow(_ a: String, _ b: String) -> some View {
        HStack {
            Text(a)
            Spacer()
            Text(b).monospacedDigit()
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Theme.labelSecondary)
    }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        FillButton(width: 36, height: 36, action: action) {
            Text(label).font(.system(size: 18, weight: .bold, design: .monospaced))
        }
    }
}

private struct PlayButton: View {
    @Environment(MetronomeModel.self) private var m
    @State private var hover = false

    var body: some View {
        let color = m.isPlaying ? Theme.red : Theme.blue
        Button(action: m.togglePlayPause) {
            HStack(spacing: 10) {
                Text(m.isPlaying ? "⏸" : "▶")
                Text(m.isPlaying ? "PAUSAR" : "INICIAR").tracking(0.7)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color, in: Capsule())
            .shadow(color: color.opacity(0.3), radius: 7, y: 4)
            .opacity(hover ? 0.92 : 1)
            .offset(y: hover ? -1 : 0)
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
    }
}

// MARK: - Speed Training

private struct SpeedTrainingCard: View {
    @Environment(MetronomeModel.self) private var m

    var body: some View {
        Card(highlighted: m.speed.enabled) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if m.speed.enabled {
                    monitor
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                        params
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            SVGIcon(svg: Catalog.speedIconSvg)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.orange, in: RoundedRectangle(cornerRadius: 9))
                .shadow(color: Theme.orange.opacity(0.32), radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Speed Training").font(.system(size: 17, weight: .bold))
                Text("Treino de Velocidade e Aceleração Progressiva")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.labelSecondary)
            }
            Spacer()
            FillButton(radius: 999, width: 90, height: 30, action: m.resetSpeedSession) {
                Text("↺ Zerar").font(.system(size: 12, weight: .semibold))
            }
            .help("Zerar tempo decorrido e retornar ao BPM inicial")
            GutyToggle(label: m.speed.enabled ? "Ativo" : "Desligado",
                       isOn: Binding(get: { m.speed.enabled }, set: { m.setSpeedEnabled($0) }))
                .help("Ativar ou desativar o Speed Training")
        }
    }

    private var monitor: some View {
        let status = m.speedStatus
        let tag: String = switch status {
        case .done: "CONCLUÍDO! 🎯"
        case .running: "EM PROGRESSO ⚡"
        case .paused: "PAUSADO"
        case .ready: "PRONTO PARA INICIAR"
        }
        let running = status == .running || status == .done
        let total = m.speed.totalMinutes * 60
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tag)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(running ? Theme.green : Theme.labelSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(running ? Theme.green.opacity(0.16) : Theme.fill, in: Capsule())
                Spacer()
                Text("\(mmss(m.speedElapsed)) / \(mmss(total))")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.fill)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.orange)
                        .frame(width: g.size.width * m.speedProgress)
                        .animation(.easeOut(duration: 0.3), value: m.speedProgress)
                }
            }
            .frame(height: 8)
            HStack {
                Text("BPM Atual: ") + Text("\(m.bpm)").bold()
                Spacer()
                if m.bpm >= m.speed.endBpm {
                    Text("Alvo Atingido: ") + Text("\(m.speed.endBpm) BPM").bold()
                } else {
                    Text("Próximo +") + Text("\(m.speed.stepBpm) BPM").bold() + Text(" em ")
                        + Text("\(m.speedSecondsUntilNext)s").bold() + Text(" (Alvo: \(m.speed.endBpm))")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.labelSecondary)
        }
        .padding(16)
        .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: Theme.radiusControl))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl).stroke(Theme.separatorSubtle))
    }

    @ViewBuilder private var params: some View {
        ParamCard(title: "Tempo Total de Estudo", badge: "\(m.speed.totalMinutes) min",
                  value: m.speed.totalMinutes, valueText: "\(m.speed.totalMinutes) min",
                  onDec: { m.setSpeedTotalMinutes(m.speed.totalMinutes - 1) },
                  onInc: { m.setSpeedTotalMinutes(m.speed.totalMinutes + 1) },
                  onCommit: m.setSpeedTotalMinutes,
                  pills: [5, 10, 15, 20], pillTitle: { "\($0)m" }, onPill: m.setSpeedTotalMinutes)
        ParamCard(title: "BPM Inicial", badge: "\(m.speed.startBpm) BPM",
                  value: m.speed.startBpm, valueText: "\(m.speed.startBpm)",
                  onDec: { m.setSpeedStart(m.speed.startBpm - 1) },
                  onInc: { m.setSpeedStart(m.speed.startBpm + 1) },
                  onCommit: { m.setSpeedStart($0) },
                  pills: [40, 60, 80, 100], pillTitle: { "\($0)" }, onPill: { m.setSpeedStart($0, pillJump: true) })
        ParamCard(title: "BPM Final", badge: "\(m.speed.endBpm) BPM",
                  value: m.speed.endBpm, valueText: "\(m.speed.endBpm)",
                  onDec: { m.setSpeedEnd(m.speed.endBpm - 1, clampToStart: true) },
                  onInc: { m.setSpeedEnd(m.speed.endBpm + 1, clampToStart: true) },
                  onCommit: { m.setSpeedEnd($0) },
                  pills: [90, 100, 120, 140], pillTitle: { "\($0)" }, onPill: { m.setSpeedEnd($0, pillJump: true) })
        ParamCard(title: "Crescimento (Passo)", badge: "+\(m.speed.stepBpm) BPM",
                  value: m.speed.stepBpm, valueText: "\(m.speed.stepBpm) BPM",
                  onDec: { m.setSpeedStep(m.speed.stepBpm - 1) },
                  onInc: { m.setSpeedStep(m.speed.stepBpm + 1) },
                  onCommit: m.setSpeedStep,
                  pills: [1, 2, 4, 5], pillTitle: { "\($0)" }, onPill: m.setSpeedStep,
                  hint: "+\(m.speed.stepBpm) BPM a cada \(max(1, m.speed.intervalSeconds))s")
        ParamCard(title: "Subir a Cada", badge: "\(m.speed.intervalSeconds) seg",
                  value: m.speed.intervalSeconds, valueText: "\(m.speed.intervalSeconds) seg",
                  onDec: { m.setSpeedInterval(m.speed.intervalSeconds - 1) },
                  onInc: { m.setSpeedInterval(m.speed.intervalSeconds + 1) },
                  onCommit: m.setSpeedInterval,
                  pills: [5, 10, 15, 20], pillTitle: { "\($0)s" }, onPill: m.setSpeedInterval,
                  hint: m.speedIntervalSummary)
    }

    private func mmss(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }
}

private struct ParamCard: View {
    let title: String
    let badge: String
    let value: Int
    let valueText: String
    let onDec: () -> Void
    let onInc: () -> Void
    let onCommit: (Int) -> Void
    let pills: [Int]
    let pillTitle: (Int) -> String
    let onPill: (Int) -> Void
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.labelSecondary)
                Spacer()
                Text(badge)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cyan)
            }
            ParamStepper(onDec: onDec, onInc: onInc) {
                EditableNumber(value: value, onCommit: onCommit) {
                    Text(valueText)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
            }
            SegmentedChips(items: pills, selected: pills.contains(value) ? value : nil,
                           title: pillTitle, fontSize: 11, expand: true, onSelect: onPill)
            if let hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.labelTertiary)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: Theme.radiusControl))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl).stroke(Theme.separatorSubtle))
    }
}

// MARK: - Abas (Silent Bars / Presets)

private struct TrainingTabsCard: View {
    enum Tab: Hashable { case silent, presets }
    @Environment(MetronomeModel.self) private var m
    @State private var tab: Tab = .silent

    var body: some View {
        @Bindable var m = m
        Card {
            VStack(alignment: .leading, spacing: 18) {
                SegmentedChips(items: [Tab.silent, .presets], selected: tab,
                               title: { $0 == .silent ? "Ritmo Interno (Silent Bars)" : "Presets Rápidos" },
                               mono: false, fontSize: 13) { tab = $0 }

                switch tab {
                case .silent:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], alignment: .leading,
                              spacing: 16) {
                        param("Ativar Treino com Mudo") {
                            GutyToggle(label: "Modo Silencioso Ativo", isOn: $m.silentBarsEnabled)
                        }
                        param("Compassos Tocados") {
                            ParamStepper(onDec: { m.playedBars = max(1, m.playedBars - 1) },
                                         onInc: { m.playedBars = min(32, m.playedBars + 1) }) {
                                Text("\(m.playedBars)").font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: 160)
                        }
                        param("Compassos Mudos") {
                            ParamStepper(onDec: { m.silentBars = max(1, m.silentBars - 1) },
                                         onInc: { m.silentBars = min(32, m.silentBars + 1) }) {
                                Text("\(m.silentBars)").font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: 160)
                        }
                        param("Desafio Aleatório") {
                            GutyToggle(label: "Silêncio de Surpresa", isOn: $m.silentRandom)
                        }
                    }
                case .presets:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clique para carregar. Clique com o botão direito para salvar as configurações atuais.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.labelSecondary)
                        HStack(spacing: 10) {
                            ForEach(1...4, id: \.self) { slot in
                                PresetButton(slot: slot)
                            }
                        }
                    }
                }
            }
        }
    }

    private func param<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.labelSecondary)
            content()
        }
    }
}

private struct PresetButton: View {
    let slot: Int
    @Environment(MetronomeModel.self) private var m

    var body: some View {
        let saved = m.savedPresets.contains(slot)
        Button { m.presetTapped(slot) } label: {
            Text("P\(slot)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(saved ? Theme.cyan : Theme.labelPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: Theme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl)
                    .stroke(saved ? Theme.blue : Theme.separatorSubtle, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .contextMenu {
            Button("Salvar configurações atuais em P\(slot)") { m.savePreset(slot) }
        }
    }
}
