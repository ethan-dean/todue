# GEMINI.md

## Project Overview

**Todue** is a multi-platform todo list application designed for low-friction task management. It features a unique recurring task system (text-based patterns), smart rollover of incomplete tasks, and real-time synchronization across devices.

The project is a **monorepo** containing:
*   **Backend:** Java Spring Boot 3.5.7 application.
*   **Web:** React 19.1.1 + TypeScript frontend.
*   **Mobile:** Flutter application for iOS and Android.

**Current Status:** **Feature Complete**. All core development phases (1-19) are marked as done. The project is currently in the **Testing & Deployment** phase.

## Architecture & Key Concepts

### Tech Stack
*   **Backend:** Java 21, Spring Boot, MySQL, Spring Security (JWT), WebSocket.
*   **Web:** React, Vite, TypeScript.
*   **Mobile:** Flutter, SQLite (offline support).

### Core Mechanics (Implemented)
*   **Virtual Todos:** Future recurring instances are generated on-the-fly and only materialized into the database when interacted with.
*   **Rollover:** Incomplete tasks automatically move to the current date.
    *   Past recurring instances are materialized (limit 1).
    *   Existing incomplete todos are rolled forward.
    *   Rolled items get negative positions to appear at the top.
*   **Recurrence:** Text-based parsing (e.g., "every day", "every 2 weeks").
*   **Sync:** Real-time via WebSockets. "Dirty state" signals cause clients to refetch specific dates.

## Building and Running

### Backend (`backend/todue`)
*   **Build:** `./mvnw clean package`
*   **Run:** `./mvnw spring-boot:run`
*   **Test:** `./mvnw test`
*   **Setup:** Requires MySQL database. Copy `.env.example` to `.env` and configure DB credentials.

### Web (`web`)
*   **Install:** `npm install`
*   **Run Dev:** `npm run dev` (http://localhost:5173)
*   **Build:** `npm run build`
*   **Lint:** `npm run lint`

### Mobile (`mobile`)
*   **Get Deps:** `flutter pub get`
*   **Run iOS:** `flutter run -d ios`
*   **Run Android:** `flutter run -d android`
*   **Test:** `flutter test`

## Key Documentation Files

*   **`requirements.md`**: The source of truth for all features, database schema, and logic.
*   **`todo.md`**: A detailed 23-phase implementation plan. Phases 1-19 are complete.
*   **`todo-human.md`**: Tracks remaining manual tasks, testing, and deployment steps.
*   **`CLAUDE.md`**: Developer guidance and command references.
*   **`README.md`**: High-level project summary and setup guide.

## Development Conventions

*   **Database:** Use `snake_case` for table/column names.
*   **API:** RESTful endpoints with JSON. Dates are `YYYY-MM-DD`.
*   **Timezones:** All dates stored as simple `DATE`. Calculations happen in the user's timezone (stored in `users` table).
*   **Testing:** Plan includes JUnit/MockMvc (Backend), Jest (Web), and Flutter Test.

## Next Steps (Testing & Deployment)
1.  **Phase 20 (Testing):** Execute comprehensive unit and integration tests for Backend, Web, and Mobile.
2.  **Phase 21 (Deployment):** Provision VPS, configure production Database, deploy Backend JAR, and build/deploy Web and Mobile apps.
3.  **Phase 22 (Launch):** Final security review, soft launch, and public release.
