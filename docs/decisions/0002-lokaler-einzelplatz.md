# ADR-0002: Lokaler Einzelplatz ohne Backend

- Status: **Accepted**
- Datum: 2026-08-05
- Ersetzt: [ADR-0001](0001-nativer-macos-client.md)
- Betrifft: **dieses Repository.** In `sitzplan_app` ändert sich kein Code, kein
  Schema und keine RLS-Policy; der Web-Client läuft unverändert weiter. Drei
  Dokumente dort werden durch diese Entscheidung allerdings unwahr:
  `docs/decisions/0006-native-macos-client.md` (Status `Accepted`, beschreibt
  diesen Client als zusätzlichen Client desselben Produkts),
  `docs/architecture.md` im Abschnitt „Ein zweiter Client“ und
  `contracts/README.md`, das das Web-Repo zur Quelle der Wahrheit für Fixtures
  erklärt, die dieses Repo abgleichen soll. Sie brauchen drüben einen Nachtrag,
  ADR-0006 zusätzlich eine Statusklärung — eigener Pull Request, eigene
  Entscheidung. Dieses ADR entscheidet nichts für das Web-Repo.

## Kontext

ADR-0001 hat den macOS-Client als *zweiten Client desselben Produkts*
beschrieben: ein Supabase-Projekt, ein Schema, ein Satz RLS-Policies, ein
Benutzerkonto, zwei Oberflächen. Das gesamte Papier dieses Repositories hängt
daran — der erste Hartanker in `AGENTS.md`, der Tabellenteil des
Datenvertrags, die Funktionsparität, die Meilensteine, die elf Issues.

Zwei Dinge haben sich gegen diese Konstruktion gestellt.

**Der Preis kommt vor dem Nutzen.** Ein zweiter Client am gemeinsamen Backend
zahlt dauerhaft für die Kopplung: Anmeldung, Sitzungserneuerung, Kontowechsel
und vergessene Passwörter; PostgREST-Eigenheiten wie `numeric`, das mal als
Zahl und mal als Zeichenkette ankommt; ehrliche Netzzustände; optimistisches
Sperren über `updated_at`; Serverkonflikte, die aufgelöst werden wollen;
RLS-Gegenproben; Schemaänderungen, die in derselben Woche nachgezogen werden.
Nichts davon ist Sitzplanarbeit, und alles davon steht vor der ersten Klasse,
die jemand anlegen kann.

**Der Nutzen ist nicht der Grund für diesen Client.** Was das gemeinsame
Backend kauft, ist eine geteilte Datenlage: dieselbe Klasse morgens im
Browser, mittags am Mac. Das ist ein echter Wert, aber ADR-0001 nennt den
Grund für die native Anwendung selbst — Druck, Tastatur, Fokus, Undo,
Zeigerpräzision. Keiner davon braucht einen Server. Der Server war die
Voraussetzung, die man mitnahm, nicht die Fähigkeit, die man wollte.

Dazu kommt die Datenlage selbst. Klassenlisten, Merkmale wie ADHS,
Autismus-Spektrum oder Nachteilsausgleich und freie Notizen zu einzelnen
Kindern sind das Sensibelste, was diese Anwendung anfasst. Der Web-Client
muss sie systembedingt auf einem Server ablegen und einer Kontoverwaltung
anvertrauen. Eine native Anwendung muss das nicht. Sie kann die Daten dort
lassen, wo die Lehrkraft ohnehin arbeitet — auf ihrem eigenen Rechner. Das
ist keine Sparmaßnahme, das ist die bessere Antwort auf die Frage, wer diese
Daten hält.

## Entscheidung

Sitzplan Studio für macOS wird ein **eigenständiges Produkt**, das seine
Daten ausschließlich lokal speichert. Kein Konto, keine Anmeldung, kein
Server, kein Datenaustausch mit dem Web-Client.

### Kein Backend

SwiftData ist der Speicher, der `ModelContainer` liegt unter
`~/Library/Application Support/SitzplanStudio/`. Es gibt kein Supabase-SDK im
Projekt, keinen Publishable Key, keine RLS, keine Servermigrationen, keinen
Anmeldebildschirm.

