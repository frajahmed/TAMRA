# TAMRA – Übergabe an Qwen (Neustart)

Stand: 28.10.2026. Dieses Dokument fasst den bisherigen Chat zwischen Ahmed (Product Owner)
und Claude zusammen. Ab jetzt gilt eine neue Rollenverteilung. Lies dieses Dokument komplett und
danach `QWEN.md` (verbindliche Code-Regeln).

---

## 1. Rollen ab jetzt

| Wer | Aufgabe |
| --- | --- |
| **Qwen** (Entwickler) | Schreibt den gesamten Code: API, App, Tests, Migrationen, Übersetzungen und Doku zum Ticket. Ein Ticket pro Chat. Hält sich strikt an `QWEN.md`. |
| **Claude** (Management + Test) | Schreibt und priorisiert Tickets, prüft jeden Pull Request (Review gegen `QWEN.md`), führt API-Tests lokal aus, liest die GitHub-CI-Ergebnisse, schreibt Fehlerberichte an Qwen und pflegt Status, CHANGELOG und ARCHITECTURE. Claude schreibt keinen Feature-Code mehr. |
| **Ahmed** (Product Owner) | Entscheidet fachlich, gibt Tickets an Qwen, überträgt Qwens Dateien nach GitHub (Branch + Pull Request) und merged, wenn Claude „OK“ gibt. |

---

## 2. Was TAMRA ist

Eine Ernährungs- und Fitness-App wie YAZIO: Tagebuch mit Kalorien und Makros, Lebensmittelsuche
(Open Food Facts), Barcode-Scanner, Gewicht und Wasser, Sport (manuell und aus Apple Health /
Health Connect), Statistiken für 7 Tage, 4 Wochen und 12 Monate, sowie Offline-Betrieb.

- Repository: https://github.com/frajahmed/TAMRA (Branch `main`)
- Lokaler Ordner bei Ahmed: `C:\Users\ahmed\OneDrive\Desktop\mein Projekt\Tamra`
- Docker ist auf Ahmeds PC installiert. `1-github-hochladen.bat` lädt den lokalen Stand zu GitHub hoch, das Ergebnis steht in `1-github-log.txt`.
- Sprachen der App: Englisch, Deutsch, Französisch, Italienisch und Arabisch (rechts-nach-links).

### Feste Entscheidungen (nicht ändern ohne Ahmed)
1. **Diabetes-Modus gestrichen** (25.10.2026). KE/BE, Glukose und `carb_unit` wurden entfernt und dürfen nicht zurückkommen.
2. **Design „Braun + Blau“** (26.10.2026):
   - Dattelbraun `#7A4B2A` ist die Markenfarbe (Buttons, Logo, aktiver Tab).
   - Blau `#2563EB` ist die Fortschrittsfarbe (Kalorienbogen, Diagramme).
   - Hell- und Dunkelmodus nutzen Tokens in `app/lib/app/theme.dart`, siehe `docs/DESIGN.md`.
3. **Kalorienbilanz:**
   - Budget = Ziel + Sport, wenn „Sport anrechnen“ (`count_activity_kcal`) an ist.
   - Rest = Budget − Gegessen.
   - Schritte werden nur angezeigt, nie als kcal addiert.
   - Die Formel steht immer sichtbar unter dem Bogen.
4. **Positiv, nie bestrafend:**
   - Überschreiten wird ohne rote Alarmfarbe angezeigt.
   - Es gibt keine Gesundheitsversprechen.
   - Das Kalorienziel geht nie unter das sichere Minimum.
5. **Sicherheit:**
   - Passwörter werden mit Argon2id gehasht.
   - Login-Drosselung.
   - Schutz gegen Missbrauch der Gratis-Testphase.
   - DSGVO-Export und Kontolöschung.
   - Gesundheitsdaten werden nie geloggt.
6. **Offline (T-33):**
   - Es gibt kein drift/SQLite, sondern einen JSON-Datei-Cache plus eine Outbox (siehe Abschnitt 4).
   - Der Client erzeugt UUIDs für neue Einträge.

