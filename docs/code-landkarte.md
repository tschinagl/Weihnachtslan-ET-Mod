# Code-Orientierung

Die folgenden Pfade beziehen sich auf den automatisch vorbereiteten Release-Source. Sein Pfad steht unter Windows in `.cache/state.json`, unter Linux in `.cache/linux/state.json`, jeweils unter `sourcePath`. Die versionierte Änderung liegt in `mod/etlab.patch`.

| Thema | Dateien und Einstieg |
|---|---|
| Klassen, Waffen, Spawn-Loadouts | `src/game/bg_classes.c`: Klassentabellen, `BG_HeavyLoadoutAkimbo`, `BG_IsSecondaryWeaponAvailable`, `BG_GetBestSecondaryWeapon` |
| Spawn und Munition | `src/game/g_client.c`: `SetWolfSpawnWeapons`, `ClientSpawn` |
| Limbo-Auswahl | `src/cgame/cg_limbopanel.c`; Servervalidierung in `g_cmds.c` |
| Gemeinsame Waffenlogik | `src/game/bg_pmove.c`: `PM_Weapon`, Zangentakt; Client und Server gemeinsam bauen |
| Zange | `src/game/g_weapon.c`: `G_CanUsePliersOn`, `Weapon_Engineer`, Scharfmachen/Entschärfen |
| Minenflagge und Übungsfeld | `g_weapon.c`: `G_RevealLandmine`, `G_ETLabPracticeTargets`; Command in `g_cmds.c` |
| Fernglas-Minenentdeckung | `src/game/g_teammapdata.c`: `G_CheckSpottedLandMines` |
| Snapshot-Sichtbarkeit | `src/game/g_missile.c` |
| Hinweise | `src/game/g_main.c` |
| Minenschaden | `src/game/g_combat.c`: `G_DamageExt`, vorhandene Radius-/Deckungsprüfung |
| Deklarationen | `bg_public.h`, `g_local.h` |

Alle bisherigen Spielregeln passen in den Gamecode-Mod. Für weitere Klassen müssen zusätzlich Klassenanzahl, Tabellen, Limbo, Characters, Session, Skills, Bots und Netzwerkannahmen zusammen geprüft werden. Eine neue Klasse ist nicht automatisch ein neuer XP-Skill.

Cvars ändern nur vorhandene Optionen. Lua eignet sich für Serverregeln und Tests, soweit die API diese Funktionen zugänglich macht. Veränderungen von Waffenverhalten, Prediction oder Client-Auswahl benötigen häufig den hier verwendeten nativen Gamecode-Mod.

Engine-Dateien unter anderem in `src/client`, `src/server`, `src/renderer*` sowie externe `libs/` gehören nicht zu den Mod-Änderungen. CMake wird lediglich um das native Testziel ergänzt.

## ETBudget

- bg_public.h / bg_classes.c: PC_CUSTOM, STAT_CUSTOM_LOADOUT, gemeinsamer Katalog, Kosten, Validierung und Fähigkeitenprüfungen.
- g_cmds.c / g_session.c / g_client.c: validierte Spawn-Auswahl, Cancel, persistente Session, Ausrüstung und cb-Konfigurationsschlüssel.
- cg_limbopanel.c / cg_players.c: sechster Button, Punktepanel, Eingabe und serverseitig bestätigte Auswahl.
- g_weapon.c / bg_pmove.c / g_main.c / g_misc.c: Zangen- und Revive-Berechtigungen. g_items.c verhindert nicht gekaufte Waffen-Pickups.
- cg_draw_hud.c: Charge-Anzeige nach aktuell gewählter Waffe.
- tests/budget-runtime.lua und scripts/Test-BudgetClient.ps1: echter stummer Hintergrund-Clienttest.
