# LLM-Workflow

## Claude-Code-Einstieg

- Repository-Root: `CLAUDE.md` importiert `AGENTS.md`, `.agents/skills/etlab-mod/SKILL.md` und `README.md`. Fachreferenzen anschließend nach Aufgabe laden.
- Gemeinsame Regeln in den importierten Dateien pflegen. Keine Kopien in `.claude/` oder zusätzliche gleichlautende Skills erzeugen.
- Neue Claude-Code-Sitzung im Repository starten; mit `/context` die geladenen Memory-Dateien prüfen, falls ein tatsächlicher Claude-Ladetest beauftragt ist. Dateiverweise allein sind kein Nachweis einer bereits ausgeführten Claude-Sitzung.
- Projekt-ZIP muss `CLAUDE.md` und sämtliche importierten Dateien enthalten. Relative Imports verwenden, damit Windows- und Linux-Clones denselben Einstieg erhalten.

## Vorbedingungen

1. Host-Plattform bestimmen. Nicht aus vorhandener WSL-/Docker-Installation auf einen Linux-Testauftrag schließen; `AGENTS.md` entscheidet.
2. `git status --short`, Branch und Remote lesen. Fremde Änderungen nicht überschreiben oder ungefragt committen.
3. Für Gameplay `spielregeln.md` und die einschlägigen Symbole in `code-landkarte.md` lesen. Nur fachlich notwendige offene Fragen klären; Kontext und vorhandene Regeln nutzen.
4. Runtime-Installationen und persönliche Profile bleiben außerhalb des Repository-Inhalts. Kein Git-Reset zur Reparatur ungesicherter Änderungen.

## Toolchain

| Host | Voraussetzungen |
|---|---|
| Windows x64 | Git, Windows PowerShell 5.1, curl.exe; Visual Studio/Build Tools 2022 mit MSVC x64/x86, Windows SDK und C++-CMake-Tools |
| Linux x86_64 | Python ≥ 3.10, Git, GCC/G++, Make, CMake, Ninja, pkg-config; siehe `linux.md` |

Fehlende Tools konkret feststellen. Keine zweite Plattform installieren oder starten, nur um reguläre Tests zu verbreitern. Build und CTest brauchen keine Original-PK3s; Spielstart und Runtime-Tests brauchen `pak0.pk3`, `pak1.pk3`, `pak2.pk3`.

## Windows-Befehle

Experiment-Einstieg: `Budget-Mod starten.cmd` hält den Release-Lock ein. Aktueller Modname: `etbudget`; Spielport 27980. Vor Übergabe `scripts/Test-BudgetClient.ps1` ausführen. Grafiktests laufen stumm auf einem privaten Windows-Desktop; niemals einen sichtbaren Fallback starten.


Vom Repository-Root aus; nur auf einem Windows-Arbeitsrechner verwenden:

```powershell
# Bestehende Spieldaten lokal importieren; Pfad aus tatsächlicher Installation bestimmen.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Import-GameAssets.ps1 -Source 'C:\Pfad\ETLegacy\etmain'

# Neuester Stable-Release, Mod-Build und CTest.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Mod.ps1

# Nach Gamecode-Edits im aktiven Source-Checkout:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Save-ModChanges.ps1

# Passende native Runtime-Prüfungen:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ETLabServer.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-ETLabGame.ps1 -MineSmoke
```

`ETLab starten.cmd` ruft `Start-Mod.ps1` auf: Stable-Version prüfen, bei Bedarf bauen, lokalen Client starten. `Mod bauen.cmd` baut ohne Spielstart. `Build-Mod.ps1 -Locked` / `Start-Mod.ps1 -Locked` verwenden den eingecheckten Release-Lock. Die direkten `Start-ETLabGame`-/`Client`-/`Server`-Helfer verwenden den bereits vorbereiteten Stand ohne Release-Abfrage.

## Linux-Befehle

Nur auf einem Linux-Arbeitsrechner verwenden; Details in `linux.md`:

```sh
python3 scripts/etlab-linux.py import-assets --source /pfad/ETLegacy/etmain
python3 scripts/etlab-linux.py build
python3 scripts/etlab-linux.py save
python3 scripts/etlab-linux.py smoke
python3 scripts/etlab-linux.py start --locked --mine-smoke
```

## Änderungen und Updates

- Windows-State: `.cache/state.json`; Linux-State: `.cache/linux/state.json`. `sourcePath` relativ zum Repository-Root auflösen.
- Source dort bearbeiten; Tests in `tests/native/` bearbeiten. Nach Gameplay-Änderungen `save` ausführen, damit der kanonische Patch alle Änderungen enthält.
- Neue Gamecode-Dateien im Source-Checkout per `git add -N <Pfad>` erfassen; keine eigenen Source-Commits. Patch im äußeren Repository reviewen.
- Latest-Policy: offizieller Stable-Release, passender Tag und offizielles Engine-Archiv. Plattform-Lock enthält Commit, Downloadadresse, MD5 und SHA256.
- `-Locked` / `--locked`: festgehaltene Version ohne Latest-Abfrage. Beim Release gleiche Version und Patch für alle Zielplattformen sicherstellen.
- Fehlgeschlagene Release-Erkennung/Download/Patch-Anwendung führt zum Abbruch. Nicht still auf ältere Version ausweichen. Bereits vorbereitete Stände und ungesicherte Edits erhalten.

## Abschlusskriterien

- Geforderte Änderung ist im versionierten Mod-Patch bzw. in den Projektwerkzeugen enthalten; nicht nur im ignorierten Checkout.
- Build und relevante Prüfungen auf der Host-Plattform bestehen. Keine automatischen Tests der anderen Plattform.
- Doku und Skills entsprechen dem Ergebnis. Gameplay-Testfälle und Nachweisgrenzen nicht aus einer reinen Buildmeldung ableiten.
- Bei Veröffentlichungsauftrag: nur aufgabenbezogene Dateien committen/pushen, Remote-Commit und Sichtbarkeit prüfen. Ein Release/Serverdeployment ist ein eigener Auftrag.
