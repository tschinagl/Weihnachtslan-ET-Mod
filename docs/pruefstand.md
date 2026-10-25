# Testvertrag und Nachweise für LLM-Agenten

## Testauswahl

Host-Plattform zuerst feststellen und `AGENTS.md` befolgen: Windows nur Windows, Linux nur Linux. Keine automatische Erweiterung auf die Gegenplattform durch WSL/Container/VM/SSH. Cross-platform-Abnahme nur beim ausdrücklich beauftragten Release.

| Änderung | Erforderliche lokale Prüfung |
|---|---|
| Nur Dokumentation | Verweise, Befehle gegen vorhandene Skripte, Konsistenz, Encoding/Zeilenenden; kein Spielstart |
| Build-/Paketwerkzeug | Relevanten Werkzeugpfad bzw. dessen portable Logik auf der Host-Plattform prüfen; nativen Build bei betroffenen Buildpfaden |
| Gamecode | Regulärer Host-Build + CTest; passende native Assertions |
| Interaktion, Prediction, Laden von Modulen | Zusätzlich passender Host-Server-/Client-Smoke |
| Release für Windows und Linux | Explizite Zielplattformmatrix und gemischte Verbindungen nach `installation.md` |

## Testsemantik

- `tests/native/etlab_loadouts.c`: echte Gameplay-Funktionen; Engine-Geometrie, PVS und Benachrichtigungen kontrolliert. Spawn/Loadouts, Klassen/Teams, XP 0/4, Zangenrechte, Minensuche und Schaden werden geprüft.
- `tests/smoke.lua`: Map Oasis, Modname, Lua-Init und Frames. Server-Smoke prüft zusätzlich Loopback, RCON und sauberen Exit. Kein Spieler-/Rendering-Nachweis.
- `tests/mines-runtime.lua`: echter Client; Fernglas, Pistolen und Zange über Spielbefehle. Entschärfung Soldier/Engineer bei Skill 0/4 für Dynamit und Mine. Granaten werden nach echtem Wurf für reproduzierbare Positionierung neben die Mine versetzt; Fuse, Explosion und Schaden sind echte Gameplay-Ausführung.
- `tests/test_linux_packaging.py`: portable Archivlogik unter dem Host-Python; erzeugt keine Linux-Prozesse und ist kein Linux-Runtime-Test.
- Spielprofile frisch halten, Screenshot ansehen, eigene Testprozesse beenden. Build-/Paket-Hashes dem Lauf zuordnen. Keine fremden Profile oder Prozesse bereinigen.

## Vorliegende Windows-Nachweise

Stand 25.10.2026, offizieller Release 2.86.2, Upstream-Commit `fdb40f8706b4e5081bf721cdc5726b2791a6e1f9`:

- Mod-only Release-Build mit VS 2022 / MSVC 19.44: erfolgreich; `BUILD_CLIENT=OFF`, `BUILD_SERVER=OFF`, `BUILD_MOD=ON`.
- 1337 native Gameplay-Prüfungen erfolgreich. Medic-Prüfungen umfassen Klassenwechsel, Fernglas-Level 0–4, Zangenverbote, fehlende Minenmarkierung und erhaltene Trap Awareness.
- Offizielle Engine-Executables mit Downloadarchiv bytegleich geprüft.
- Dedicated-Server-Smoke und echter Client-Smoke erfolgreich; Screenshot geprüft.
- Zangentakt Soldier/Engineer bei identischem Skill: etwa 100/50 ms; vollständige Defuses mit Frame-Toleranz. Verzögerte Entfernung von Dynamit kann einen zusätzlichen Engineer-Impuls ergeben.
- Schutz vor ungesicherten Source-Änderungen geprüft: Vorbereitung bricht ab und erhält Edits.

## Vorliegende Linux-Nachweise

Stand 25.10.2026, Linux x86_64, Ubuntu 24.04, GCC 13.3, CMake 3.28, glibc 2.39, offizieller Release 2.86.2:

- Mod-only Build und native CTest-Prüfungen erfolgreich.
- Offizielle Linux-Engine lädt den Mod; Server-Smoke mit Oasis, Lua, Loopback und RCON erfolgreich.
- Grafischer Client-Smoke unter WSLg erfolgreich, einschließlich Fernglas, Akimbo, Entschärfung und beiden Handgranaten. Screenshot geprüft.
- Konkreter Mod-Arbeitsstand und Artefakthashes stehen in den jeweiligen Nachweisdateien. Ergebnisse nicht ungeprüft auf einen anderen Commit/Diff übertragen.

Diese vorhandenen WSLg-Nachweise ändern die Host-Plattformregel nicht: weitere Linux-Tests auf Windows erst im beauftragten Release.

## Artefakte und Grenzen

- Windows: `logs/`, `profiles/client-smoke-*/etlab/`, `<Windows-sourcePath>/build/Testing/Temporary/LastTest.log`.
- Linux: `logs/linux/build.json`, `server-smoke.json`, `client-smoke.json`, `profiles/linux-*/etlab/`, `<Linux-sourcePath>/build/Testing/Temporary/LastTest.log`.
- Logs/Profile sind lokal und absichtlich nicht eingecheckt. Fehlen sie in einem frischen Clone, Nachweise nicht erfinden.
- Upstream-Compilerwarnungen bestehen. Keine vollständige Abnahme aller Maps, Bots, Revive-Fälle, Grafiktreiber oder Distributionen.
- Gemeinsames PK3 strukturell prüfen; echte Windows-Client-/Linux-Server-Verbindungen und weitere Plattformkombinationen bleiben Release-Abnahme.
