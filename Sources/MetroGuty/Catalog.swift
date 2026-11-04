import Foundation

/// Banco de timbres (12 timbres reais), na mesma ordem do site.
struct SoundDef {
    let name: String
    let downbeat: String
    let beats: String
    let div: String?
}

/// Subdivisões rítmicas (16 padrões). `pattern` divide um tempo em slots iguais.
struct SubdivisionDef {
    let name: String
    let desc: String
    let pattern: [Int]
    let divTakesBeatVolume: Bool
}

enum Catalog {
    static let sounds: [SoundDef] = [
        SoundDef(name: "Digital 1", downbeat: "digital1_downbeat", beats: "digital1_beats", div: nil),
        SoundDef(name: "Digital 2", downbeat: "digital2_downbeat", beats: "digital2_beats", div: nil),
        SoundDef(name: "Digital 3", downbeat: "digital3_downbeat", beats: "digital3_beats", div: nil),
        SoundDef(name: "Cowbell", downbeat: "cowbell_downbeat", beats: "cowbell_beats", div: nil),
        SoundDef(name: "Mecânico 1", downbeat: "mechanical1_downbeat", beats: "mechanical1_beats", div: nil),
        SoundDef(name: "Mecânico 2", downbeat: "mechanical2_downbeat", beats: "mechanical2_beats", div: nil),
        SoundDef(name: "Mecânico 3", downbeat: "mechanical3_downbeat", beats: "mechanical3_beats", div: nil),
        SoundDef(name: "Conga", downbeat: "conga_downbeat", beats: "conga_beats", div: "conga_div"),
        SoundDef(name: "Woodblock", downbeat: "woodblock_downbeat", beats: "woodblock_beats", div: nil),
        SoundDef(name: "Claves", downbeat: "claves_downbeat", beats: "claves_beats", div: nil),
        SoundDef(name: "Baquetas", downbeat: "sticks_downbeat", beats: "sticks_beats", div: nil),
        SoundDef(name: "Hi-Hat", downbeat: "hihat_downbeat", beats: "hihat_beats", div: "hihat_div"),
    ]

    static let subdivisions: [SubdivisionDef] = [
        SubdivisionDef(name: "Semínima", desc: "1 por tempo", pattern: [1,0,0,0,0,0,0,0,0,0,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Colcheia", desc: "Divisão em 2", pattern: [1,0,0,0,0,0,1,0,0,0,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Tercina", desc: "3 por tempo", pattern: [1,0,0,0,1,0,0,0,1,0,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Semicolcheia", desc: "Divisão em 4", pattern: [1,0,0,1,0,0,1,0,0,1,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Colcheia + 2 Semi", desc: "1 colcheia + 2 semi", pattern: [1,0,0,0,0,0,1,0,0,1,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "2 Semi + Colcheia", desc: "2 semi + 1 colcheia", pattern: [1,0,0,1,0,0,1,0,0,0,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Shuffle / Blues", desc: "Swing ternário", pattern: [1,0,0,0,0,0,0,0,1,0,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "1ª e 4ª Semi", desc: "Início e fim", pattern: [1,0,0,0,0,0,0,0,0,1,0,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Contratempo", desc: "Somente o \"e\"", pattern: [0,0,0,0,0,0,1,0,0,0,0,0], divTakesBeatVolume: true),
        SubdivisionDef(name: "2ª e 4ª Semi", desc: "Síncope central", pattern: [0,0,0,1,0,0,0,0,0,1,0,0], divTakesBeatVolume: true),
        SubdivisionDef(name: "2ª e 3ª Tercina", desc: "Tercina sem 1ª", pattern: [0,0,0,0,1,0,0,0,1,0,0,0], divTakesBeatVolume: true),
        SubdivisionDef(name: "3ª e 4ª Semi", desc: "Segunda metade", pattern: [0,0,0,0,0,0,1,0,0,1,0,0], divTakesBeatVolume: true),
        SubdivisionDef(name: "Quintoletos", desc: "5 por tempo", pattern: [1,0,1,0,1,0,1,0,1,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Septoletos", desc: "7 por tempo", pattern: [1,0,1,0,1,0,1,0,1,0,1,0,1,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Sextoletos", desc: "6 por tempo", pattern: [1,0,1,0,1,0,1,0,1,0,1,0], divTakesBeatVolume: false),
        SubdivisionDef(name: "Swing Semicolcheia", desc: "Trinaire groove", pattern: [1,0,0,0,1,0,1,0,0,0,1,0], divTakesBeatVolume: false),
    ]

    private static let tempoMarkings: [(max: Int, text: String)] = [
        (45, "Grave"), (60, "Largo"), (76, "Adagio"), (108, "Andante"), (120, "Moderato"),
        (156, "Allegro"), (200, "Vivace"), (240, "Presto"), (999, "Prestissimo"),
    ]

    static func tempoMarking(for bpm: Int) -> String {
        tempoMarkings.first { bpm <= $0.max }?.text ?? "Prestissimo"
    }

    // Ícones extras do HTML original (andamento e Speed Training).
    static let tempoIconSvg = ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 21h12l-4-18h-4L6 21z"/><line x1="12" y1="17" x2="16" y2="7"/><circle cx="16" cy="7" r="1.5" fill="#000000"/></svg>"##

    static let speedIconSvg = ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#000000" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14.8A8.5 8.5 0 1 1 20 14.8" /><line x1="12" y1="4.5" x2="12" y2="7" /><line x1="6.5" y1="7" x2="8.2" y2="8.7" /><line x1="17.5" y1="7" x2="15.8" y2="8.7" /><line x1="12" y1="13" x2="16.5" y2="8.5" stroke-width="2.4" /><circle cx="12" cy="13" r="1.8" fill="#000000" stroke="none" /></svg>"##
}
