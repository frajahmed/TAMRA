# Changelog

Alle wichtigen Änderungen an TAMRA. Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [Unreleased]

### Changed
- Reste des gestrichenen Diabetes-Modus entfernt: Profilfeld `carb_unit` (KE/BE, Migration
  `profiles 0002`), App-Umrechnungen `CarbUnits` und Blutzucker-Einheiten.
- Diabetes-Modus aus der Planung gestrichen (Entscheidung 25.10.2026).
- Mindestlänge für Passwörter von 8 auf 10 Zeichen (API und App).
- API braucht jetzt PostgreSQL (lokal über `docker compose up`); SQLite wird nicht mehr unterstützt.

### Added
- App: Apple Health / Health Connect verbinden (T-53): Trainings und Schritte der letzten 30 Tage,
  danach seit dem letzten Abgleich, beim App-Start automatisch und per „Jetzt abgleichen“; Import
  seitenweise (500), ohne Duplikate; Plattform-Berechtigungen per `configure_platforms.py`.
- App Sport (T-52, T-54): Aktivität-Tab mit Wochenleiste, Sport eintragen (kcal-Vorschlag aus
  MET × Gewicht × Zeit, änderbar), importierte Trainings nur löschbar; Tagebuch rechnet
  Ziel + Sport − Gegessen (Schalter im Profil); Statistik mit 7 Tagen / 4 Wochen / 12 Monaten und
  Sport als zweitem Balken; Hinweis im Onboarding „Alltag ohne Sport“.
- API Sport (T-50, T-51): Aktivitäten und Schritte (manuell und Import aus Gesundheits-Apps,
  ohne Duplikate, gelöschte Importe bleiben gelöscht), Tagesbilanz `GET /stats/day/`
  (Ziel + Sport − Gegessen), Verlauf nach Tag/Woche/Monat (`group=`), Schalter
  `count_activity_kcal` im Profil; Tagebuch-Übersicht liefert Sport und Schritte mit.
- App: „Gestern kopieren“ im Tagebuch-Menü und „Von gestern kopieren“ bei leeren Mahlzeiten (T-32).
- App: Profil/Einstellungen (T-43): Tagesziel, Einheiten kg/lb und kcal/kJ, Sprache (bleibt nach
  Neustart), Daten-Export über das Teilen-Menü (`share_plus`), Einwilligung widerrufen, Abmelden,
  Konto löschen mit Passwort.
- App: Navigations-Dock (Tagebuch, Statistik, Plus-Knopf, Aktivität, Profil), Wasser-Karte im
  Tagebuch, Gewichtsverlauf mit Diagramm (kg/lb), Statistik der letzten 7 Tage (T-41, T-42 App).
  Diagramme selbst gezeichnet, ohne zusätzliches Paket.
- API: Statistik `GET /api/v1/stats/summary/?from=&to=` (T-42): Summen je Tag inkl. leerer Tage,
  Durchschnitt über Tage mit Einträgen, Wasser, Gewicht und Gewichtsveränderung, max. 31 Tage.
- App: Tagebuch als Startbildschirm (T-31): Wochenleiste, Kalorienbogen mit sichtbarer Formel,
  Makro-Balken, vier Mahlzeiten mit „+“, Eintrag hinzufügen/ändern mit Live-Vorschau,
  Wischen zum Löschen mit „Rückgängig“ (4 s), kcal oder kJ. API: Tagesübersicht liefert `energy_unit`.
- Design-System (`docs/DESIGN.md`) nach dem Konzept vom 26.10.: Farb-Tokens für Hell/Dunkel
  (`AppColors`: Dattelbraun als Marke, Blau für Fortschritt, feste Makro-Farben), Karten mit Rand,
  Komponenten-Plan (Kalorienbogen, Wochenleiste, Navigations-Dock mit Scan-Knopf), Backlog mit
  KI-Foto-Scan, Fasten, Rezepten und Serien (`docs/tickets/backlog.md`).
- Sauberer Code: jede öffentliche Klasse, Methode und Funktion hat einen Doc-Kommentar (API und App);
  CI prüft das automatisch (ruff D101–D103, `.github/scripts/check_dart_docs.py`); Regeln in `QWEN.md` §5.
