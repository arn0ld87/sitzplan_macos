import Domain
import SwiftUI

/// Anlegen und Bearbeiten eines Schülers — dieselbe Maske, zwei Beschriftungen.
struct SchuelerBearbeiten: View {
    let titel: String
    private let sichern: (String, String, Int, [Merkmal], String?) async -> Bool

    @State private var vorname: String
    @State private var nachname: String
    @State private var farbIndex: Int
    @State private var merkmale: Set<Merkmal>
    @State private var notiz: String
    @State private var arbeitet = false

    @Environment(\.dismiss) private var schliessen
    @FocusState private var fokus: Feld?

    private enum Feld { case vorname, nachname }

    init(
        titel: String,
        vorname: String = "",
        nachname: String = "",
        farbIndex: Int = 0,
        merkmale: [Merkmal] = [],
        notiz: String? = nil,
        sichern: @escaping (String, String, Int, [Merkmal], String?) async -> Bool
    ) {
        self.titel = titel
        _vorname = State(initialValue: vorname)
        _nachname = State(initialValue: nachname)
        _farbIndex = State(initialValue: farbIndex)
        _merkmale = State(initialValue: Set(merkmale))
        _notiz = State(initialValue: notiz ?? "")
        self.sichern = sichern
    }

    private var eingabeGueltig: Bool {
        !vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !nachname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titel)
                .font(.title2)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 16)

            // Name
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Vorname").gridColumnAlignment(.trailing)
                    TextField("Vorname", text: $vorname)
                        .textFieldStyle(.roundedBorder)
                        .focused($fokus, equals: .vorname)
                        .onSubmit { fokus = .nachname }
                }
                GridRow {
                    Text("Nachname").gridColumnAlignment(.trailing)
                    TextField("Nachname", text: $nachname)
                        .textFieldStyle(.roundedBorder)
                        .focused($fokus, equals: .nachname)
                        .onSubmit { if eingabeGueltig { starteSichern() } }
                }
            }

            Divider().padding(.vertical, 14)

            // Farbwahl
            Text("Farbe")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            HStack(spacing: 8) {
                ForEach(0..<Farbe.schuelerPalette.count, id: \.self) { i in
                    Circle()
                        .fill(Farbe.schuelerFarbe(farbIndex: i))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if farbIndex == i {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .padding(2)
                                Circle()
                                    .strokeBorder(.primary.opacity(0.4), lineWidth: 1)
                            }
                        }
                        .onTapGesture { farbIndex = i }
                        .accessibilityLabel("Farbe \(i + 1)")
                        .accessibilityAddTraits(farbIndex == i ? .isSelected : [])
                }
            }

            Divider().padding(.vertical, 14)

            // Merkmale
            Text("Merkmale")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            merkmaleRaster

            Divider().padding(.vertical, 14)

            // Notiz
            Text("Notiz")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            TextEditor(text: $notiz)
                .frame(height: 60)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary, lineWidth: 1))
                .font(.body)

            // Aktionen
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
            .padding(.top, 16)
        }
        .padding(20)
        .frame(minWidth: 440)
        .onAppear { fokus = .vorname }
        .ohneDarkMode()
    }

    private var merkmaleRaster: some View {
        let spalten = 2
        let alle = Merkmal.allCases
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: spalten),
            spacing: 6
        ) {
            ForEach(alle, id: \.self) { merkmal in
                Toggle(isOn: Binding(
                    get: { merkmale.contains(merkmal) },
                    set: { an in
                        if an { merkmale.insert(merkmal) } else { merkmale.remove(merkmal) }
                    }
                )) {
                    Text(merkmal.beschriftung).font(.callout)
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private func starteSichern() {
        guard eingabeGueltig, !arbeitet else { return }
        arbeitet = true
        Task {
            let erfolg = await sichern(
                vorname,
                nachname,
                farbIndex,
                Array(merkmale),
                notiz.isEmpty ? nil : notiz
            )
            arbeitet = false
            if erfolg { schliessen() }
        }
    }
}
