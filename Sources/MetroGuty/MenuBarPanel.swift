import AppKit
import SwiftUI

/// Ícone monocromático da barra de status, desenhado a partir da geometria do logo.
enum MenuBarGlyph {
    static let image: NSImage = {
        let svg = ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#000000" stroke-width="2.2"><circle cx="12" cy="12" r="8.2"/><line x1="12" y1="0.8" x2="12" y2="23.2"/><line x1="4" y1="9.6" x2="20" y2="9.6"/><line x1="12" y1="13.6" x2="19.6" y2="13.6"/></svg>"##
        let img = NSImage(data: Data(svg.utf8)) ?? NSImage()
        img.isTemplate = true
        return img
    }()
}

/// Rótulo na barra de status: ícone + BPM enquanto toca.
struct MenuBarLabel: View {
    @Environment(MetronomeModel.self) private var m

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarGlyph.image)
            if m.isPlaying {
                Text("\(m.bpm)").monospacedDigit()
            }
        }
    }
}

/// Versão compacta do MetroGuty que abre a partir da barra de status.
struct MenuBarPanel: View {
    @Environment(MetronomeModel.self) private var m
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var m = m
        VStack(spacing: 14) {
            header

            // BPM
            HStack(spacing: 6) {
                smallStep(-5)
                smallStep(-1)
                EditableNumber(value: m.bpm, onCommit: { m.setBpm($0) },
                               fieldFont: .system(size: 34, weight: .bold, design: .monospaced),
                               fieldWidth: 90) {
                    VStack(spacing: 0) {
                        Text("\(m.bpm)")
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .tracking(-1.5)
                            .contentTransition(.numericText())
                        Text("BPM • \(m.tempoMarking)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.cyan)
                    }
                    .frame(minWidth: 96)
                }
                smallStep(1)
                smallStep(5)
            }

            Slider(value: Binding(get: { Double(m.bpm) }, set: { m.setBpm(Int($0.rounded())) }), in: 10...300)
                .tint(Theme.blue)
                .controlSize(.small)

            // Transporte
            HStack(spacing: 8) {
                Button(action: m.togglePlayPause) {
                    Text(m.isPlaying ? "⏸  PAUSAR" : "▶  INICIAR")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(m.isPlaying ? Theme.red : Theme.blue, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
                FillButton(radius: 999, width: 54, height: 38, action: m.tap) {
                    Text("TAP").font(.system(size: 12, weight: .bold))
                }
                .scaleEffect(m.tapPulse ? 0.94 : 1)
                .animation(.easeOut(duration: 0.1), value: m.tapPulse)
                .help("Tap Tempo")
                FillButton(radius: 999, width: 38, height: 38, action: m.stopAndReset) {
                    Text("⏹").font(.system(size: 13))
                }
                .help("Parar e zerar")
            }

            // Compasso + acento
            HStack {
                SegmentedChips(items: [2, 3, 4, 6], selected: m.beatsPerBar,
                               title: { $0 == 6 ? "6/8" : "\($0)/4" }, fontSize: 11) { m.beatsPerBar = $0 }
                Spacer(minLength: 10)
                GutyToggle(label: "Acento", isOn: $m.accentDownBeat)
            }

            // Timbre + subdivisão
            VStack(spacing: 8) {
                pickerRow("Timbre", selection: $m.soundIndex,
                          items: Catalog.sounds.indices.map { ($0, Catalog.sounds[$0].name) })
                pickerRow("Subdivisão", selection: $m.subdivisionIndex,
                          items: Catalog.subdivisions.indices.map { ($0, Catalog.subdivisions[$0].name) })
            }

            // Volume
            HStack(spacing: 8) {
                Button(action: m.toggleMute) { Text(m.volumeIcon).font(.system(size: 13)) }
                    .buttonStyle(.plain)
                    .help("Mutar / Ativar som")
                Slider(value: Binding(get: { Double(m.volume) }, set: { m.setVolume(Int($0.rounded())) }),
                       in: 0...100)
                    .tint(Theme.blue)
                    .controlSize(.small)
                Text("\(m.volume)%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.labelSecondary)
                    .frame(width: 36, alignment: .trailing)
            }

            if m.speed.enabled { speedStatus }

            Divider().overlay(Theme.separator)

            HStack {
                Button("Abrir MetroGuty") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Text(m.stopwatchText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.labelSecondary)
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.labelSecondary)
        }
        .padding(16)
        .frame(width: 320)
        .background(Theme.card)
        .foregroundStyle(Theme.labelPrimary)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: Logo.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 22, height: 22)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            Text("MetroGuty").font(.system(size: 13, weight: .bold))
            Spacer()
            // Indicador de tempos (mesmas cores do radar)
            HStack(spacing: 5) {
                ForEach(0..<m.beatsPerBar, id: \.self) { i in
                    let active = m.activeBeat == i
                    let down = active && m.activeIsDownbeat
                    Circle()
                        .fill(down ? Theme.red : active ? Theme.cyan : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .scaleEffect(active ? 1.3 : 1)
                        .animation(.easeOut(duration: 0.12), value: active)
                }
            }
        }
    }

    private var speedStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SPEED TRAINING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.orange)
                Spacer()
                Text("\(m.speed.startBpm) → \(m.speed.endBpm) BPM")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.labelSecondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.fill)
                    Capsule().fill(Theme.orange).frame(width: g.size.width * m.speedProgress)
                }
            }
            .frame(height: 5)
        }
    }

    private func smallStep(_ d: Int) -> some View {
        FillButton(width: 34, height: 28, action: { m.stepBpm(d) }) {
            Text(d > 0 ? "+\(d)" : "\(d)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
    }

    private func pickerRow(_ title: String, selection: Binding<Int>, items: [(Int, String)]) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.labelSecondary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(items, id: \.0) { Text($0.1).tag($0.0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }
}
