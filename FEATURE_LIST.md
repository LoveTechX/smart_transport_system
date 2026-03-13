# Smart Transport System Feature List

Project analysis date: March 13, 2026

This document lists the features currently present in the Flutter project based on the implemented screens, services, and app flow.

## 1. Core App Structure

- Splash screen with branded app launch flow.
- Role-based entry point for Passenger, Driver, Conductor, and Admin users.
- Separate dashboards and workflows for each role.
- Material 3 themed UI with a consistent dark transport-operations design.
- Android screen-capture protection using `FLAG_SECURE`.
- Firebase initialization for platform services.

## 2. Authentication And Security

- Passenger sign up and login using Firebase Authentication.
- Driver login using Firebase Authentication.
- Conductor login using Firebase Authentication.
- Email normalization and validation before authentication.
- Password normalization and password policy enforcement.
- Login attempt throttling and temporary lockout after repeated failures.
- Role-specific login flows.
- Admin dashboard entry from the role-selection screen.

## 3. Passenger Features

- Passenger command center dashboard.
- Multi-language preference selector with English, Hindi, and Punjabi.
- Live bus tracking entry point.
- Route and stop browsing entry point.
- Schedule viewing entry point.
- QR ticketing entry point.
- Real-time alerts entry point.
- AI features entry point.
- My Tickets entry point.
- Travel history entry point.
- Profile entry point.
- Help center entry point.
- AI chatbot access from the passenger dashboard.
- Passenger SOS button for emergency escalation.
- Quick call actions for Police and Ambulance.

## 4. Passenger Live Tracking

- Google Maps-based bus tracking screen.
- Route-specific tracking from the route list.
- Current user location lookup with GPS fallback handling.
- Bus stop markers for start, intermediate stops, and destination.
- Route polyline rendering on the map.
- Simulated live bus movement across route stops.
- Multiple map modes: Normal, Satellite, Hybrid, and Terrain.
- Camera controls for tilt, bearing, and zoom.
- Route information panel showing distance, duration, fare, operator, and bus type.
- Route stop list with tap-to-focus map navigation.
- Auto-fit route bounds when the map loads.

## 5. Passenger Route Discovery

- Route list screen for all bus routes.
- Search by route number, route name, source, and destination.
- Filter by operator.
- Filter by bus type.
- View route status as Active or Inactive.
- View route summary details including distance, time, and fare.
- Tap any route to open live tracking for that route.
- Large built-in route catalog with route metadata and stop lists.

## 6. Passenger Ticketing And Travel Tools

- QR ticket generation.
- Passenger name input during ticket generation.
- Route selection during ticket creation.
- Seat number selection during ticket creation.
- Ticket ID / QR payload generation.
- Smart seat availability display.
- Occupied seat count and available seat count.
- Crowd-level indicator based on seat occupancy.
- AI crowd warning when occupancy crosses the crowded threshold.

## 7. Passenger Alerts, AI Tools, And Support

- Real-time notification feed for arrivals, delays, route changes, and safety notices.
- AI ETA prediction based on route, traffic, and historical delays.
- LSTM / Bi-LSTM style ETA prediction simulation.
- XGBoost-style travel time prediction simulation.
- Smart route optimization.
- Reinforcement learning style route optimization.
- Predictive delay detection.
- Weather-aware delay prediction.
- Computer vision style occupancy and safety analysis.
- GNN-style network flow prediction.
- Driver safety and risk scoring display.
- Fleet management snapshot.
- Smart passenger alert bundle generation.
- Nearest bus stop detection.
- Voice assistant simulation for arrival, seat, route, and SOS queries.
- Offline mode toggle for cached route/stop mode.
- Passenger feedback submission.
- Feedback analytics summary with rating average and sentiment counts.
- Technology stack checklist display.
- Reference transit app comparison display.

## 8. Driver Features