**Schemaentwicklung verschwindet damit nicht, sie zieht um.** Was früher eine
SQL-Migration war, ist jetzt ein `VersionedSchema` mit `SchemaMigrationPlan` in
`SitzplanSpeicher`. Wer einen `@Model`-Typ ändert, ohne das mitzuplanen, macht
die Datenbank der Lehrkraft unlesbar — und anders als früher gibt es keinen
Server, von dem sie sich neu laden ließe. Das ist der Preis dafür, dass die
Daten nur einmal existieren, und er ist ab dem ersten ausgelieferten Build
fällig.

Der einzige ausgehende Netzaufruf der Anwendung ist der KI-Aufruf, und den
löst die Lehrkraft ausdrücklich aus. Alles andere — Start, Laden, Speichern,
Drucken — hat kein Netz zu sehen. Das wird ein Hartanker in `AGENTS.md`,
damit es nicht später versehentlich aufweicht.

### Zwei unabhängige Produkte

Web-Client und macOS-Client laufen nebeneinander weiter und wissen nichts
voneinander. Kein Import, kein Export in Richtung Web, keine Synchronisation,
kein gemeinsames Konto, kein gemeinsames Schema. Der Web-Client bleibt
unverändert in Betrieb; wer ihn benutzt, verliert durch diese Entscheidung
nichts.

Was bleibt, sind die **Dokumentverträge**: `RaumDokument` und `PlanDokument`
in den Versionen 3 und 1, die Sitzplatzkennung `<objektId>__sitz_<n>`, die
Rasterrechnung in Zentimetern, die Möbelmaße, das tolerante Lesen alter
Dokumente und das strenge Schreiben aktueller sowie weiches Löschen über ein
Datumsfeld als einzigen Löschmechanismus.

Dieses Feld heißt im Speicher **`geloeschtAm`**. `deleted_at` und `deletedAt`
sind die Schreibweisen in den Fixtures und stammen aus der Zeit des gemeinsamen
Backends; sie bezeichnen dieselbe Sache. Wer `deleted_at` für einen Feldnamen im
Swift-Modell hält, modelliert am Vertrag vorbei — die Zuordnung steht in
[`contracts/README.md`](../../contracts/README.md).

Ihre Rolle ändert sich: Sie sind nicht mehr der geteilte Vertrag zwischen
zwei Clients, sondern die **Verhaltensspezifikation dieses Repositories**. Sie
gelten nicht weiter, weil ein Server sie erzwingt, sondern weil sie richtig,
durchdacht und geprüft sind. Die fünf Fixtures unter `contracts/fixtures/`
bleiben unverändert liegen und hören auf, eine Kopie aus `sitzplan_app` zu
sein; der geplante CI-Abgleich gegen das Web-Repo entfällt ersatzlos.

Das hält nebenbei eine spätere Brücke offen — ein Datei-Import bliebe möglich,
weil beide Seiten dieselben Dokumentformate schreiben. Gebaut wird er nicht.

Im Web-Repo verliert `contracts/` damit seinen Grund: Das Verzeichnis kam mit
ADR-0006 hinzu, und keine dortige Testsuite liest die Fixtures. Ob es stehen
bleibt oder verschwindet, entscheidet das Web-Repo.

### Der lokale Speicher

Die `@Model`-Typen sind dünn. Das fachliche Dokument bleibt ein
`Codable`-Wert und liegt als Attribut am Model:

```swift
// Pakete/SitzplanSpeicher — kennt SwiftData
@Model final class RaumEintrag {
    var id: UUID
    var name: String
    var geloeschtAm: Date?
    var dokument: RaumDokument      // Wert, kein Objektgraph
}

// Pakete/SitzplanKern/Sources/Domain — kennt nichts
struct RaumDokument: Codable, Sendable, Equatable { … }
```

Daraus folgt der Paketschnitt: **zwei** lokale SPM-Pakete, nicht eines.
`Pakete/SitzplanKern` ist plattformneutral — nur Sprache und Foundation, nichts,
was eine Oberfläche, eine Datenbank oder ein Netz voraussetzt.
`Pakete/SitzplanSpeicher` kennt SwiftData und ist damit macOS-only. `swift test`
baut immer das ganze Paket; läge beides in einem Paket, wäre es auf Linux nicht
baubar, und der billige Linux-Job für Fixtures, `seatId` und Rasterrundung
entfiele.

