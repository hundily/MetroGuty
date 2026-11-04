import SwiftUI

struct Card<Content: View>: View {
    var highlighted = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusCard))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusCard)
                    .stroke(highlighted ? Theme.blue.opacity(0.4) : Theme.separatorSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Theme.labelSecondary)
            .padding(.bottom, 4)
    }
}

/// Botão com efeito de "press" (scale) como no CSS.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Botão cinza translúcido (step-btn, slider-step-btn, tap-btn...).
struct FillButton<Label: View>: View {
    var radius: CGFloat = Theme.radiusSmall
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    let action: () -> Void
    @ViewBuilder var label: Label
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(Theme.labelPrimary)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .background(hover ? Theme.fillSecondary : Theme.fill, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.separatorSubtle, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
    }
}

/// Toggle estilo iOS (verde quando ligado).
struct GutyToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.labelPrimary)
        }
        .toggleStyle(.switch)
        .tint(Theme.green)
        .controlSize(.small)
        .fixedSize()
    }
}

/// Grupo de chips segmentados (compasso, pills do Speed Training, abas).
struct SegmentedChips<T: Hashable>: View {
    let items: [T]
    let selected: T?
    let title: (T) -> String
    var mono = true
    var fontSize: CGFloat = 12
    var expand = false
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let active = item == selected
                Button { onSelect(item) } label: {
                    Text(title(item))
                        .font(mono ? .system(size: fontSize, weight: .semibold, design: .monospaced)
                                   : .system(size: fontSize, weight: .semibold))
                        .foregroundStyle(active ? Theme.labelPrimary : Theme.labelSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: !expand, vertical: false)
                        .padding(.horizontal, expand ? 2 : 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: expand ? .infinity : nil)
                        .background(active ? Theme.chipActive : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .shadow(color: active ? .black.opacity(0.35) : .clear, radius: 3, y: 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Número editável com duplo clique ("2 cliques para editar").
struct EditableNumber<Label: View>: View {
    let value: Int
    let onCommit: (Int) -> Void
    var fieldFont: Font = .system(size: 16, weight: .bold, design: .monospaced)
    var fieldWidth: CGFloat = 80
    @ViewBuilder var label: Label

    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(fieldFont)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.cyan)
                    .frame(width: fieldWidth)
                    .padding(4)
                    .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 6))
                    .focused($focused)
                    .onSubmit { close(save: true) }
                    .onExitCommand { close(save: false) }
                    .onChange(of: focused) { _, f in if !f && editing { close(save: true) } }
            } else {
                label
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        text = String(value)
                        editing = true
                        DispatchQueue.main.async { focused = true }
                    }
                    .help("2 cliques para digitar")
            }
        }
    }

    private func close(save: Bool) {
        if save, let v = Int(text.trimmingCharacters(in: .whitespaces)) { onCommit(v) }
        editing = false
    }
}

/// Stepper com − valor + (param-stepper-wrap).
struct ParamStepper<Center: View>: View {
    let onDec: () -> Void
    let onInc: () -> Void
    @ViewBuilder var center: Center

    var body: some View {
        HStack(spacing: 8) {
            FillButton(width: 32, height: 32, action: onDec) {
                Text("−").font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            center.frame(maxWidth: .infinity)
            FillButton(width: 32, height: 32, action: onInc) {
                Text("+").font(.system(size: 16, weight: .bold, design: .monospaced))
            }
        }
    }
}

/// Chip da grade de timbres / subdivisões.
struct GridChip: View {
    let name: String
    let svg: String
    var desc: String? = nil
    let active: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(active ? Theme.cyan : Theme.labelPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    SVGIcon(svg: svg)
                        .foregroundStyle(active ? Theme.cyan : Theme.labelSecondary)
                }
                if let desc {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.labelSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(active ? Theme.blueMuted : (hover ? Theme.fillSecondary : Theme.cardElevated),
                        in: RoundedRectangle(cornerRadius: Theme.radiusControl))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl)
                .stroke(active ? Theme.blue : Theme.separatorSubtle, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hover = $0 }
    }
}