---

## 3. Stand der Tickets

Sprint 0–5 sind fertig: T-10 bis T-14, T-20 bis T-24, T-30 bis T-33, T-40 bis T-44 und T-50 bis T-54.
Die Details stehen in `docs/tickets/README.md` und `docs/tickets/sprint-*.md`.

**Achtung, noch nicht auf GitHub:**
- 8 Commits (bis `193bb06`) liegen nur auf Ahmeds PC und warten auf den Upload per Doppelklick auf `1-github-hochladen.bat`.
- Danach prüft die GitHub-CI erstmals T-32, T-50 bis T-54, T-33 und T-44 in der App.
- Erst wenn diese CI grün ist, beginnt neue Arbeit. Fehler daraus gibt Claude als „Fix-Ticket“ an Qwen.

Letzter CI-Stand:
- Grün bis `f03c45d`.
- `3cbaf80` (T-43): analyze grün, 4 Tests rot wegen der Bildschirmhöhe. Repariert in `193bb06` (`useTallView`), aber noch nicht auf GitHub geprüft.

### Offene Aufgaben (nicht Code)
- [ ] Upload der 8 Commits (Ahmed: Bat doppelklicken).
- [ ] GitHub Action „Bootstrap Flutter platforms“ einmal starten. Sie erzeugt `app/android` und `app/ios` mit allen Berechtigungen über `configure_platforms.py`.
- [ ] iOS: HealthKit-Capability in Xcode aktivieren (braucht Apple-Account, manuell).
- [ ] Store-Screenshots mit Ahmed (Texte stehen in `docs/store/listing.md`).

### Nächste Feature-Tickets (Vorschlag, Claude schreibt sie als Sprint 6 aus)
| Ticket | Inhalt | Hinweis |
| --- | --- | --- |
| T-63 | Streaks und Abzeichen | klein, guter Einstieg; nie für „weniger essen“ belohnen |
| T-61 | Fasten-Timer (16:8, 18:6, 5:2) im Kalorienbogen | Umschalter Budget ↔ Fasten |
| T-62 | Rezepte, Diät-Filter, Einkaufsliste | API + App |
| T-60 | KI-Foto-Scan einer Mahlzeit | eigene Einwilligung; Foto sofort löschen; Nährwerte aus unserer DB, nicht vom Modell |
| T-64 | Strava, Garmin, Fitbit, Polar direkt | serverseitig, Phase 3 |

Die Beschreibungen stehen in `docs/tickets/backlog.md`.

---

## 4. Technik in Kürze

### API (`api/`)
- Django 5.2, Django REST Framework, simplejwt (JWT) und drf-spectacular (OpenAPI in `docs/openapi.yaml`).
- Nur PostgreSQL. Docker: `api/docker-compose.yml`, Host-Port über `API_PORT` (Standard 8000; Ahmeds Port 8000 ist belegt, daher 8010).
- Apps:
  - `accounts`: User (E-Mail-Login, UUID), Registrierung, Export und Löschung in `data.py`.
  - `profiles`: Ziele, Einheiten, Sprache, `count_activity_kcal`.
  - `foods`: Volltextsuche, Barcode, Open-Food-Facts-Import.
  - `diary`: Einträge, Tageszusammenfassung, Kopieren.
  - `tracking`: Gewicht und Wasser.
  - `stats`: `/stats/summary/?group=day|week|month`, `/stats/day/`; Grenzen in `MAX_DAYS`.
  - `activity`: Sport, Schritte, Import idempotent per `source` + `external_id`.
  - `billing`, `core` (Basismodelle, `IsOwner`, Fehlerformat), `locale`.
- Bei gleichen Feldnamen für Enums wird `ENUM_NAME_OVERRIDES` in `config/settings/base.py` gepflegt, etwa für `source`.
- Qualität:
  - `ruff check` und `ruff format`; Docstrings Pflicht (D101–D103).
  - `makemigrations --check`.
  - Coverage ≥ 80 % (aktuell 99 %, 199+ Tests).