Erzwungen wird die Schichtengrenze dabei **nicht vom Paketschnitt**. SwiftData
ist ein System-Framework; `import SwiftData` in `Domain` übersetzt auf einem Mac
anstandslos, gleich in welchem Paket der Quelltext liegt. Rot wird es erst auf
Linux, wo es das Framework nicht gibt und `swift test --package-path
Pakete/SitzplanKern` abbricht. Der Linux-Job ist damit nicht bloß billig — er
ist die einzige Stelle, an der diese Grenze überhaupt geprüft wird. Wer ihn
abschaltet oder nicht-blockierend macht, schafft die Grenze ab, ohne eine Zeile
Architektur zu ändern.

Weich gelöscht wird wie im Web über ein Datumsfeld, hier `geloeschtAm`. Jede
Leseabfrage auf Nutzdaten filtert es heraus; Papierkorb-Abfragen sind eigene
Repository-Methoden, keine Variante mit Schalter.

### Gemini mit eigenem Schlüssel

Die Edge Function `ki-sitzplan` im Web-Repo existiert aus einem Grund, den
sie selbst benennt: In einem Vite-Bundle gibt es kein Geheimnis. Ein
Schlüssel, der zugleich hinterlegt und nicht auslesbar sein soll, muss
außerhalb des Frontends liegen (ADR-0007 im Web-Repo).

Dieser Grund gilt für eine native Anwendung nicht. Sie hat die Keychain.

Also hinterlegt die Lehrkraft ihren **eigenen** Google-Schlüssel; er liegt in
der Keychain, nie in einer Einstellungsdatei, nie im Repository, nie in einem
Log. Die Anwendung ruft Gemini direkt auf. Kein Zwischenserver, keine fremde
Rechnung, keine Deckel-Buchhaltung — die Grenzen von 100 Aufrufen je Konto
und Tag, 10 je Minute und 300 global, die der Web-Client über die Tabelle
`ki_aufrufe` führt, sind hier gegenstandslos, weil jede Lehrkraft auf eigene
Rechnung ruft.

Ohne hinterlegten Schlüssel ist die Anwendung **vollständig benutzbar**; die
KI-Funktion ist dann nicht verfügbar und wird als nicht verfügbar angezeigt,
nicht als Fehler. Sie ist Beiwerk, keine Voraussetzung.

Portiert wird die Fachlogik, nicht die Infrastruktur: der Prompt-Bau samt
`MERKMAL_LABEL` aus der Edge Function und die Nachprüfung aus
`src/data/ki-vorschlag.ts` mit ihren zwanzig Tests. Deren Grundhaltung gilt
unverändert — dem Modell wird nicht geglaubt, erfundene Sitzplätze und
Regelverstöße werden gemeldet und nicht still geglättet.

### Pseudonymisierung im Prompt

Der Web-Client schickt Vor- und Nachnamen an das Modell. Dieser Client tut
das nicht: Schüler gehen als `s1`, `s2`, `s3` in den Prompt, die Rückabbildung
auf echte Namen bleibt auf dem Rechner und passiert erst, wenn der Vorschlag
zurück ist.

Ehrlich dazu gehört, was das **nicht** leistet. Es schützt die Namen, nicht
die Merkmale: Dass in einer Klasse jemand mit ADHS und jemand mit
Nachteilsausgleich sitzt, geht weiterhin an Google — sonst wäre der Vorschlag
wertlos. Wer die Klasse kennt, kann `s1` in Sekunden zuordnen; Google kann es
nicht. Pseudonymisierung senkt hier den Schaden, sie beseitigt ihn nicht, und
sie ersetzt keine Abwägung. Wer diese Abwägung nicht treffen will, hinterlegt
keinen Schlüssel und verliert nichts als eine Bequemlichkeit.

Ungeklärt bleibt der Freitext: Notizen zu einzelnen Kindern können Namen
anderer Kinder enthalten, und die zieht keine Ersetzung von Bezeichnern mit.
Wie damit umgegangen wird — Notizen draußen lassen, ersetzen oder ausdrücklich
freigeben —, entscheidet das Issue zur KI-Funktion. Ohne diese Klärung wird
sie nicht gebaut.

### Plattformbasis

