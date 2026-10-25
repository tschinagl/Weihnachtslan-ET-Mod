# Gameplay-Vertrag für LLM-Agenten

Zweck: Sollverhalten bei Änderungen und Tests erhalten. Regeln gelten für beide Teams, sofern nicht ausdrücklich eingeschränkt. Diese Datei beschreibt Gameplay; Build- und Plattformregeln stehen in `AGENTS.md` und `llm-workflow.md`.

## Custom-Klasse

- Sechste Klasse, ID 5, Name Custom, mit eigenem Plus-Button im Limbo-Menü. Bestehende Klassen bleiben verfügbar.
- Budget: 12 Punkte. Katalog: Medic-Päckchen 3; Spritze 4; Ammo-Päckchen 3; Engineer-Paket 6; Sniper 4; mobiles MG 5; Satchel 4; Rauchgranate 2.
- Grundausstattung: Team-SMG mit 60 Reserve/30 Magazin, Pistole mit 24 Reserve/8 Magazin, Team-Messer und zwei Handgranaten. Vorhandene XP-Boni wirken weiter.
- Engineer-Paket umfasst Zange, drei Minen, Dynamit sowie normale Engineer-Rechte zum Bauen, Reparieren, Scharfmachen und Entschärfen. Ohne Paket keine Zangenrechte für Custom.
- Sniper und MG ergänzen die SMG. Sniper: K43/Garand mit 20 Reserve/10 Magazin; MG42/Browning mit 100 Schuss ohne Reserve. Spritze: sechs Ladungen vor XP-Boni. Satchel enthält den Fernzünder.
- Keine passive Medic-Regeneration, kein Medic-HP-Bonus, kein automatischer Fernglasbesitz. Waffen-Pickup ist für Custom gesperrt; Ammo-Päckchen funktionieren weiter.
- Gemeinsamer classWeaponTime für kostenpflichtige Aktionen; vorhandene waffenspezifische Charge-Zeiten, Verbrauch und Skill-Boni bleiben erhalten. HUD orientiert sich für Custom an der gewählten Waffe.
- Auswahl wird serverseitig auf bekannte Bits und Budget geprüft. Team-Befehl kann als sechstes Argument die Maske enthalten. Ungültige Auswahl wird verworfen, bestehende Auswahl bleibt bestehen.
- Session trennt customLoadout (nächster Spawn) und customActiveLoadout (aktuelles Leben). Revive übernimmt keine neue Auswahl. Normale Respawns übernehmen die validierte Auswahl, Klassenwechsel entfernen Custom-Fähigkeiten. Cancel setzt die vorgemerkte Auswahl auf das aktive Loadout zurück.
- Server-Konfigurationsschlüssel cb synchronisiert die akzeptierte Auswahl für das erneute Öffnen des Menüs. Lokale cg_budgetLoadout dient als Vorschlag, Startwert 19 = Medic-Päckchen, Spritze, Sniper (11 Punkte).
- Luftangriff, Artillerie, Uniformwechsel und Armor sind nicht Teil dieses Prototyps. Keine Custom-Bot-Unterstützung zugesagt; Teststarter deaktivieren Omni-bot.

## Spielregeln der klassischen Klassen

