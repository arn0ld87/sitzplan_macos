# Domain Docs

Wie Engineering-Skills die fachliche Dokumentation in diesem Repository lesen sollen.

## Before exploring, read these

- CONTEXT.md im Repo-Root (falls vorhanden)
- CONTEXT-MAP.md im Repo-Root (falls vorhanden; hier aktuell nicht genutzt)
- docs/decisions/ fuer Architekturentscheidungen (ADR-Quelle in diesem Repo)

Wenn eine dieser Dateien fehlt, still weiterarbeiten. Keine Pflicht, sie sofort anzulegen.

## File structure

Single-context repo (dieses Repo):

/
|- CONTEXT.md
|- docs/decisions/
|  |- 0001-nativer-macos-client.md
|  \- 0002-lokaler-einzelplatz.md
\- src/ oder Paket-Ordner

## Use the glossary's vocabulary

Wenn Domain-Begriffe in Ausgaben verwendet werden, die Begriffe aus CONTEXT.md uebernehmen (sobald vorhanden), keine eigenen Synonyme einfuehren.

## Flag decision conflicts

Wenn ein Vorschlag bestehenden Entscheidungen unter docs/decisions/ widerspricht, den Konflikt explizit benennen statt stillschweigend zu uebergehen.
