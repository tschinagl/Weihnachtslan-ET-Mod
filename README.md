# ETBudget-Mod

Ein experimenteller ET: Legacy-Mod mit einer sechsten Klasse: Custom. Im Limbo-Menü lassen sich acht Ausrüstungs- und Fähigkeitspakete innerhalb eines Budgets von zwölf Punkten kombinieren. Die fünf klassischen Klassen bleiben spielbar. Der Windows-Prototyp verwendet eigene Spielprofile und die unveränderte offizielle ET: Legacy-Engine.

## Einstieg für LLM-Agenten

Dieses Projekt wird durch LLM-Agenten entwickelt. Mit Ausnahme der Einleitung richtet sich die Dokumentation an ausführende Agenten; keine persönlichen Anreden oder Schritt-für-Schritt-Anleitungen für menschliche Entwickler ergänzen.

Claude Code lädt über `CLAUDE.md` die gemeinsamen Regeln aus `AGENTS.md`, dem Projektskill und dieser README per `@`-Import. Andere Agenten verwenden die folgenden Einstiegspunkte direkt. Die fachlichen Regeln bleiben in den gemeinsamen Dateien.

1. `AGENTS.md` lesen: Scope, lokale Plattform und Testregeln.
2. `.agents/skills/etlab-mod/SKILL.md` lesen: Workflow und technische Fallstricke.
3. Aufgabenabhängige Referenzen laden:

| Aufgabe | Referenz |
|---|---|
| Vorbereitung, Build, Änderungen sichern, Git-Übergabe | [LLM-Workflow](docs/llm-workflow.md) |
| Gameplay ändern oder überprüfen | [Verbindliche Spielregeln](docs/spielregeln.md) |
| Symbole und betroffene Module finden | [Code-Landkarte](docs/code-landkarte.md) |
| Auf einem Linux-Rechner arbeiten | [Linux-Toolvertrag](docs/linux.md) |
| Paketexport, Installation, LAN und Release | [Bereitstellungsvertrag](docs/installation.md) |
| Prüfungen wählen oder Ergebnisse einordnen | [Testvertrag und Nachweise](docs/pruefstand.md) |

## Plattformregel

**Windows-Arbeitsrechner: ausschließlich Windows bauen und testen. Linux-Arbeitsrechner: ausschließlich Linux bauen und testen.** Auf Windows keine zusätzlichen Linux-Tests über WSL, Container, VM oder Remote-Host starten. Umgekehrt auf Linux keine zusätzlichen Windows-Tests starten. Plattformübergreifende Abnahme gehört in einen ausdrücklich beauftragten Release.

## Repository-Vertrag

- Ein nativer Gamecode-Mod, interner Modname und `fs_game`: `etbudget`.
- Kanonische Mod-Änderungen: `mod/etlab.patch`; native Tests: `tests/native/`; Runtime-Assertions: `tests/*.lua`.
- Abhängigkeit: offizieller ET: Legacy-Stable-Release. Normale Vorbereitung/Build/Start ermitteln die neueste Veröffentlichung; kein `master`, Nightly oder RC.
- Reproduzierbarer Stand: Windows `release.lock.json`, Linux `release-linux.lock.json`; `-Locked` beziehungsweise `--locked` bewusst einsetzen.
- Generierte lokale Daten: `.cache/`, `runtime/`, `assets/`, `profiles/`, `logs/`, `archive/`, `dist/`. Nicht committen.
- Original-Spieldaten und Engine sind nicht Bestandteil des Mod-Repositorys. Bestehende Installationen/Profile nicht als Buildziel verwenden.
- Repository: [tschinagl/Weihnachtslan-ET-Mod](https://github.com/tschinagl/Weihnachtslan-ET-Mod). Bereitstellung, Tests und Push nur im beauftragten Scope.

## Herkunft

Gamecode-Basis: [ET: Legacy](https://github.com/etlegacy/etlegacy). Copyright-Vermerke erhalten; Lizenztext in `LICENSE` (GPL-3.0). Original-Spielassets bleiben davon getrennt. Source-Commit und Archivprüfsummen stehen im jeweiligen Release-Lock.
