# Agentenvertrag: ETBudget-Mod

## Zwei eigenständige Mods

- Vor Arbeiten `docs/mod-varianten.md` lesen und den aktuellen Branch prüfen. `main` gehört zu `etlab`; `experiment/custom-budget` gehört zu `etbudget`.
- Die Branches sind eigenständige Mod-Varianten. ETBudget ist ein am 25.10.2026 grundsätzlich erfolgreich ausprobierter Machbarkeitstest; kein automatischer Merge, Rebase oder Rückführen nach `main`.
- Ein erfolgreicher Prototyptest ist keine vollständige Release-/Multiplayer-/Balancing-Abnahme und kein Auftrag zum Ausbau. Änderungen nur im beauftragten Mod durchführen.

## Scope und Dokumentation

- Dieses Repository wird ausschließlich durch LLM-Agenten entwickelt. README-Einleitung: kurze Beschreibung des Weihnachts-LAN-Mods. Übrige Dokumentation: technische Agentenanweisungen, Invarianten, Befehle, Nachweise und Grenzen; keine persönlichen Bezüge oder menschlichen Tutorials.
- README und `.agents/skills/etlab-mod/SKILL.md` lesen; gezielt passende Referenzen nachladen.
- Gameplay-Sollzustand: `docs/spielregeln.md`. Vorhandene Regeln erhalten, soweit der Auftrag sie nicht ausdrücklich ändert.
- Nur Gamecode-Mod bearbeiten. Offizielle Release-Engine und externe Libraries unverändert verwenden.

## Experiment-Vertrag

- Branch `experiment/custom-budget`; eigener Worktree, Source-Cache, Runtime und Profile. Mod-ID `etbudget`; keine Änderungen oder Übernahme in `main` ohne Auftrag.
- Windows-Prototyp: `Budget-Mod starten.cmd` startet mit dem Release-Lock; lokaler Spielport 27980.
- Custom-Katalog und Kosten: `bg_customOptions` und `CUSTOM_BUDGET`; Server und Client verwenden dieselben Definitionen.
- Grafiktests ausschließlich über `scripts/Hidden-TestClient.ps1`: privater Windows-Desktop, niemals zum Testdesktop wechseln, Audioinitialisierung mit `s_initsound 0` deaktiviert. Keine sichtbaren Testfenster und kein Ton. Interaktiver Spielstart bleibt davon getrennt.

## Plattform und Tests

- Die Plattform des Arbeitsrechners bestimmt den Standard: Windows → nur Windows-Build/Tests; Linux → nur Linux-Build/Tests.
- Auf einem Windows-Rechner keine automatischen zusätzlichen Linux-Prüfungen über WSL, Docker, VM oder SSH ausführen. Eine vorhandene Linux-Umgebung ist keine Freigabe dafür. Auf Linux keine automatischen zusätzlichen Windows-Prüfungen ausführen.
- Plattformübergreifende Abnahme nur als Teil eines ausdrücklich beauftragten Releases. Bei normaler Entwicklung keine vollständige Release-Matrix starten.
- Nach Codeänderungen regulär auf der eigenen Plattform bauen. Build enthält native CTest-Prüfungen vor Staging. Runtime-Tests nur passend zur Änderung; reiner Dokutext braucht keinen Spielstart.
- Build, native Assertions, Server-Smoke, Client-Smoke und gemischter Multiplayer sind unterschiedliche Nachweise. Nicht getestete Eigenschaften ausdrücklich offen lassen.
- Bei laufendem Spiel, gesperrten Dateien oder Debug-Sitzung abbrechen und melden; keine fremden Prozesse beenden. Tests beenden nur ihre eigenen Prozesse.

## Source- und Buildvertrag

| Plattform | Build | Aktiver Source-State | Änderungen sichern |
|---|---|---|---|
| Windows x64 | `scripts/Build-Mod.ps1` | `.cache/state.json` | `scripts/Save-ModChanges.ps1` |
| Linux x86_64 | `python3 scripts/etlab-linux.py build` | `.cache/linux/state.json` | `python3 scripts/etlab-linux.py save` |

- Normaler Build verwendet die neueste offiziell veröffentlichte Stable-Version. `-Locked` / `--locked` nur bewusst für reproduzierbare Prüfungen verwenden; kein stiller Wechsel auf Entwicklungsstände.
- Gamecode im durch `sourcePath` bezeichneten Checkout bearbeiten; anschließend in `mod/etlab.patch` sichern. Neue Source-Dateien mit `git add -N` erfassen. Keine eigenen Commits im Abhängigkeits-Checkout.
- Native Tests direkt in `tests/native/` pflegen; vorbereitete Checkouts erhalten nur Kopien. CMake baut regulär im `build/` des jeweiligen Source-Checkouts.
- Ungesicherte Änderungen niemals durch Reset/Neuaufsetzen überschreiben. Release-Konflikte und Compilerfehler diagnostizieren; bestehenden Stand erhalten.
- Windows-/Linux-Clientmodule für gemischte LANs in einem gemeinsamen PK3 bereitstellen; Export prüft übereinstimmenden Source-Commit und Mod-Patch. Cross-platform-Runtime-Abnahme erst beim Release.

## Dateien und Übergabe

- Bestehende Encodings/Zeilenenden erhalten. PS1: Windows PowerShell 5.1, UTF-8 mit BOM, CRLF. Python/Shell: UTF-8 ohne BOM, LF. SKILL.md mit YAML-Kopf: UTF-8 ohne BOM, CRLF.
- Lokale Assets, Downloads, Builds, Profile und Logs nicht committen. Keine Server-Umstellung oder Veröffentlichung ohne entsprechenden Auftrag; eine im Chat erteilte Freigabe nicht erneut erfragen.
- Parallele Änderungen anderer Aufgaben erhalten und nicht ungefragt in den eigenen Commit aufnehmen. Vor Änderungen und vor Staging `git status`/Diff prüfen.
- Abschluss: geänderte Dateien, native Prüfungen und Grenzen knapp nennen. Keine fremden Plattformtests als Teil einer normalen lokalen Abnahme auslösen.
