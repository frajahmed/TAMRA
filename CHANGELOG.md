# Changelog

Alle wichtigen Änderungen an TAMRA. Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [Unreleased]

### Added
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