### App (`app/`)
- Flutter mit Riverpod 2 (ohne Codegenerierung), go_router und dio.
- Navigation: `StatefulShellRoute.indexedStack` mit `AppShell` und `NavDock`:
  - Tabs: Tagebuch, Statistik, (+ Mitte), Aktivität, Profil.
  - Weitere Routen: `/weight`, `/activity/add`, `/diary/entry` und die Food-Routen.
- Texte:
  - Stehen in `lib/l10n/translations.dart` (alle 5 Sprachen) mit Getter in `app_strings.dart`.
  - Übersetzungs-Getter brauchen keinen Doc-Kommentar.
- Farben nur über `AppColors.of(context)`.
- Diagramme sind selbst gezeichnet (`core/widgets/charts.dart`).
- Hilfsfunktionen: `core/json.dart` (jsonDouble, jsonInt, dateKey, parseAmount …) und `core/ids.dart` (`newUuid`).
- Offline:
  - `OfflineDiaryRepository` umhüllt die API.
  - Tage werden in `FileLocalStore` gecacht.
  - Änderungen offline landen in der `Outbox` und werden später über die normalen Endpunkte abgespielt.
  - Ein 400 „id already used“ oder ein 404 gilt als erledigt.
  - Logout und Kontolöschung leeren den Speicher.
- Health:
  - Interface `HealthSource`; nur `DeviceHealthSource` nutzt das Paket `health`.
  - `HealthSync`: Der erste Sync holt 30 Tage, danach nur seit dem letzten Sync, in Seiten zu je 500.
  - `HealthAutoSync` läuft beim App-Start.
- Löschen im Tagebuch: Ein Timer (4 s, `undoDuration`) entscheidet, nicht die SnackBar. Ausstehende Löschungen werden bei `dispose` ausgeführt.
- Tests:
  - `test/helpers/fakes.dart` enthält Fakes für alle Repositories, dazu `testApp(...)` und `useTallView(tester)`.
  - Lange Listen in Tests immer mit `useTallView`.

### CI (`.github/`)
- Workflow `api.yml`: ruff, Migrationen, Tests mit Coverage, OpenAPI.
- Workflow `app.yml`:
  - Prüft Doc-Kommentare (`scripts/check_dart_docs.py`), `flutter analyze` und `flutter test`.
  - `scripts/annotate_flutter.py` meldet jeden roten Test einzeln.
  - `dart format` blockiert nicht.
- `bootstrap-flutter.yml` erzeugt android/ios.

---

## 5. Bekannte Stolperfallen (aus dem bisherigen Chat)

| Problem | Regel |
| --- | --- |
| `<` oder `>` in `///`-Kommentaren bricht `flutter analyze` | Typen in Backticks schreiben: `` `List<int>` `` |
| Zwei `pumpWidget` in einem Test (z. B. Sprachwechsel) | In zwei Tests aufteilen |
| SnackBar mit Aktion schließt sich nicht von selbst | Timer verwenden, nicht `closed` |
| Tests finden Widgets unten in langen Listen nicht | `useTallView(tester)` und `ensureVisible` |
| `as List` / `as Map` aus JSON | Typisiert casten oder `core/json.dart` verwenden |
| Konstruktor mit `assert` auf Listen als `const` | Kein `assert` mit Laufzeitwerten in const-Konstruktoren |
| Datumsformat | `intl` / `MaterialLocalizations`, nie selbst bauen |
| Zwei Serializer-Felder `source` mit verschiedenen Choices | Eintrag in `ENUM_NAME_OVERRIDES` |
| Qwen T-40 hatte Fehler: Gewicht per PATCH auf belegten Tag, Profilgewicht nicht synchron | `validate_date` + `services.sync_profile_weight` als Vorbild |
| Docker-Port 8000 belegt | `API_PORT=8010` |

---

## 6. Ablauf pro Ticket (neu)

