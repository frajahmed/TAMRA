# Anleitung: So arbeitest du mit Qwen an TAMRA

Diese Anleitung ist für dich (Product Owner). Qwen schreibt nur Code; du überträgst ihn
nach GitHub; GitHub prüft automatisch; Claude kontrolliert am Sprint-Ende.

## Einmalig vorbereiten

1. **Android/iOS-Ordner erzeugen:** GitHub → Repository `TAMRA` → Tab **Actions** →
   „Bootstrap Flutter platforms“ → **Run workflow**. Dauert ca. 5 Minuten.
   Danach gibt es `app/android` und `app/ios`.
2. **Schreibrechte für Actions:** Settings → Actions → General → Workflow permissions →
   „Read and write permissions“ → Save (nötig für Schritt 1).
3. **`main` schützen:** Settings → Branches → Add rule → Branch name `main` →
   „Require a pull request before merging“ und „Require status checks to pass“
   (Checks `API / test` und `App / test` auswählen, sobald sie einmal gelaufen sind).

## Ablauf für jedes Ticket

1. **Ticket wählen:** das nächste offene Ticket in `docs/tickets/` (der Reihe nach).
2. **Prompt an Qwen** (neuer Chat pro Ticket, damit Qwen nichts verwechselt):

   ```
   Du bist der Entwickler von TAMRA. Halte dich strikt an QWEN.md.
   Setze genau dieses Ticket um und gib jede Datei vollständig mit Pfad aus.

   === QWEN.md ===
   <Inhalt von QWEN.md einfügen>

   === Ticket ===
   <Ticket-Text einfügen>

   === Dateien zum Lesen ===
   ### <Pfad>
   <Inhalt>
   ### <Pfad>
   <Inhalt>
   ```

   Die Dateien zum Lesen stehen im Ticket unter „Files to read“. Öffne sie auf GitHub,
   Button „Raw“ → alles kopieren.
3. **Branch anlegen:** auf GitHub oben links Branch-Auswahl → Namen eingeben,
   z. B. `feat/T-10-register` → „Create branch“.
4. **Dateien übertragen** (im neuen Branch!):
   - Neue Datei: „Add file“ → „Create new file“ → **im Namensfeld den vollen Pfad eintippen**,
     z. B. `api/accounts/serializers.py` (die Schrägstriche legen Ordner an) → Inhalt einfügen.
   - Bestehende Datei: Datei öffnen → Stift-Symbol → kompletten Inhalt ersetzen.
   - Commit-Nachricht von Qwen verwenden, „Commit directly to the `feat/...` branch“.
5. **Pull Request öffnen:** „Compare & pull request“ → Vorlage ausfüllen (Ticket-Nummer).
6. **Checks abwarten:** unten im Pull Request erscheinen „API / test“ und „App / test“.
   - Grün ✅ → „Merge pull request“.
   - Rot ❌ → auf „Details“ klicken, Fehlermeldung kopieren, an Qwen schicken:
     „Die Prüfung ist fehlgeschlagen. Behebe nur diesen Fehler und gib die geänderten Dateien
     vollständig aus: <Log>“. Dann die Dateien im selben Branch ersetzen.
   - Nach 3 erfolglosen Versuchen: Ticket-Nummer und Log an Claude geben.
7. **Häkchen setzen** im Ticket-Dokument (`docs/tickets/...`): `- [x]`.

## Sprint-Ende (alle 2 Wochen)

Schreib Claude: „Sprint X fertig, bitte prüfen.“ Claude liest die Änderungen seit dem letzten
Stand, prüft nach der Review-Checkliste und liefert Korrekturen gebündelt.

## Häufige Fehler

| Fehler | Lösung |
| --- | --- |
| Datei heißt „Create new file“ | Im Namensfeld den Pfad eintragen, nicht den Button-Text |
| Code direkt in `main` | Immer erst einen Branch anlegen |
| Qwen gibt nur Teile einer Datei aus | „Gib die komplette Datei aus, ohne Auslassungen.“ |
| Qwen ändert andere Dateien als im Ticket | Ablehnen, auf QWEN.md Abschnitt 1 verweisen |
| `ruff format` schlägt fehl | Qwen bitten, den Code nach ruff/black-Stil (Zeilenlänge 100) zu formatieren, oder Claude fragen |
| `dart format` schlägt fehl | Qwen bitten, `dart format`-Stil einzuhalten; im Notfall den Bootstrap-Workflow-Schritt „format“ lokal ausführen |
