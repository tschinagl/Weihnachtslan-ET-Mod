# Bereitstellungs- und Release-Vertrag für LLM-Agenten

## Scope

Diese Datei bei Paketexport, Installationsauftrag, LAN-Bereitstellung oder Release lesen. Das Vorhandensein dieser Anleitung autorisiert keine Serveränderung, Veröffentlichung oder plattformübergreifende Tests. Normale Entwicklung folgt ausschließlich der Host-Plattform; vollständige Plattformmatrix erst bei einem ausdrücklich beauftragten Release.

## Vorbedingungen ermitteln

- Zielsystem/Architektur: Windows x64 oder Linux x86_64; vorhandene offizielle ET: Legacy-Installation und deren tatsächliche Startbefehle.
- Passender Mod-Stand, `manifest.json`, Release-Lock, Source-Commit und Patch-Hash. Keine Gleichheit allein aus einem PK3-Dateinamen ableiten.
- Original-Spieldaten vorhanden: `pak0.pk3`, `pak1.pk3`, `pak2.pk3`. Nicht in Mod-ZIPs oder Git aufnehmen.
- Installationspfad, `fs_homepath`, aktive Spiel-/Serverprozesse und vorhandene `etbudget`-Dateien prüfen. Individuelle Configs/Profile nicht überschreiben.

## Paketexport

| Buildplattform | Befehl | Ausgabe |
|---|---|---|
| Windows | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Export-Mod.ps1` | Windows-Mod-ZIP und Mod-Projekt-ZIP |
| Linux | `python3 scripts/etlab-linux.py export` | Linux-Mod-ZIP |
| Linux, vorhandenes passendes Windows-ZIP | `python3 scripts/etlab-linux.py export --windows-package /pfad/windows-mod.zip` | Kombiniertes Windows-/Linux-Mod-ZIP |

Ausgaben liegen in `dist/`. Exporte bauen bzw. verwenden den festgehaltenen Release-Stand. Für ein kombiniertes Paket müssen Source-Commit und Patch übereinstimmen; Windows-Dateihashes werden geprüft. Keine zweite Plattform nur wegen eines Exportauftrags starten. Fehlendes Gegenplattform-Artefakt erst im entsprechenden Release-Workflow beschaffen.

## Installation

- Bestehenden eigenen `etbudget`-Ordner separat sichern, dann vollständig durch den Paketinhalt ersetzen; keine alten PK3s beimischen.
- `etbudget` liegt neben `etmain`. Auf Server und allen Clients identisches kombiniertes Paket verwenden, wenn Windows und Linux gemeinsam spielen.
- Persönliche Download-Caches können Pakete überdecken. Für Abnahme separates `fs_homepath` verwenden; keine fremden Profile bereinigen.
- Engine-Dateien nicht durch Mod-Artefakte ersetzen. Windows lädt DLLs, Linux SO-Dateien; beide Clienttypen brauchen passende Module im identischen PK3.

Startparameter für die tatsächliche offizielle Installation ableiten:

```sh
# Linux, offizielles x86_64-Archiv; HOST und PORT aus Auftragskontext.
./etl.x86_64 +set fs_game etbudget +connect HOST:PORT
./etl.x86_64 +set fs_game etbudget +set g_etlabPractice 1 +map oasis
./etlded.x86_64 +set dedicated 1 +set net_ip 0.0.0.0 +set net_port 27960 +set fs_game etbudget +set sv_advert 0 +map oasis
```

```powershell
# Windows x64
.\etl.exe +set fs_game etbudget +connect HOST:PORT
.\etl.exe +set fs_game etbudget +set g_etlabPractice 1 +map oasis
```

LAN-Server ausdrücklich an gewünschte Adresse binden; Entwicklungsstarter verwenden sonst Loopback. Firewall, öffentliche Werbung, Downloadserver und externe Serverkonfiguration nur im beauftragten Scope ändern. Ohne Downloadserver müssen Clients das Paket vor dem Beitritt erhalten. Dedicated Server dürfen keine Übungsobjekte erzeugen.

## Release-Abnahme

Nur bei Release-Auftrag:

1. Gemeinsamen Source-Commit, Mod-Patch, Stable-Version und Plattform-Locks festhalten.
2. Auf jeder beauftragten Zielplattform regulär bauen und native Tests ausführen.
3. Server- und relevante Gameplay-Tests auf den Zielplattformen durchführen; Hashes und Logs zuordnen.
4. Gemeinsames Paket erzeugen und Zip-/PK3-Inhalt, Prüfsummen und lokale Installation prüfen.
5. Bei gemischter LAN-Zielgruppe Windows-Client ↔ Linux-Server und Linux-Client ↔ Server mit identischem PK3 und aktiviertem Pure-Check tatsächlich verbinden. Ein strukturell korrektes ZIP ist dafür kein Runtime-Nachweis.
6. Grenzen dokumentieren: Distribution/glibc, Grafiktreiber, Architekturen, Maps/Bots und nicht ausgeführte Fälle. Nur beauftragte Artefakte veröffentlichen.
