# Issue tracker: GitHub

Issues und PRDs fuer dieses Repository liegen in GitHub Issues. Verwende fuer alle Operationen die gh CLI.

## Conventions

- Issue erstellen: gh issue create --repo arn0ld87/sitzplan_macos --title "..." --body "..."
- Issue lesen: gh issue view <number> --repo arn0ld87/sitzplan_macos --comments
- Issues listen: gh issue list --repo arn0ld87/sitzplan_macos --state open --json number,title,body,labels,comments
- Kommentieren: gh issue comment <number> --repo arn0ld87/sitzplan_macos --body "..."
- Labels setzen/entfernen: gh issue edit <number> --repo arn0ld87/sitzplan_macos --add-label "..." / --remove-label "..."
- Schliessen: gh issue close <number> --repo arn0ld87/sitzplan_macos --comment "..."

Repository ist immer `arn0ld87/sitzplan_macos` — explizit per `--repo`, nicht aus dem lokalen Checkout geraten.

## Pull requests as a triage surface

PRs as a request surface: no.

Wenn diese Option spaeter auf yes gesetzt wird, laufen externe PRs ueber die gleichen Label- und Zustandsregeln wie Issues.

## When a skill says "publish to the issue tracker"

Erstelle ein GitHub Issue.

## When a skill says "fetch the relevant ticket"

Nutze gh issue view <number> --comments.
