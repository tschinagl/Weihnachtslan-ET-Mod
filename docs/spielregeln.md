# Gameplay-Vertrag für LLM-Agenten

Zweck: Sollverhalten bei Änderungen und Tests erhalten. Regeln gelten für beide Teams, sofern nicht ausdrücklich eingeschränkt. Diese Datei beschreibt Gameplay; Build- und Plattformregeln stehen in `AGENTS.md` und `llm-workflow.md`.

## Spielregeln

- **Akimbo:** Soldier mit Panzerfaust, alliierter Bazooka oder Flammenwerfer erhält ab 0 XP zwei Pistolen. Die normale Freischaltung über Light Weapons Level 4 bleibt für andere Loadouts erhalten. Eine auf Heavy Weapons Level 4 gewählte zusätzliche SMG bleibt zusammen mit dem Bonus verfügbar. Der Bonus richtet sich nach dem beim Spawn gewählten Loadout; ein späterer Waffen-Pickup berechnet ihn nicht neu.
- **Zusätzliche Zange:** Soldier, Field Ops und Covert Ops können damit ausschließlich scharfes Dynamit und scharfe beziehungsweise bereits ausgelöste Landminen entschärfen. Kein Bauen, Reparieren, Scharfmachen oder Entschärfen von Satchels. Bau-/Reparaturhinweise erscheinen nur beim Engineer. Durch Entschärfen erhalten andere Klassen keine Landminen zum Legen. Medics erhalten keine Zange und können damit weder Dynamit noch Minen entschärfen.
- **Entschärfungsdauer:** Soldier, Field Ops und Covert Ops arbeiten bei gleichem Skill-Level halb so schnell und benötigen damit die doppelte Dauer für Dynamit und Landminen. Der gemeinsame Client-/Server-Code verwendet 100 ms statt 50 ms zwischen Zangenaktionen. Der Fortschritt pro Aktion und die jeweiligen Skill-Boni bleiben unverändert.
- **Engineer:** Behält seine normalen Fähigkeiten und seine unveränderte Geschwindigkeit beim Bauen, Reparieren, Scharfmachen und Entschärfen.
- **Fernglas:** Alle Klassen außer Medic erhalten es in beiden Teams bereits ab 0 XP und können damit gegnerische Minen mit dem normalen Covert-Ops-Mechanismus entdecken. Dadurch werden keine Artillerie- oder Verkleidungsfähigkeiten vergeben. Medics erhalten das Fernglas regulär ab Battle Sense Level 1, können damit aber keine Minen entdecken oder markieren. Ihre normale Trap Awareness auf Battle Sense Level 4 bleibt erhalten.
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
