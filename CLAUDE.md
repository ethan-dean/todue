# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Todue is a multi-platform todo list application with recurring tasks, real-time sync, and offline support.

- **Backend**: Java Spring Boot 3.5.7 with MySQL
- **Web**: React 19.1.1 + TypeScript + Vite
- **Mobile**: Flutter (iOS/Android)

**Status**: Core development complete (Phases 1-19). Currently in Testing & Deployment phase. See `todo-human.md` for remaining manual tasks.

## Development Commands

### Backend (Spring Boot)
```bash
cd backend/todue
./mvnw spring-boot:run                              # Run dev server (port 8080)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev  # Run with dev profile
./mvnw test                                         # Run all tests
./mvnw test -Dtest=UserServiceTest                  # Run specific test class
./mvnw clean package                                # Build JAR
```

### Web (React + Vite)
```bash
cd web
npm install                    # Install dependencies
npm run dev                    # Dev server (port 5173)
npm run build                  # Production build
npm run lint                   # ESLint
```

### Mobile (Flutter)
```bash
cd mobile
flutter pub get                # Get dependencies
flutter run -d ios             # Run on iOS
flutter run -d android         # Run on Android
flutter test                   # Run tests
flutter analyze                # Static analysis
flutter build apk              # Build Android APK
flutter build ios              # Build iOS
```

## Architecture

### Virtual Todo System

The core concept is **virtual todos** - recurring task instances generated dynamically:

1. **Recurring patterns** are stored in `recurring_todos` table with pattern type (DAILY, WEEKLY, BIWEEKLY, MONTHLY, YEARLY)
2. **Virtual todos** exist only in memory for current/future dates - generated on-the-fly when querying
3. **Materialization** occurs when user interacts with a virtual (complete, edit, reorder, or during rollover)
4. **Past dates** only show materialized (real) todos, not virtuals

Key files:
- `backend/todue/src/main/java/com/example/todue/service/TodoService.java` - Virtual generation and materialization
- `backend/todue/src/main/java/com/example/todue/util/RecurrenceCalculator.java` - Pattern calculation
- `backend/todue/src/main/java/com/example/todue/util/RecurrenceParser.java` - Text pattern parsing

### Rollover Logic

Incomplete todos automatically move to current date:

1. Triggers when user views current date AND `last_rollover_date` != current date
2. Materializes max 1 past virtual instance (oldest first)
3. Rolls forward existing incomplete real todos
4. Sets `is_rolled_over=true` and very negative positions (-1000, -999...) to appear at top

Key file: `backend/todue/src/main/java/com/example/todue/service/RolloverService.java`

### Two Critical Date Fields

Todos have two date fields - understanding this is essential:
- `assigned_date`: Current date the todo appears on (changes during rollover)
- `instance_date`: Original occurrence date (NEVER changes - preserves which recurring instance this was)

### Position Management

- Integer position per (user_id, assigned_date)
- Lower position = higher in list
- Gap-based: 0, 10, 20, 30... allows insertion without updating other todos
- Rolled-over todos: -1000, -999, -998...
- Sort order: `position ASC`, `id ASC`

### Real-time Sync

WebSocket sends invalidation signals (not full data):
- `TODOS_CHANGED` with date → client refetches that date
- `RECURRING_CHANGED` → client refetches all visible dates

Key files:
- `backend/todue/src/main/java/com/example/todue/service/WebSocketService.java`
- `web/src/services/websocketService.ts`
- `mobile/lib/services/websocket_service.dart`

### State Management

**Web**: React Context (not Redux)
- `TodoContext` (870 lines) - Todo operations, optimistic updates, WebSocket integration
- `AuthContext` - Authentication state

**Mobile**: Provider pattern
- `TodoProvider` (817 lines) - Offline-first with SQLite cache, prefetch window

### Offline Support (Mobile Only)

- SQLite cache via `sqflite`
- Prefetches 21-day window (7 past to 14 future)
- Stale-while-revalidate pattern
- Connectivity detection with `connectivity_plus`

## Database Schema

Five tables: `users`, `todos`, `recurring_todos`, `skip_recurring`, `password_reset_tokens`

Full schema in `requirements.md` lines 193-267.

## API Endpoints

```
POST   /api/auth/register, /api/auth/login, /api/auth/reset-password-request, /api/auth/reset-password
GET    /api/user/me, /api/user/current-date
PUT    /api/user/timezone
GET    /api/todos?date=2024-01-15
GET    /api/todos?start_date=2024-01-15&end_date=2024-01-21
POST   /api/todos
PUT    /api/todos/{id}/text, /api/todos/{id}/position, /api/todos/{id}/assigned-date
POST   /api/todos/{id}/complete
DELETE /api/todos/{id}?delete_all_future=true
/ws    - WebSocket endpoint
```

## Environment Configuration

### Backend
Copy `backend/todue/.env.example` to `.env`:
```
DB_HOST=localhost
DB_PORT=3306
DB_NAME=td_db
DB_USERNAME=td_user
DB_PASSWORD=your-password
JWT_SECRET=your-256-bit-secret
RESEND_API_KEY=your-resend-key
```

Profiles:
- `dev`: `ddl-auto=update`, DEBUG logging
- `prod`: `ddl-auto=validate`, WARN logging, optimized connection pool

### Web
Create `web/.env`:
```
VITE_API_URL=http://localhost:8080
```

### Mobile
API URL configured in `mobile/lib/services/api_service.dart`

## Key Implementation Details

### Recurrence Pattern Parsing

Text patterns detected at end of todo text:
- "every day" → DAILY
- "every week" → WEEKLY
- "every other week" → BIWEEKLY
- "every month" → MONTHLY
- "every year" → YEARLY

Backend strips pattern before storing (e.g., "mow lawn every week" → "mow lawn").

### Orphaning on Edit

When user edits a recurring todo instance:
1. Add entry to `skip_recurring` for that instance_date
2. Set `recurring_todo_id=NULL` on the todo (orphan it)
3. The recurring pattern continues generating new virtuals

### Deleting Recurring Todos

- **Delete single instance**: Add to `skip_recurring`
- **Delete all future**: Set `end_date` on `recurring_todos`, hard delete future incomplete instances

### Timezone Handling

- All dates stored as MySQL DATE type
- User timezone in profile (default 'UTC')
- "Current date" = current date in user's timezone
- `GET /api/user/current-date` returns server's view of user's current date

## Testing

Manual testing completed for most features. Automated test suite pending (Phase 20 in `todo-human.md`).

To test locally:
1. Start backend: `cd backend/todue && ./mvnw spring-boot:run`
2. Start web: `cd web && npm run dev`
3. Register user, create todos, test recurring patterns

## Deployment

Production deployment uses systemd service. See:
- `backend/todue/deploy.sh` - Deployment script
- `backend/todue/todue.service` - systemd unit file
- `todo-human.md` Phase 21 - Full deployment checklist

Low-memory configuration (for VPS with ~400MB available):
- 5 DB connections
- 20 Tomcat threads
- Java heap limits configured in service file

## Important Files

- `requirements.md` - Complete technical specification (504 lines)
- `todo-human.md` - Remaining manual tasks (testing, deployment, launch)
- `backend/todue/.env.example` - Required environment variables