1. **Claude** schreibt das Ticket mit Ziel, Akzeptanzkriterien, „Files to read“, „Files to create/change“ und den Tests.
2. **Ahmed** öffnet einen neuen Qwen-Chat und gibt Qwen diese Übergabe-Datei, `QWEN.md`, das Ticket und die Dateien aus „Files to read“.
3. **Qwen** antwortet im Format aus `QWEN.md` §1:
   - jede Datei komplett mit Pfad;
   - am Ende „Commit message“, „How to test“ und „Questions“.
4. **Ahmed** legt einen Branch `feat/T-xx-name` an, überträgt die Dateien und öffnet einen Pull Request.
5. **Claude** prüft:
   - Review gegen `QWEN.md`;
   - API-Tests lokal;
   - CI-Annotationen auf GitHub.
   
   Ergebnis ist entweder „OK zum Mergen“ oder ein Fehlerbericht mit genauen Dateien und Zeilen.
6. Bei einem Fehlerbericht gibt **Ahmed** ihn an Qwen („Behebe nur diese Fehler, gib die geänderten Dateien vollständig aus“). Danach geht es weiter bei Schritt 5.
7. Ist alles grün, merged **Ahmed**, und **Claude** aktualisiert Status, CHANGELOG und ARCHITECTURE.

### Start-Prompt für Qwen (in jeden neuen Chat kopieren)
```
Du bist der Entwickler von TAMRA. Lies zuerst die Übergabe (QWEN-UEBERGABE.md) und die
Regeln (QWEN.md). Halte dich strikt daran. Setze genau EIN Ticket um. Ändere nur die Dateien
unter "Files to create/change". Gib jede Datei vollständig mit Pfad aus, schreibe Tests,
und erfinde keine Ergebnisse – Unsicherheiten gehören unter "Questions".
Claude prüft deinen Code danach.

=== QWEN-UEBERGABE.md ===
<Inhalt>

=== QWEN.md ===
<Inhalt>

=== Ticket ===
<Ticket-Text>

=== Dateien zum Lesen ===
### <Pfad>
<Inhalt>
```

---

## 7. Verlauf des bisherigen Chats (Kurzfassung)

1. **Sprint 0:**
   - Repo, Django-API, Flutter-App, CI und Docker aufgesetzt.
   - Regeln für Qwen in `QWEN.md`, Anleitung in `docs/ANLEITUNG-QWEN.md`.
2. **Sprint 1:** Registrierung, Profil mit Kalorienziel, Einwilligungen, Login und Onboarding in der App.
3. **Sprint 2:**
   - Lebensmittel und Open Food Facts; Qwen hat Entwürfe geliefert, Claude hat sie überarbeitet.
   - Suche und Barcode in der App.
4. **Sicherheit:** Argon2id, Login-Drosselung, Testphasen-Missbrauchsschutz, DSGVO-Export und Löschung.
5. **Sprint 3:** Tagebuch-API und -Screen, Kopieren von Tag oder Mahlzeit, Offline mit Outbox.
6. **Diabetes-Modus entfernt;** Doc-Kommentare überall, per CI erzwungen; Wunsch „OOP, kommentiert, sauber“ umgesetzt (`QWEN.md` §5).
7. **Sprint 4:**
   - Gewicht und Wasser: von Qwen geschrieben, von Claude korrigiert.
   - Navigation-Dock, Statistik, Profil mit Einstellungen, Barrierefreiheit (Kontrast, Screenreader, 200 % Text) und Store-Texte.
8. **Designkonzept** von Ahmed übernommen; Farbwahl „Braun + Blau“.
9. **Sprint 5 (Wunsch Ahmed: Sport-Apps verbinden, Kalorien mit Essen verrechnen, Verlauf):**
   - Sport-API mit Import und Bilanz.
   - Sport-Screens, Apple Health und Health Connect, Bilanz-Dashboard mit 7 Tagen, 4 Wochen und 12 Monaten.
10. **28.10.2026:** Neustart der Zusammenarbeit. Qwen programmiert, Claude managt und testet.

Nicht verwendet: Dateien zu „Hey NORA“ (`01_STATUS_UND_ENTSCHEIDUNGEN.md` und `12_ROLLEN_UND_RECHTE_ENTWURF.md`) gehören zu einem anderen Projekt.