- Driver command center dashboard.
- Live map overview using OpenStreetMap via Flutter Map.
- Start trip control.
- Stop trip control.
- Driver location sharing into the service layer.
- Route assignment selection.
- Bus status update flow with Running, Delayed, and Stopped states.
- Route-change notification publishing.
- Passenger count monitoring via slider.
- Fatigue detection using driving time, eye-closure score, and steering variation.
- Safety monitoring panel for driver wellness indicators.
- Capacity and occupancy panel.
- Seat availability insight for the current route.
- AI fastest-route recommendation.
- Traffic load simulation control.
- Trip history log for duty start/stop events.
- Help shortcut from the driver dashboard.
- AI assistant shortcut from the driver dashboard.
- Driver SOS emergency action.
- Responsive dashboard layout with side rail on large screens and drawer/top selector on smaller screens.

## 9. Conductor Features

- Conductor command center dashboard.
- QR ticket verification.
- Manual ticket ID entry / scan simulation.
- Walk-in passenger ticket generation.
- Route selection for conductor operations.
- Verification result display.
- Voice assistant command support.
- Seat occupancy control.
- Mark seat as occupied.
- Mark seat as available.
- Live occupied and available seat counters.
- Trip ticket report with ticket count, unique seats, and estimated revenue.
- Passenger ticket list for the current route.
- Ticket history tracking view.
- Crowd percentage display.
- Overcrowding alert state.
- AI crowd and safety vision panel with standing-passenger and accident-risk indicators.
- Conductor SOS emergency action.
- Responsive dashboard layout matching the driver/admin panel style.

## 10. Admin / Control Center Features

- Admin command center dashboard.
- Overview panel with total buses, active routes, average rating, and feedback count.
- Passenger-view shortcut from the control room.
- AI assistant shortcut from the control room.
- Top-routes operational snapshot.
- Fleet AI snapshot with route efficiency, delays, and average driver score.
- Route management with add/remove route entries.
- Reinforcement learning based route re-assignment recommendation.
- Driver monitoring panel with status and fatigue labels.
- Schedule management with add-schedule flow.
- Passenger demand forecasting.
- Live alerts panel using the notification feed.
- Emergency alert toggle.
- Report and statistics generation dialog.
- Smart passenger broadcast bundle generation for a selected route.
- Route-change inclusion toggle in the broadcast flow.
- Admin SOS / control-room emergency action.
- Responsive dashboard layout with side rail and compact navigation modes.

## 11. AI Assistant And Help Features

- In-app AI chatbot screen.
- Quick-action chips for common help topics.
- Auto-detection of user language style.
- Chatbot replies in English, Hindi/Hinglish, and Punjabi.
- Manual language switching inside chatbot.
- App overview guidance from the chatbot.
- Role-specific guidance for Passenger, Driver, Conductor, and Admin.
- Route lookup through chatbot by bus number or source/destination keywords.
- Ticket, fare, tracking, ETA, emergency, login, and AI-feature help responses.
- Full-app guide response summarizing major workflows.
- AI Help Center screen for typed issue analysis.
- Rule-based troubleshooting for map, login, and tracking issues.
- Fallback option to call a support agent when AI cannot resolve the issue.

## 12. Data And Operational Logic

- Route repository with rich route metadata.
- Route stop model with sequence number, location, landmark, and ETA values.
- Ticket storage and retrieval in the service layer.
- Seat occupancy tracking per bus/route.
- Live bus-location storage in the service layer.
- Trip history logging.
- Feedback storage and analytics.
- Notification generation and notification feed timer.
- Emergency payload generation including role, bus, timestamp, and coordinates.

## 13. Additional Implemented Or Partial Features

- Alternate passenger map screen that reads live bus coordinates from Firestore.
- Static schedule screen with sample bus timings.
- Basic My Tickets screen shell.
- Basic Travel History screen shell.
- Basic Passenger Profile screen shell.
- Basic generic login screen file exists but is not part of the main app flow.

## 14. Current Feature Maturity Notes

- Several AI capabilities are implemented as deterministic or simulated service logic inside the app, not as real backend ML inference.
- Some passenger screens are present as placeholders or minimal screens rather than fully developed production workflows.
- The alternate Firestore-based passenger map screen exists in the codebase but is not wired into the main route table from `main.dart`.

## 15. High-Level Summary For Team Sharing

The app is a multi-role smart transport platform with passenger tracking and ticketing, driver operations, conductor ticket and seat control, admin fleet oversight, emergency actions, real-time alerts, and a broad set of simulated AI transport features such as ETA prediction, delay detection, route optimization, crowd analytics, demand forecasting, and multilingual chatbot support.