| Punkt | Festlegung |
| --- | --- |
| Deployment Target | **macOS 15** |
| Sprache | Swift 6, Swift-6-Sprachmodus, strict concurrency `complete` |
| Oberfläche | SwiftUI, `@Observable`, `async/await`, Actors |
| Speicher | SwiftData, lokal, kein Netz |
| Projektschnitt | `.xcodeproj` (App + XCUITest) + zwei lokale SPM-Pakete |
| Unit-Tests | Swift Testing |
| UI-Tests | XCUITest |
| Lokale Toolchain | Xcode 27 Beta — **nur Werkzeug**, nicht Grundlage |
| Verbindliche Toolchain | CI: `ubuntu-latest` für den Kern, `macos-26` für die App |

Zur ersten Zeile: ADR-0001 hatte macOS 14 gewählt, weil die Zielgruppe
Schulrechner sind und nicht Entwicklungsmaschinen. Diese Rücksicht gilt
weiter, aber sie trifft jetzt jemand anderen. Solange der macOS-Client ein
zweiter Zugang zum selben Konto war, hätte ein zu hohes Deployment Target
Nutzer ausgesperrt. Jetzt ist er ein zusätzliches Angebot: Wer einen älteren
Mac hat, benutzt weiterhin den Web-Client, der unverändert weiterläuft.

Dafür ist macOS 15 die erste Fassung, auf der SwiftData vollständig genug ist.
Deklarative Indizes (`#Index`) und zusammengesetzte Eindeutigkeit über mehrere
Schlüsselpfade (`#Unique`) gibt es erst ab macOS 15, ebenso den eigenen
`DataStore` und die Änderungshistorie. Auf macOS 14 bliebe davon allein
`@Attribute(.unique)` auf einer einzelnen Eigenschaft; jeder Index wäre
Handarbeit im Repository-Code — genau die Sorte stiller Fehler, die eine lokale
Datenbank teuer macht. Wenn der Speicher der Kern des Produkts wird, ist es
falsch, ihn auf der unvollständigeren Fassung des Frameworks zu bauen.

Der Sprung kostet die MacBook Air der Jahrgänge 2018 und 2019, die macOS 14
noch tragen und macOS 15 nicht mehr. Alle übrigen Modelle, die macOS 14
tragen, tragen auch macOS 15. Für die ausgeschlossenen Geräte bleibt der
Web-Client die Antwort.

Beta-SDKs bleiben als Projektgrundlage ausgeschlossen. Lokal liegt Xcode 27
auf macOS 27, beides Beta; verbindlich grün ist der CI-Lauf. Weicht der
lokale Build ab, gewinnt die CI.

## Folgen

**Gut.** Der erste Meilenstein wird erheblich kleiner. Keine Anmeldung, keine
Sitzungserneuerung, kein Kontowechsel, keine Netzzustände, kein
optimistisches Sperren, kein Serverkonflikt, keine RLS-Gegenprobe. Was
gebaut wird, ist Sitzplanarbeit.

**Gut.** Schülerdaten verlassen den Rechner nicht — außer im KI-Aufruf, und
der ist pseudonymisiert, ausdrücklich ausgelöst und ohne Schlüssel gar nicht
möglich. Für eine Anwendung, die Gesundheits- und Fördermerkmale von Kindern
verarbeitet, ist das die deutlich stärkere Position.

**Gut.** Der Kern ist ohne Oberfläche und ohne Datenbank testbar und läuft
damit im billigen Linux-Job. Fixtures, `seatId`, Rasterrundung, Toleranzen
und Sitzregeln brauchen weder einen Mac-Runner noch ein Supabase-Projekt.

**Gut.** Kein Betriebsaufwand. Kein Projekt, das pausiert wird, keine
Schlüsselrotation, keine Rechnung, die von der Zahl der Nutzer abhängt.

**Teuer.** Es gibt keine Sicherung mehr. Ein Rechner, eine Datei, ein Nutzer:
Geht das Gerät kaputt und läuft keine Time Machine, sind die Daten weg. Der
Server war nebenbei auch das Backup, und dieser Nebeneffekt entfällt
ersatzlos. Ein Export gehört deshalb früh auf die Liste — er ist nicht Teil der
ersten Meilensteine, aber er ist keine Kür. Die [Roadmap](../roadmap.md) zieht
ihn bewusst vor, statt ihn ans Ende zu hängen.

