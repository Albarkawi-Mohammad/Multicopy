import SwiftUI
import MulticopyCore

struct HistoryView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var model: PanelModel

    let onPaste: (ClipboardStore.Item) -> Void
    let onCopy: (ClipboardStore.Item) -> Void
    let onTogglePin: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onClose: () -> Void
    let onEnableAutoPaste: () -> Void
    let onToggleLaunchAtLogin: (Bool) -> Void
    let onClearHistory: () -> Void
    let onQuit: () -> Void

    @FocusState private var searchFocused: Bool

    private var visibleItems: [ClipboardStore.Item] {
        store.visibleItems(query: model.query)
    }

    private var pinnedItems: [ClipboardStore.Item] {
        visibleItems.filter(\.isPinned)
    }

    private var recentItems: [ClipboardStore.Item] {
        visibleItems.filter { !$0.isPinned }
    }

    private var highlightedID: UUID? {
        if let id = model.selectedID, visibleItems.contains(where: { $0.id == id }) {
            return id
        }
        return visibleItems.first?.id
    }

    private var countLabel: String {
        let count = visibleItems.count
        return count == 1 ? "1 copy" : "\(count) copies"
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider()
                .overlay(Color.primary.opacity(0.06))

            content

            if !model.accessibilityGranted {
                Divider()
                    .overlay(Color.primary.opacity(0.06))
                accessibilityBanner
            }

            Divider()
                .overlay(Color.primary.opacity(0.06))

            footer
        }
        .frame(width: 470, height: 544)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
        )
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            requestSearchFocus()
        }
        .onChange(of: model.focusRequest) { _, _ in
            requestSearchFocus()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search clipboard", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .focused($searchFocused)
                .onSubmit {
                    pasteHighlighted()
                }

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }

            Text(countLabel)
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.secondary.opacity(0.8))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var content: some View {
        Group {
            if store.items.isEmpty {
                emptyState
            } else if visibleItems.isEmpty {
                noResultsState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            if !pinnedItems.isEmpty {
                                sectionHeader("Pinned")
                                ForEach(pinnedItems) { item in
                                    row(for: item)
                                }
                            }

                            if !recentItems.isEmpty {
                                if !pinnedItems.isEmpty {
                                    sectionHeader("Recent")
                                }
                                ForEach(recentItems) { item in
                                    row(for: item)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                    }
                    .scrollIndicators(.never)
                    .onChange(of: highlightedID) { _, id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.tertiary)

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.horizontal, 9)
        .padding(.top, 9)
        .padding(.bottom, 4)
    }

    private func row(for item: ClipboardStore.Item) -> some View {
        HistoryRow(
            item: item,
            isSelected: item.id == highlightedID,
            onPaste: { onPaste(item) },
            onCopy: { onCopy(item) },
            onTogglePin: { onTogglePin(item.id) },
            onDelete: { onDelete(item.id) }
        )
        .id(item.id)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            Text("No copies yet")
                .font(.system(size: 13, weight: .semibold))

            Text("Copy some text and it will appear here.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
    }

    private var noResultsState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            Text("No matches")
                .font(.system(size: 13, weight: .semibold))

            Text("Try a different search.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
    }

    private var accessibilityBanner: some View {
        Button(action: onEnableAutoPaste) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Brand.accent)
                    .frame(width: 6, height: 6)

                Text("Auto-paste is off")
                    .font(.system(size: 11, weight: .semibold))

                Text("\u{00B7} Enable to paste instantly")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text("Enable")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Brand.accent)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Brand.accent)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Brand.accent.opacity(0.07))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Grant Accessibility access so Multicopy can press \u{2318}V for you")
    }

    private var footer: some View {
        HStack(spacing: 12) {
            keyHint("\u{2191}\u{2193}", "Navigate")
            keyHint("\u{21B5}", "Paste")
            keyHint("esc", "Close")

            Spacer(minLength: 8)

            settingsMenu
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color.primary.opacity(0.018))
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )

            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.75))
        }
    }

    private var settingsMenu: some View {
        Menu {
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { onToggleLaunchAtLogin($0) }
                )
            )

            if !model.accessibilityGranted {
                Button("Enable Auto-Paste\u{2026}") {
                    onEnableAutoPaste()
                }
            }

            Divider()

            Button("Clear Unpinned History\u{2026}") {
                onClearHistory()
            }

            Divider()

            Button("Quit Multicopy") {
                onQuit()
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Settings")
        .accessibilityLabel("Settings")
    }

    private func pasteHighlighted() {
        if let id = highlightedID, let item = visibleItems.first(where: { $0.id == id }) {
            onPaste(item)
        }
    }

    private func requestSearchFocus() {
        DispatchQueue.main.async {
            searchFocused = true
        }
    }
}

private struct HistoryRow: View {
    let item: ClipboardStore.Item
    let isSelected: Bool
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onPaste) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.preview)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.createdAt.shortRelativeDescription)
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.secondary.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(item.preview))
            .accessibilityHint("Paste this copy")

            HStack(spacing: 2) {
                if item.isPinned || isHovered {
                    RowIconButton(
                        systemName: item.isPinned ? "pin.fill" : "pin",
                        tint: item.isPinned ? Brand.accent : Color.secondary,
                        help: item.isPinned ? "Unpin" : "Pin",
                        action: onTogglePin
                    )
                }

                if isHovered {
                    RowIconButton(
                        systemName: "trash",
                        tint: Brand.accent,
                        help: "Delete",
                        action: onDelete
                    )
                }
            }
            .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Brand.accent.opacity(0.35), lineWidth: 1)
            }
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(Brand.accent)
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .padding(.leading, 4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Paste") { onPaste() }
            Button("Copy to Clipboard") { onCopy() }
            Divider()
            Button(item.isPinned ? "Unpin" : "Pin") { onTogglePin() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Brand.accent.opacity(0.18)
        }
        if isHovered {
            return Color.primary.opacity(0.055)
        }
        return Color.clear
    }
}

private struct RowIconButton: View {
    let systemName: String
    let tint: Color
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isHovered ? tint : Color.secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(Text(help))
    }
}