- API: Gewicht und Wasser (T-40, Qwen; Review Claude): ein Gewicht pro Tag, Profilgewicht und
  Kalorienziel werden mitgeführt, Export und Konto-Löschung enthalten die neuen Daten.
- Planung Sprint 5 (`docs/tickets/sprint-5.md`): Sport und Schritte aus Apple Health / Health Connect
  (darüber Garmin, Fitbit, Polar, Samsung Health, Strava), manuelle Aktivitäten, Kalorienbilanz
  (Ziel + Sport – Gegessen) und Verlauf nach Tagen, Wochen und Monaten.
- App: Barcode-Scan (T-24) mit `mobile_scanner`: EAN-8/13 und UPC, gleicher Code nur einmal
  abgefragt, „nicht gefunden“ → eigenes Lebensmittel mit Barcode, Kamera verweigert → Einstellungen.
  Kamera-Berechtigung wird vom Workflow „Bootstrap Flutter platforms“ eingetragen.
- App: Lebensmittel-Suche (T-23) mit 400 ms Debounce, Leer- und Fehlerzustand, Formular
  „Eigenes Lebensmittel“ (Komma als Dezimalzeichen, kcal ≤ 900, Makros ≤ 100 g), Texte in 5 Sprachen.
- Sicherheit (Claude): Passwörter mit Argon2id (Salt pro Nutzer, automatisches Upgrade alter
  Hashes), Mindestlänge 10, Login-Begrenzung gegen Passwort-Raten, Schutz gegen
  Testabo-Missbrauch (HMAC-Hash von E-Mail und Gerät, überlebt Konto-Löschung), `docs/SECURITY.md`.
  131 Tests, 99 %.
- DSGVO (Claude): Datenexport als JSON inkl. gelöschter Einträge, Konto endgültig löschen mit
  Passwort, Sperren aller Tokens (T-43, API-Teil). 112 Tests, 99 %.
- Sprint 3 API (Claude): Tagebuch mit Nährwert-Snapshot pro Eintrag, Tageszusammenfassung
  mit Zielen, Mahlzeit/Tag kopieren, eigene IDs für Offline-Nutzung (T-30, T-32). 106 Tests, 99 %.
- Sprint 2 API (Claude, nach Prüfung eines Qwen-Entwurfs):
  - Lebensmittel-Modell mit Nährwerten pro 100 g, Volltext- und Teilwortsuche (PostgreSQL),
    Barcode-Abfrage mit Open Food Facts, eigene Lebensmittel, Import-Befehl für OFF-Dumps
    (T-20, T-21, T-22). 84 Tests gegen PostgreSQL, 98 % Abdeckung.
- Sprint 1 (Claude):
  - API: Registrierung, Profil mit Kalorien- und Makrozielen (gleiche Formel wie die App),
    Einwilligungen nach DSGVO Art. 9 (T-10, T-11, T-12), 43 Tests, 97 % Abdeckung.
  - App: Login, Registrierung, sichere Token-Speicherung mit automatischer Erneuerung,
    Weiterleitung je nach Status, Einwilligung, Onboarding mit Ergebnis (T-13, T-14), Tests.
- Sprint 0 (Fundament, von Claude erstellt):
  - `api/`: Django 5 + DRF, Settings für dev/test/prod, eigenes User-Modell (E-Mail-Login, UUID),
    Basis-Modelle mit UUID, Zeitstempeln und weichem Löschen, `IsOwner`-Permission,
    einheitliches Fehlerformat, Health-Endpoint, JWT-Login/Refresh/Logout, OpenAPI-Schema,
    Sentry-Filter für Gesundheitsdaten, Docker Compose (API, PostgreSQL, Redis, Celery), 15 Tests.
  - `app/`: Flutter-Grundgerüst mit Riverpod, go_router, 5 Sprachen inkl. RTL, Theme,
    API-Client mit Fehlerformat, Ernährungs-Rechenlogik (Nährwerte, Mifflin-St Jeor,
    KE/BE, Einheiten), Start- und Entwickler-Screen, Tests.
  - CI: Workflows für API und App, Secret-Scan, Bootstrap-Workflow für Android/iOS-Ordner.
  - Doku: `QWEN.md`, Architektur, Anleitung, Tickets für Phase 1.