**Teuer.** Kein Gerätewechsel. Wer den Mac tauscht, nimmt die Daten von Hand
mit oder fängt neu an. Solange es keinen Export gibt, ist „von Hand“ das
Wandern der Datei im Application-Support-Ordner, und das ist keine Antwort,
die man einer Lehrkraft geben will.

**Teuer.** Zwei Produkte mit gleichem Namen und gleichem Aussehen halten
verschiedene Daten. Wer beide benutzt, hat zwei getrennte Klassenlisten und
merkt es erst, wenn eine Klasse fehlt. Die Oberfläche muss das sichtbar
machen, statt es zu verschweigen.

**Teuer.** Die doppelte Fachlogik aus ADR-0001 bleibt bestehen —
Rasterrundung, `seatId`, tolerantes Lesen, Regelprüfung existieren weiterhin
zweimal —, jetzt aber ohne das gemeinsame Backend, das die Doppelung
gerechtfertigt hat. Sie ist reine Doppelung geworden. Angenommen wird sie,
weil die Fixtures aus ihr einen prüfbaren Zustand machen und weil der
Alternativpreis, den ADR-0001 dafür zahlte, höher war.

**Überraschend.** Der Wegfall des Backends macht die Fixtures wichtiger, nicht
unwichtiger. Sie sind ab jetzt die einzige geschriebene Stelle, an der das
Verhalten dieser Anwendung nachprüfbar festgehalten ist — vorher stand
dahinter noch ein Schema.

**Überraschend.** Der Ausschluss von Dark Mode bleibt bestehen. Er kam aus dem
Designsystem des Web-Clients, und das bleibt die gestalterische Quelle, auch
wenn die Daten getrennt sind. Auf macOS ist das ungewohnt und muss aktiv
gesetzt werden.

**Offen.** Sicherung und Export. Signierung und Notarisierung. Der Umgang mit
Freitext-Notizen im KI-Prompt. Jeder dieser Punkte hat ein eigenes Issue und
darf nicht nebenbei entschieden werden.

## Verworfen

*Die Edge Function behalten und nur die Datenhaltung lokal machen.* Der
saubere Mittelweg auf den ersten Blick: Der Schlüssel bliebe geheim, die
Deckel blieben wirksam. Er verlangt aber genau das, was hier abgeschafft
wird — ein Supabase-Projekt, ein Konto und einen Anmeldefluss, damit die
Funktion weiß, wer ruft und gegen wessen Kontingent. Man zahlte den vollen
Preis der Kopplung für ein Merkmal am Rand der Anwendung.

*Den Schlüssel in die Anwendung einbacken.* Bequem für die Lehrkraft und
sofort erledigt. Ein Schlüssel in einer ausgelieferten Binärdatei ist
auslesbar, unabhängig davon, wie er dort abgelegt ist; die Rechnung trüge der
Herausgeber, und der erste Fund im Netz beendete die Funktion für alle.

*Lokal zuerst, Synchronisation später anschließen.* Klingt nach der offenen
Tür, ist aber die teuerste Variante: Sie verlangt schon heute
Konfliktstrategie, stabile Identitäten über Geräte hinweg und Vektoruhren
oder Ähnliches im Datenmodell, sonst ist die spätere Synchronisation nicht
anschließbar. Man baut die Kosten des Servers ein, ohne seinen Nutzen zu
haben. Wenn Synchronisation kommt, kommt sie mit eigenem ADR und mit dem
Recht, das Datenmodell dafür zu ändern.

*CloudKit statt Supabase.* Wäre die naheliegende Apple-Antwort, ersetzt aber
nur den Anbieter, nicht die Eigenschaft: Schülerdaten lägen wieder auf einem
fremden Server, dazu in einem Konto, das die Lehrkraft privat besitzt und das
mit Familienfreigabe und Geräteverwaltung an der Schule kollidiert. Und
CloudKit ist Synchronisation — siehe oben.

*Ein Dateidokument statt einer Datenbank, `DocumentGroup` mit
`.sitzplan`-Dateien.* Sehr macOS-typisch, brächte Versionen, Time Machine und
Weitergabe geschenkt. Es passt aber nicht zum Gegenstand: Klassen, Schüler,
Räume und Pläne verweisen aufeinander, eine Klasse steckt in mehreren Plänen,
und der Papierkorb ist übergreifend. Das wäre eine Datenbank in einer Datei,
von Hand gebaut. Für den Export bleibt die Idee richtig und kommt dort wieder.
