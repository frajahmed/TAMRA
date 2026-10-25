# Changelog

Alle wichtigen Änderungen an TAMRA. Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [Unreleased]

### Changed
- Diabetes-Modus aus der Planung gestrichen (Entscheidung 25.10.2026).
- Mindestlänge für Passwörter von 8 auf 10 Zeichen (API und App).
- API braucht jetzt PostgreSQL (lokal über `docker compose up`); SQLite wird nicht mehr unterstützt.

### Added
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
