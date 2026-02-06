# Copilot Instructions for Todue

Todue is a multi-platform todo list application with a unique virtual todo system, text-based recurring patterns, and real-time sync.

**Monorepo structure:**
- `backend/todue/` - Java Spring Boot 3.5.7 API
- `web/` - React 19.1.1 + TypeScript + Vite
- `mobile/` - Flutter (iOS/Android)

**Current Status:** Feature complete (Phases 1-19). In testing & deployment phase.

## Build, Test, and Lint Commands

### Backend (Spring Boot)
```bash
cd backend/todue
./mvnw spring-boot:run                              # Dev server (port 8080)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev  # Run with dev profile
./mvnw test                                         # All tests
./mvnw test -Dtest=UserServiceTest                  # Single test class
./mvnw clean package                                # Build JAR
```

### Web (React + Vite)
```bash
cd web
npm run dev                    # Dev server (port 5173)
npm run build                  # Production build
npm run lint                   # ESLint
npm run lint:fix              # ESLint with autofix
npm run format                # Prettier format
npm run format:check          # Prettier check
```

### Mobile (Flutter)
```bash
cd mobile
flutter run -d ios             # Run on iOS
flutter run -d android         # Run on Android
flutter test                   # All tests
flutter test test/services/todo_provider_test.dart  # Single test file
flutter analyze                # Static analysis
flutter build apk              # Build Android APK
flutter build ios              # Build iOS
```

## High-Level Architecture

### Virtual Todo System (Core Concept)

**The most important architectural pattern:** Recurring task instances are generated dynamically, not stored in the database.

1. **Recurring patterns** stored in `recurring_todos` table (DAILY, WEEKLY, BIWEEKLY, MONTHLY, YEARLY)
2. **Virtual todos** generated on-the-fly for current/future dates - exist only in memory
3. **Materialization** happens when user interacts (complete, edit, reorder, or during rollover) - virtual becomes real database row
4. **Past dates** only show materialized todos, never virtuals

**Key implementation files:**
- `backend/todue/src/main/java/com/example/todue/service/TodoService.java` - Virtual generation & materialization logic
- `backend/todue/src/main/java/com/example/todue/util/RecurrenceCalculator.java` - Pattern date calculation
- `backend/todue/src/main/java/com/example/todue/util/RecurrenceParser.java` - Text pattern parsing ("every day" → DAILY)

### Two Critical Date Fields

Every todo has two date fields - **this distinction is essential:**
- `assigned_date` - Current date the todo appears on (changes during rollover)
- `instance_date` - Original occurrence date (NEVER changes - preserves which recurring instance this was)

### Rollover Logic

Incomplete todos automatically move to today when user views current date:

1. Triggers when `last_rollover_date` != current date
2. Materializes **max 1 past virtual** instance (oldest first, so recurring tasks don't flood today)
3. Rolls forward existing incomplete real todos
4. Sets `is_rolled_over=true` and assigns very negative positions (-1000, -999...) to appear at top

**Implementation:** `backend/todue/src/main/java/com/example/todue/service/RolloverService.java`

### Position Management

- Integer position per `(user_id, assigned_date)` tuple
- Lower position = higher in list
- **Gap-based numbering:** 0, 10, 20, 30... allows insertion without updating other todos
- Rolled-over todos: -1000, -999, -998... (top of list)
- Sort order: `ORDER BY position ASC, id ASC`

### Real-Time Sync via WebSocket

WebSocket sends **invalidation signals**, not full data:
- `TODOS_CHANGED` with date → client refetches that specific date
- `RECURRING_CHANGED` → client refetches all visible dates

**Why invalidation?** Avoids duplicating business logic (virtual generation, rollover) on server-side message construction.

**Key files:**
- `backend/todue/src/main/java/com/example/todue/service/WebSocketService.java`
- `web/src/services/websocketService.ts`
- `mobile/lib/services/websocket_service.dart`

### State Management

**Web (React):** Context API, not Redux
- `web/src/contexts/TodoContext.tsx` (870 lines) - Todo operations, optimistic updates, WebSocket integration
- `web/src/contexts/AuthContext.tsx` - Authentication state

**Mobile (Flutter):** Provider pattern
- `mobile/lib/providers/todo_provider.dart` (817 lines) - Offline-first with SQLite cache
- Prefetches 21-day window (7 past, 14 future)
- Stale-while-revalidate pattern

### Offline Support (Mobile Only)

- SQLite local cache via `sqflite` package
- Connectivity detection with `connectivity_plus`
- All reads serve from cache first, then background refresh
- Writes queue when offline, sync on reconnect

## Key Conventions

### Recurrence Pattern Parsing

Text patterns detected **at end of todo text:**
- "every day" → DAILY
- "every week" → WEEKLY  
- "every other week" → BIWEEKLY
- "every month" → MONTHLY
- "every year" → YEARLY

**Backend strips pattern before storing:** "mow lawn every week" → stored as "mow lawn"

### Orphaning on Edit

When user edits a recurring todo instance:
1. Add entry to `skip_recurring` for that `instance_date`
2. Set `recurring_todo_id=NULL` on the todo (orphan it from pattern)
3. Recurring pattern continues generating new virtuals for other dates

### Deleting Recurring Todos

- **Delete single instance:** Add to `skip_recurring` table
- **Delete all future:** Set `end_date` on `recurring_todos`, hard delete future incomplete instances

### Timezone Handling

- All dates stored as MySQL `DATE` type (no time component)
- User timezone in `users.timezone` (default 'UTC')
- "Current date" = current date in user's timezone
- Endpoint: `GET /api/user/current-date` returns server's view of user's current date

### Database Naming

- Use `snake_case` for all table and column names
- Five core tables: `users`, `todos`, `recurring_todos`, `skip_recurring`, `password_reset_tokens`

### API Date Format

- All dates use ISO format: `YYYY-MM-DD`
- Query params: `?date=2024-01-15` or `?start_date=2024-01-15&end_date=2024-01-21`

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
- `dev` - `ddl-auto=update`, DEBUG logging
- `prod` - `ddl-auto=validate`, WARN logging, optimized connection pool

### Web
Create `web/.env`:
```
VITE_API_URL=http://localhost:8080
```

### Mobile
API URL configured in `mobile/lib/services/api_service.dart`

## Key Documentation Files

- **`requirements.md`** - Complete technical specification (source of truth)
- **`todo.md`** - 23-phase implementation plan (Phases 1-19 complete)
- **`todo-human.md`** - Remaining manual tasks (testing, deployment)
- **`README.md`** - Setup guide
- **`CLAUDE.md`** - Additional developer guidance for Claude Code
- **`GEMINI.md`** - Additional developer guidance for Gemini

## Common Workflows

### Local Development Setup
```bash
# 1. Backend
cd backend/todue
cp .env.example .env  # Edit with your DB credentials
./mvnw spring-boot:run

# 2. Web (new terminal)
cd web
npm install
npm run dev

# 3. Mobile (new terminal)
cd mobile
flutter pub get
flutter run -d ios  # or -d android
```

### Testing Recurring Patterns Locally
1. Start backend and web
2. Register user, create todo: "Exercise every day"
3. Backend strips pattern → stores "Exercise"
4. Navigate to future dates → see virtual instances
5. Complete one → it materializes in DB
6. Edit one → it orphans from pattern