- **Akimbo:** Soldier mit Panzerfaust, alliierter Bazooka oder Flammenwerfer erhält ab 0 XP zwei Pistolen. Die normale Freischaltung über Light Weapons Level 4 bleibt für andere Loadouts erhalten. Eine auf Heavy Weapons Level 4 gewählte zusätzliche SMG bleibt zusammen mit dem Bonus verfügbar. Der Bonus richtet sich nach dem beim Spawn gewählten Loadout; ein späterer Waffen-Pickup berechnet ihn nicht neu.
- **Zusätzliche Zange:** Soldier, Field Ops und Covert Ops können damit ausschließlich scharfes Dynamit und scharfe beziehungsweise bereits ausgelöste Landminen entschärfen. Kein Bauen, Reparieren, Scharfmachen oder Entschärfen von Satchels. Bau-/Reparaturhinweise erscheinen nur beim Engineer. Durch Entschärfen erhalten andere Klassen keine Landminen zum Legen. Medics erhalten keine Zange und können damit weder Dynamit noch Minen entschärfen.
- **Entschärfungsdauer:** Soldier, Field Ops und Covert Ops arbeiten bei gleichem Skill-Level halb so schnell und benötigen damit die doppelte Dauer für Dynamit und Landminen. Der gemeinsame Client-/Server-Code verwendet 100 ms statt 50 ms zwischen Zangenaktionen. Der Fortschritt pro Aktion und die jeweiligen Skill-Boni bleiben unverändert.
- **Engineer:** Behält seine normalen Fähigkeiten und seine unveränderte Geschwindigkeit beim Bauen, Reparieren, Scharfmachen und Entschärfen.
- **Fernglas:** Soldier, Engineer, Field Ops und Covert Ops erhalten es in beiden Teams bereits ab 0 XP und können damit gegnerische Minen mit dem normalen Covert-Ops-Mechanismus entdecken. Dadurch werden keine Artillerie- oder Verkleidungsfähigkeiten vergeben. Medics erhalten das Fernglas regulär ab Battle Sense Level 1, können damit aber keine Minen entdecken oder markieren. Ihre normale Trap Awareness auf Battle Sense Level 4 bleibt erhalten.
- **Entdeckte Minen:** Können durch Schüsse auf das Fähnchen beziehungsweise dessen kleinen Trefferbereich oder durch Explosivschaden gesprengt werden. Das Fähnchen blockiert keine Spielerbewegung.
- **Unentdeckte, scharfe Minen:** Können durch deutsche Stielhandgranaten und alliierte Pineapple-Handgranaten gesprengt werden. Dafür muss die Mine vorher nicht markiert werden. Schüsse und andere Explosionsarten erhalten für verborgene Minen keine zusätzliche Freigabe. Nicht scharf gemachte Minen werden durch diese Erweiterung nicht zur Explosion gebracht.
- **Entfernung und Deckung:** Es gelten die vorhandenen Radius- und Deckungsprüfungen des Spiels, einschließlich dessen Nahbereichsregeln. Eine Explosion muss tatsächlich Schaden bis zur Mine übertragen. Minen explodieren mit ihrer normalen Wirkung; das ist kein gefahrloses Entfernen.
- **Skills:** Die vorhandenen XP-Vergaben und Skill-Boni bleiben wirksam; für Soldier, Field Ops und Covert Ops gilt zusätzlich der halbierte Zangentakt. Entschärfen benötigt keine Bauenergie. Der Engineer verwendet für Bauen/Reparieren weiterhin seine normalen Charge-Regeln.

## Übungsfeld-Invarianten

- `g_etlabPractice 1` ist opt-in. Zusätzlich müssen lokaler Host, Listenserver und Map `oasis` zutreffen. Auf Dedicated Servern keine Übungsobjekte erzeugen.
- Bei regulärem Spawn: drei gegnerische scharfe Minen (zwei verborgen, eine markiert) und ein gegnerisches scharfes Dynamitpaket. Blick auf erste verborgene Mine setzen. Revive darf das Feld nicht zurücksetzen.
- Dynamit im Übungsfeld: fünf Minuten Fuse, anschließend echte Explosion; keinem Missionsziel zugeordnet.
- `etlab_targets` / F6 entfernt nur eigene Fixtures und Kartenmarker und erzeugt sie am aktuellen Standort neu. Teams nach Teamwechsel neu bestimmen.
- Bodenpositionen müssen trocken, sichtbar und ausreichend getrennt sein. Bei unzureichendem Platz Meldung statt defekter Fixtures erzeugen.
- `g_etlabPractice 0` stoppt neues Erzeugen; Mapwechsel entfernt bestehende Entitäten.

## Beobachtbare Interaktionen

| Aktion | Kontrollpfad |
|---|---|
| Team/Klasse/Loadout | Limbo, Standardtaste L |
| Akimbo / Primärwaffe / Handgranate | Weapon banks 2 / 3 / 4 |
| Zange | Weapon bank 5; bei mehreren Werkzeugen weiterwechseln |
| Fernglas | Standardtaste B halten; normaler Fortschritt, etwa 2,5 Sekunden |
| Übungsobjekte zurücksetzen | F6 / `etlab_targets` |

Native Klassen-/Loadout-Prüfungen und echte Interaktionen getrennt testen. Für Entschärfungszeiten Soldier/Engineer bei identischem Skill 0 und 4 vergleichen; Waffenwechsel und Annäherung nicht mitzählen. Dynamit kann nach Defuse verzögert entfernt werden, daher Frame-Toleranz zulassen. Bestehende XP-/Charge-Regeln nicht unbeabsichtigt ändern.

Technische Einstiege: `code-landkarte.md`. Testvertrag: `pruefstand.md`. Nur auf der eigenen Host-Plattform testen; Cross-platform-Abnahme gehört zum Release.
