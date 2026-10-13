import SwiftUI

/// The meetings joined from this Mac, most recent first: join again, copy the link, forget one
/// (right-click) or all of them.
struct RecentMeetings: View {
    @Environment(HistoryStore.self) private var history
    @State private var confirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Récentes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                if !history.entries.isEmpty {
                    Button("Vider l'historique") { confirmingClear = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 10)

            if history.entries.isEmpty {
                Text("Les réunions que vous rejoignez apparaîtront ici.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(history.entries) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }
                .scrollIndicators(.automatic)
                .frame(maxHeight: 280)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog("Vider l'historique ?", isPresented: $confirmingClear) {
            Button("Vider", role: .destructive) { withAnimation(Theme.quick) { history.clear() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("La liste des réunions récentes sera effacée de ce Mac. Les réunions elles-mêmes ne sont pas touchées : leurs liens restent valables.")
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(HistoryStore.self) private var history
    @State private var hovering = false

    private var copied: Bool { model.copiedLink == entry.room.link }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "video")
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.room.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if hovering || copied {
                ChromeButton(symbol: copied ? "checkmark" : "link", help: copied ? "Lien copié" : "Copier le lien", active: copied) {
                    model.copyLink(entry.room)
                }
                Button("Rejoindre") { model.rejoin(entry) }
                    .voidPrimaryButton()
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovering ? Theme.hover : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.rejoin(entry) }
        .contextMenu {
            Button("Rejoindre") { model.rejoin(entry) }
            Button("Copier le lien") { model.copyLink(entry.room) }
            Divider()
            Button("Retirer de l'historique") { withAnimation(Theme.quick) { history.remove(entry) } }
        }
        .help(entry.room.link)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Rejoindre") { model.rejoin(entry) }
        .accessibilityAction(named: "Copier le lien") { model.copyLink(entry.room) }
    }

    /// "Aujourd'hui, 14:32", "hier, 09:05", "3 oct., 18:00" — and the server when it isn't the
    /// one in Réglages.
    private var subtitle: String {
        var text: String
        if Calendar.current.isDateInToday(entry.date) {
            text = "Aujourd'hui, " + entry.date.formatted(date: .omitted, time: .shortened)
        } else if Calendar.current.isDateInYesterday(entry.date) {
            text = "Hier, " + entry.date.formatted(date: .omitted, time: .shortened)
        } else {
            text = entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        }
        if entry.room.server != settings.server { text += " · " + entry.room.server.displayName }
        return text
    }
}
