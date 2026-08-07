import Domain
import SwiftUI

/// Schülerliste und Sitzregeln einer Klasse.
///
/// Wird als Detailbereich von ``KlassenListe`` eingebettet, erhält ein
/// ``SchuelerModell`` und trägt keine Geschäftslogik selbst.
struct SchuelerListe: View {
    @State private var modell: SchuelerModell
    @State private var legtAn = false
    @State private var bearbeitet: Schueler?
    @State private var legtRegelAn = false

    init(modell: SchuelerModell) {
        _modell = State(initialValue: modell)
    }

    var body: some View {
        inhalt
            .task { await modell.laden() }
            .sheet(isPresented: $legtAn) {
                SchuelerBearbeiten(titel: "Neuer Schüler") { v, n, f, m, notiz in
                    await modell.anlegen(vorname: v, nachname: n,
                                         farbIndex: f, merkmale: m, notiz: notiz)
                }
            }
            .sheet(item: $bearbeitet) { s in
                SchuelerBearbeiten(
                    titel: "Schüler bearbeiten",
                    vorname: s.vorname,
                    nachname: s.nachname,
                    farbIndex: s.farbIndex,
                    merkmale: s.merkmale,
                    notiz: s.notiz
                ) { v, n, f, m, notiz in
                    var geaendert = s
                    geaendert.vorname = v
                    geaendert.nachname = n
                    geaendert.farbIndex = f
                    geaendert.merkmale = m
                    geaendert.notiz = notiz
                    return await modell.aktualisieren(geaendert)
                }
            }
            .sheet(isPresented: $legtRegelAn) {
                RegelAnlegen(schueler: modell.schueler) { a, b, art in
                    await modell.regelAnlegen(schuelerA: a, schuelerB: b, art: art)
                }
            }
            .alert(item: $modell.meldung) { m in
                Alert(
                    title: Text(m.text),
                    message: m.vorschlag.map(Text.init),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var inhalt: some View {
        switch modell.zustand {
        case .laedt:
            ProgressView().accessibilityLabel("Schüler werden geladen")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .leer:
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Noch keine Schüler").font(.title3)
                Text("Legen Sie die Schüler dieser Klasse an.")
                    .foregroundStyle(.secondary)
                Button("Neuer Schüler") { legtAn = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Farbe.primaeraktion)
            }
            .padding(32)
            .frame(maxWidth: 360)
            .toolbar { neuerSchuelerButton }

        case .gefuellt:
            List {
                Section("Schüler (\(modell.schueler.count))") {
                    ForEach(modell.schueler) { s in
                        schuelerZeile(s)
                    }
                }

                if !modell.sitzregeln.isEmpty || true {
                    sitzregelnAbschnitt
                }
            }
            .toolbar { neuerSchuelerButton }

        case .fehler(let text):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(Farbe.gefahr)
                    .accessibilityHidden(true)
                Text(text).multilineTextAlignment(.center)
                Button("Erneut versuchen") { Task { await modell.laden() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Farbe.primaeraktion)
            }
            .padding(32)
        }
    }

    // MARK: - Schülerzeile

    private func schuelerZeile(_ s: Schueler) -> some View {
        HStack(spacing: 10) {
            Initialenavatar(initialen: s.initialen, farbIndex: s.farbIndex)

            VStack(alignment: .leading, spacing: 2) {
                Text(s.vollerName)
                if !s.merkmale.isEmpty {
                    Text(s.merkmale.map(\.beschriftung).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contextMenu {
            Button("Bearbeiten…") { bearbeitet = s }
            Divider()
            Button("Löschen", role: .destructive) {
                Task { await modell.loeschen(s) }
            }
        }
        .accessibilityLabel(schuelerLabel(s))
    }

    private func schuelerLabel(_ s: Schueler) -> String {
        var teile = [s.vollerName]
        if !s.merkmale.isEmpty {
            teile.append(s.merkmale.map(\.beschriftung).joined(separator: ", "))
        }
        return teile.joined(separator: ", ")
    }

    // MARK: - Sitzregeln

    private var sitzregelnAbschnitt: some View {
        Section {
            ForEach(modell.sitzregeln) { regel in
                regelZeile(regel)
            }

            Button {
                legtRegelAn = true
            } label: {
                Label("Neue Regel", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(modell.schueler.count < 2 ? Color.secondary : Color.accentColor)
            .disabled(modell.schueler.count < 2)
            .accessibilityLabel(
                modell.schueler.count < 2
                    ? "Neue Regel — mindestens zwei Schüler erforderlich"
                    : "Neue Sitzregel anlegen"
            )
        } header: {
            Text("Sitzregeln")
        }
    }

    private func regelZeile(_ regel: Sitzregel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(regelBeschriftung(regel))
                Text(regelArtText(regel.art))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contextMenu {
            Button("Entfernen", role: .destructive) {
                Task { await modell.regelLoeschen(regel) }
            }
        }
        .accessibilityLabel("\(modell.name(fuer: regel.schuelerA)) \(regelArtText(regel.art)) \(modell.name(fuer: regel.schuelerB))")
    }

    private func regelBeschriftung(_ regel: Sitzregel) -> String {
        "\(modell.name(fuer: regel.schuelerA)) & \(modell.name(fuer: regel.schuelerB))"
    }

    private func regelArtText(_ art: Regelart) -> String {
        switch art {
        case .nichtNeben: "nicht nebeneinander"
        case .mussNeben: "muss nebeneinander"
        }
    }

    // MARK: - Toolbar

    private var neuerSchuelerButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                legtAn = true
            } label: {
                Label("Neuer Schüler", systemImage: "person.badge.plus")
            }
            .help("Neuen Schüler anlegen")
        }
    }
}

// MARK: - Initialenavatar

private struct Initialenavatar: View {
    let initialen: String
    let farbIndex: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Farbe.schuelerFarbe(farbIndex: farbIndex))
                .frame(width: 32, height: 32)
            Text(initialen)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0x15 / 255, green: 0x11 / 255, blue: 0x0D / 255))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Neue Regel anlegen

private struct RegelAnlegen: View {
    let schueler: [Schueler]
    let anlegen: (UUID, UUID, Regelart) async -> Bool

    @State private var schuelerA: UUID?
    @State private var schuelerB: UUID?
    @State private var art: Regelart = .nichtNeben
    @State private var arbeitet = false

    @Environment(\.dismiss) private var schliessen

    private var eingabeGueltig: Bool {
        if let a = schuelerA, let b = schuelerB { return a != b }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Neue Sitzregel")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Schüler A").gridColumnAlignment(.trailing)
                    Picker("Schüler A", selection: $schuelerA) {
                        Text("Bitte wählen").tag(Optional<UUID>.none)
                        ForEach(schueler) { s in
                            Text(s.vollerName).tag(Optional(s.id))
                        }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Schüler B").gridColumnAlignment(.trailing)
                    Picker("Schüler B", selection: $schuelerB) {
                        Text("Bitte wählen").tag(Optional<UUID>.none)
                        ForEach(schueler.filter { $0.id != schuelerA }) { s in
                            Text(s.vollerName).tag(Optional(s.id))
                        }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Regel").gridColumnAlignment(.trailing)
                    Picker("Regelart", selection: $art) {
                        Text("nicht nebeneinander").tag(Regelart.nichtNeben)
                        Text("muss nebeneinander").tag(Regelart.mussNeben)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }
            }

            HStack {
                Spacer()
                Button("Abbrechen") { schliessen() }
                    .keyboardShortcut(.cancelAction)
                Button("Sichern") { starteSichern() }
                    .buttonStyle(.borderedProminent)
                    .tint(Farbe.primaeraktion)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!eingabeGueltig || arbeitet)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
        .ohneDarkMode()
    }

    private func starteSichern() {
        guard let a = schuelerA, let b = schuelerB, a != b, !arbeitet else { return }
        arbeitet = true
        Task {
            let erfolg = await anlegen(a, b, art)
            arbeitet = false
            if erfolg { schliessen() }
        }
    }
}
