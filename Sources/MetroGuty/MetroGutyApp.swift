import AppKit
import SwiftUI

@main
struct MetroGutyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = MetronomeModel()

    var body: some Scene {
        Window("MetroGuty", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 860, minHeight: 640)
                .onAppear { KeyboardShortcuts.install(model: model) }
        }
        .defaultSize(width: 1060, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Metrônomo") {
                Button(model.isPlaying ? "Pausar" : "Iniciar") { model.togglePlayPause() }
                Button("Parar e Zerar") { model.stopAndReset() }
                    .keyboardShortcut(".", modifiers: .command)
                Divider()
                Button("Aumentar BPM") { model.stepBpm(1) }
                Button("Diminuir BPM") { model.stepBpm(-1) }
                Button("Tap Tempo") { model.tap() }
            }
        }

        // Versão compacta na barra de status
        MenuBarExtra {
            MenuBarPanel()
                .environment(model)
                .onAppear { KeyboardShortcuts.install(model: model) }
        } label: {
            MenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Fechar a janela mantém o MetroGuty ativo na barra de status.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Atalhos do site: Espaço (Play/Pause), Setas (BPM), T (Tap).
/// Ignorados enquanto um campo de texto está sendo editado.
@MainActor
enum KeyboardShortcuts {
    private static var monitor: Any?

    static func install(model: MetronomeModel) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if NSApp.keyWindow?.firstResponder is NSText { return event }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }
            switch event.keyCode {
            case 49: model.togglePlayPause()   // espaço
            case 126: model.stepBpm(1)          // ↑
            case 125: model.stepBpm(-1)         // ↓
            case 17: model.tap()                // T
            default: return event
            }
            return nil
        }
    }
}
