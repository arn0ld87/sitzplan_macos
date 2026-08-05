# Issues

Die Issues liegen in
[arn0ld87/sitzplan_macos](https://github.com/arn0ld87/sitzplan_macos/issues).
Diese Datei ist die Übersicht, nicht die Quelle — Volltexte stehen drüben und
werden hier nicht gespiegelt, weil eine Kopie mit Sicherheit veraltet.

Labels, angelehnt an das Web-Repo:

```
typ: feature · typ: architecture · typ: test · typ: chore · typ: fix · typ: docs
bereich: domain · bereich: data · bereich: ui · bereich: editor
bereich: ci · bereich: security · bereich: ki
prio: hoch · prio: mittel · prio: niedrig
```

## Offen

| # | Titel | Meilenstein |
| --- | --- | --- |
| [#1](https://github.com/arn0ld87/sitzplan_macos/issues/1) | Native macOS-App: lokaler Einzelplatz ohne Backend | Sammel-Issue |
| [#12](https://github.com/arn0ld87/sitzplan_macos/issues/12) | Xcode-Projekt, lokaler Speicher und Klassen | M1 |
| [#4](https://github.com/arn0ld87/sitzplan_macos/issues/4) | Schüler und Sitzregeln | M2 |
| [#5](https://github.com/arn0ld87/sitzplan_macos/issues/5) | Raumeditor | M3 |
| [#6](https://github.com/arn0ld87/sitzplan_macos/issues/6) | Sitzplaneditor und Regelprüfung | M4 |
| [#7](https://github.com/arn0ld87/sitzplan_macos/issues/7) | Drucken, PDF, Papierkorb und Qualitätsgate | M5 |
| [#15](https://github.com/arn0ld87/sitzplan_macos/issues/15) | Gemini mit eigenem Schlüssel je Lehrkraft | M6 |
| [#8](https://github.com/arn0ld87/sitzplan_macos/issues/8) | Zweistufige CI: Kern auf Linux, App auf macOS | begleitend |
| [#13](https://github.com/arn0ld87/sitzplan_macos/issues/13) | Sicherung und Export der lokalen Daten | vorgezogen |
| [#14](https://github.com/arn0ld87/sitzplan_macos/issues/14) | Rasterrückfall vereinheitlichen: 25 gegen 10 | vor M4 |
| [#11](https://github.com/arn0ld87/sitzplan_macos/issues/11) | Signierung, Notarisierung und Auslieferung | nach M5 |

Zwei Issues sind es wert, hier eigens genannt zu werden:

**[#13](https://github.com/arn0ld87/sitzplan_macos/issues/13) steht bewusst
weit vorn.** Ohne Server gibt es keine zweite Kopie mehr — der Server war
nebenbei auch das Backup. Ein Gerätewechsel ohne Export ist einer Lehrkraft
nicht zumutbar.

**[#15](https://github.com/arn0ld87/sitzplan_macos/issues/15) ist blockiert,
bis eine Frage entschieden ist.** Freitext-Notizen können Namen anderer Kinder
enthalten; die Pseudonymisierung von Bezeichnern zieht das nicht mit. Ohne
diese Entscheidung wird die KI-Funktion nicht gebaut.

## Mit ADR-0002 geschlossen

| # | Titel | Grund |
| --- | --- | --- |
| [#2](https://github.com/arn0ld87/sitzplan_macos/issues/2) | M0: Architektur, Datenverträge, Fixtures | erledigt |
| [#3](https://github.com/arn0ld87/sitzplan_macos/issues/3) | M1: Xcode-Projekt, Konfiguration und Anmeldung | `wontfix` — es gibt keine Anmeldung mehr; ersetzt durch #12 |
| [#9](https://github.com/arn0ld87/sitzplan_macos/issues/9) | Konflikterkennung: offene Punkte im Bestand | ohne Server kein Serverkonflikt; Rest in #14 |
| [#10](https://github.com/arn0ld87/sitzplan_macos/issues/10) | Offline und Synchronisation | gegenstandslos; Kehrseite in #13 |

Grundlage der Schließungen:
[ADR-0002](decisions/0002-lokaler-einzelplatz.md).
