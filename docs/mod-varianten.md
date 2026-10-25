# Mod-Varianten und Branch-Vertrag

## Zuordnung

Dieses Repository enthält zwei eigenständige Gamecode-Mods. Der ausgecheckte Branch bestimmt den Mod. Der Budget-Branch dient als aufbewahrter Machbarkeitstest und ist kein zur Übernahme in main vorgesehener Feature-Branch.

| Branch | Mod | fs_game / Paketordner | Funktionsumfang | Windows-Starter |
|---|---|---|---|---|
| [main](https://github.com/tschinagl/Weihnachtslan-ET-Mod/tree/main) | Weihnachts-LAN-Mod | etlab | Fünf klassische Klassen mit den dokumentierten Loadout-, Zangen- und Minenregeln | ETLab starten.cmd |
| [experiment/custom-budget](https://github.com/tschinagl/Weihnachtslan-ET-Mod/tree/experiment/custom-budget) | ETBudget | etbudget | Zusätzlich Custom mit zwölf Punkten und acht kombinierbaren Ausrüstungs-/Fähigkeitspaketen | Budget-Mod starten.cmd |

Die fünf klassischen Klassen sind auch in ETBudget verfügbar. Die offizielle ET: Legacy-Engine wird für beide Mods unverändert verwendet. Gleich benannte Dateien wie mod/etlab.patch und scripts/Build-Mod.ps1 enthalten den jeweiligen branchabhängigen Stand; ihr Name allein identifiziert den Mod nicht.

## Ergebnis des Machbarkeitstests

Am 25.10.2026 wurde ETBudget unter Windows praktisch ausprobiert. Die Rückmeldung im Chat bestätigt ausdrücklich, dass der Test prinzipiell funktioniert. Damit ist das Grundprinzip einer im Limbo-Menü zusammenstellbaren Custom-Klasse mit Punktebudget erfolgreich erprobt. Der geprüfte Prototyp ist im Commit [758464d](https://github.com/tschinagl/Weihnachtslan-ET-Mod/commit/758464d) festgehalten.

Der technische Nachweis umfasst Windows-Build, 11.068 native Prüfungen und einen echten Client-Test mit Budgetvalidierung, Spawn-Übernahme und ausgewählten Waffen-/Werkzeugaktionen. Automatische Grafiktests des Prototyps laufen auf einem separaten unsichtbaren Windows-Desktop mit deaktiviertem Sound. Details und Grenzen stehen im [ETBudget-Testvertrag](https://github.com/tschinagl/Weihnachtslan-ET-Mod/blob/experiment/custom-budget/docs/pruefstand.md).

Die persönliche Rückmeldung bestätigt das Prinzip, keine vollständige Abnahme jeder Kombination oder Interaktion. Balancing im LAN, Multiplayer, tatsächliches Wiederbeleben eines zweiten Spielers, sämtliche Engineer-Karteninteraktionen, Bots und Linux-Runtime sind für ETBudget nicht vollständig abgenommen. Luftangriff, Artillerie, Uniformwechsel und Armor sind im Prototyp nicht implementiert. Der erfolgreiche Versuch enthält keinen Auftrag für einen Release oder weiteren Ausbau.

## Arbeitsvertrag für Entwickler und LLM-Agenten

- Vor Änderungen aktuellen Branch mit git branch --show-current und Arbeitsstand mit git status prüfen. Mod-Zuordnung anhand dieser Tabelle und der branchlokalen README bestimmen.
- Arbeiten am Weihnachts-LAN-Mod gehören nach main; Arbeiten an ETBudget nach experiment/custom-budget. Bei unklarem Zielmod zuerst klären, bevor Gameplay geändert wird.
- Kein automatischer Merge, Rebase oder pauschales Zurückführen des Budget-Branches nach main. Ein Worktree ist hier ein Arbeitsordner für einen eigenständigen Mod, keine implizite Merge-Aufgabe.
- Gemeinsame technische Verbesserungen nur auf ausdrücklichen Auftrag gezielt auf den anderen Branch übertragen und dort prüfen. Mod-spezifische Regeln und Pakete getrennt erhalten.
- Getrennte Worktrees/Clones sowie eigene Source-Caches, Buildverzeichnisse, Runtimes, Profile und Logs verwenden. Aktiven Source aus dem State des jeweiligen Checkouts ermitteln; keine generierten Mod-Binaries zwischen den Varianten mischen.
- Beim Start und Export fs_game, Modordner und Starter überprüfen. Nur Mod-Module bauen; keine Änderungen an Engine, externen Libraries oder Originalinstallationen.
- Plattform- und Testregeln des jeweiligen AGENTS.md beachten. Eine erfolgreiche Prüfung eines Mods gilt nicht automatisch für den anderen.

## Referenz

[Issue #2: Zwei eigenständige Mods und erfolgreicher Punktebudget-Prototyp](https://github.com/tschinagl/Weihnachtslan-ET-Mod/issues/2) dokumentiert die getroffene Einordnung.
