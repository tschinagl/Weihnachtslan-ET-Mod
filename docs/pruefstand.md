# Testvertrag und Nachweise: ETBudget

## Testauswahl

- Windows-Arbeitsrechner: ausschließlich Windows-Build und Windows-Runtime. Keine Linux-/WSL-/Container-/SSH-Tests.
- Regulärer Build: Windows PowerShell 5.1, scripts/Build-Mod.ps1 -Locked; native CTest-Prüfungen vor Staging.
- scripts/Test-ETLabServer.ps1 prüft Dedicated Server, Oasis, Lua, Loopback, RCON und sauberen Exit.
- scripts/Test-BudgetClient.ps1 prüft den echten grafischen Client in einem frischen Profil. scripts/Hidden-TestClient.ps1 startet ihn auf einem privaten Windows-Desktop, deaktiviert die Audioinitialisierung und wechselt niemals den sichtbaren Desktop. Auch Start-ETLabGame.ps1 -SmokeTest/-MineSmoke nutzt diesen Hintergrundstarter.
- Ein sichtbarer Teststart oder Ton ist nicht zulässig. Bei Fehlern des Hintergrundstarters abbrechen; kein sichtbarer Fallback.

## Windows-Nachweise

Stand 25.10.2026, offizieller Release 2.86.2, Upstream fdb40f8706b4e5081bf721cdc5726b2791a6e1f9:

- Windows x64 Mod-only-Build und native Tests erfolgreich. Engine und externe Libraries unverändert.
- Native Matrix: alle 256 Budgetmasken in beiden Teams, Kosten und Budgetgrenzen, unbekannte/negative Masken, Spawn-Inventar, unerlaubte Primär-/Sekundärwaffen, Berechtigungen, Entfernen von Ausrüstung und Wechsel in klassische Klassen. Vorhandene Klassen-/Minenprüfungen weiterhin enthalten.
- Runtime: Custom-Spawn, Client-Synchronisierung, Ablehnung überteuerter/unbekannter/negativer Auswahl, Annahme gültiger vorgemerkter Auswahl, unverändertes laufendes Leben, Übernahme beim nächsten Spawn und Entfernen der Spritze.
- Echte Eingabe über Spielbefehle: Medic-Päckchen geworfen und im Spiel vorhanden; Spritze und zusätzliches Sniper-Gewehr auswählbar; Mine geworfen und vorhanden; Zange auswählbar. Beide Teams verbunden/bespielt im selben lokalen Clientlauf.
- Limbo-Screenshot geprüft: sechs Klassenbuttons, acht Pakete, Kosten, gewählte und deaktivierte Einträge, Punkteanzeige.
- Unsichtbarer Runtime-Lauf erfolgreich: privater ETBudgetTest-Desktop, Eingabe-Desktop vor/nach Test unverändert, Sound disabled im Engine-Log, gerenderter Screenshot vorhanden und geprüft.

## Artefakte und Grenzen

- Lokale Ergebnisse: logs/build.log, .cache/sources/v2.86.2/build/Testing/Temporary/LastTest.log, logs/budget-client.json, profiles/budget-smoke-*/etbudget/etconsole.log und Screenshots. Nicht versionieren.
- Passende Patch-/Engine-Hashes werden im Client-Testbericht festgehalten. Nach Codeänderungen Build und betroffene Runtime-Prüfung wiederholen.
- Keine vollständige Multiplayer-/Revive-/Map-/Bot-Abnahme. Tatsächliches Wiederbeleben eines zweiten Spielers, jede Engineer-Karteninteraktion und Balancing im LAN bleiben offen. Screenshot und Spielbefehle sind kein Nachweis eines vollständigen manuellen Mausklick-Durchlaufs.
- Linux-Werkzeugpfade sind auf die Mod-ID abgestimmt; Linux-Build/Runtime dieses Prototyps nicht geprüft. Kein plattformübergreifender Release beauftragt.
