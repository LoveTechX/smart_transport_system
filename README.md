# Smart Transport System

AI-enabled public transport tracking and operations platform built with Flutter and Firebase.

## Overview

Smart Transport System is a multi-role mobility application for:
- passengers (live tracking, ETA, tickets, alerts)
- drivers (trip controls, route status, safety)
- conductors (ticket verification and reporting)
- admin/control teams (route, schedule, fleet, emergency monitoring)

The app combines real-time map tracking, operational dashboards, and AI-assisted transport intelligence in one product.

## Core Highlights

- Real-time bus tracking with map-based route and stop visibility
- AI ETA prediction and predictive delay detection
- Smart route optimization including reinforcement-style route selection
- Crowd/occupancy estimation and seat availability logic
- Weather-aware travel delay estimation
- Driver safety/risk monitoring signals
- Fleet-level performance snapshot and smart passenger alerts
- Role-based feature flow (Passenger, Driver, Conductor, Admin)
- Firebase integration for app platform services
- Screen security support on Android (`FLAG_SECURE`)

## AI Features Included

### Essential AI Models (Product-Level Simulation APIs)

- LSTM / Bi-LSTM style ETA forecasting
- XGBoost-style travel time prediction
- Reinforcement learning style route optimization
- Computer vision style occupancy/crowd/safety signal analysis
- Graph neural network style network flow prediction

### Essential Transport AI Capabilities

- Real-time vehicle tracking
- AI ETA prediction
- Predictive delay detection
- Passenger crowd prediction
- Smart route optimization
- Safety monitoring
- Fleet management insights
- Smart passenger notifications
- Bus occupancy intelligence
- Weather-aware delay prediction

## Role-Based Modules

### Passenger

- Track bus on map
- View routes and schedule
- Ticket generation and ticket history
- Alerts and AI feature dashboard
- Profile and support/chat interfaces

### Driver

- Duty start/stop workflow
- Location sharing and route context
- Passenger count and status updates
- Route change notifications
- Smart safety/crowd insights

### Conductor

- QR ticket verification
- Ticket generation flow
- Seat management and ticket reports
- Passenger/ticket history view

### Admin / Control

- Route and schedule management
- Delay and notification monitoring
- Emergency control toggles
- Report and statistics summary
- Fleet health visibility

## Technology Stack

- Flutter (Material 3)
- Dart
- Firebase Core / Auth / Firestore / Storage
- Google Maps Flutter
- Geolocator
- Flutter Map (OSM-based views)
- ML Kit Face Detection (planned/extended security flows)

## Project Structure (Key Paths)

- `lib/main.dart` — app bootstrapping, theme, routes
- `lib/services/smart_transport_ai_service.dart` — AI logic + transport intelligence service layer
- `lib/screens/passenger/` — passenger feature screens
- `lib/screens/admin/` — admin/control dashboards
- `lib/screens/driver_screen.dart` — driver operations
- `lib/screens/conductor_screen.dart` — conductor operations

## Run Locally

### Prerequisites

- Flutter SDK (stable)
- Dart SDK (compatible with project constraints)
- Firebase project setup for your target platforms
- Android Studio / VS Code with Flutter & Dart extensions

### Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Ensure Firebase configuration files are present:
   - `android/app/google-services.json`
   - iOS/macOS configs where applicable
4. Run the app:
   ```bash
   flutter run
   ```

## Security Notes

- Android screen protection is enabled via `flutter_windowmanager` (`FLAG_SECURE`)
- Authentication and security policies are enforced in app-level auth/service flows
- Role-based navigation separates user operational surfaces

## Current Status

This project is under active development and includes production-style UI/UX for major workflows. Some AI features are currently implemented as deterministic/simulated model services intended to be replaced with backend ML inference pipelines for production deployments.

## Next Recommended Enhancements

- Connect AI inference to cloud-hosted model endpoints
- Add real IoT/AIS-140 ingestion pipeline
- Enable full real-time Firestore sync for fleet telemetry
- Add automated tests for service-level AI outputs and role workflows
- Add CI/CD and environment-based configuration management

## Repository Notes

- Workspace folder: `smart_transport_system`
- Flutter package name in `pubspec.yaml`: `bus_tracking_system`

---

For collaboration, feature requests, or deployment assistance, open an issue or create a feature branch and submit a pull request.
