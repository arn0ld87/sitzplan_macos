# Issue tracker: GitHub

Issues und PRDs fuer dieses Repository liegen in GitHub Issues. Verwende fuer alle Operationen die gh CLI.

## Conventions

- Issue erstellen: gh issue create --title "..." --body "..."
- Issue lesen: gh issue view <number> --comments
- Issues listen: gh issue list --state open --json number,title,body,labels,comments
- Kommentieren: gh issue comment <number> --body "..."
- Labels setzen/entfernen: gh issue edit <number> --add-label "..." / --remove-label "..."
- Schliessen: gh issue close <number> --comment "..."

Das Repository wird aus dem lokalen Git-Checkout aufgeloest (origin auf GitHub).

## Pull requests as a triage surface

PRs as a request surface: no.

Wenn diese Option spaeter auf yes gesetzt wird, laufen externe PRs ueber die gleichen Label- und Zustandsregeln wie Issues.

## When a skill says "publish to the issue tracker"

Erstelle ein GitHub Issue.

## When a skill says "fetch the relevant ticket"

Nutze gh issue view <number> --comments.
