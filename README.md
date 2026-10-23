# TAMRA

TAMRA (arabisch تمرة, „die Dattel“) ist ein fairer Kalorien-, Makro- und Fasten-Tracker
für iOS und Android: Barcode-Scan und Fasten gratis, keine Werbung im Tagebuch,
5 Sprachen (DE, EN, FR, IT, AR mit Rechts-nach-links), Diabetes-Modus mit KE/BE-Zählung.

| Ordner | Inhalt |
| --- | --- |
| `app/` | Flutter-App (iOS + Android) |
| `api/` | Django REST API |
| `docs/` | Architektur, OpenAPI-Vertrag, Tickets, Anleitungen |
| `.github/` | CI-Workflows, Vorlagen für Tickets und Pull Requests |

## Schnellstart

API (braucht Docker):
```bash
cd api
cp .env.example .env
docker compose up --build
# http://localhost:8000/api/v1/health/  →  {"status": "ok"}
```

App (braucht Flutter):
```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Für Entwickler und den Coding-Agenten
1. `QWEN.md` lesen (Regeln).
2. `docs/ANLEITUNG-QWEN.md` (so läuft ein Ticket ab).
3. Tickets in `docs/tickets/`, der Reihe nach.
4. Architektur: `docs/ARCHITECTURE.md`.
