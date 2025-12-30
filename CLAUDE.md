# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Todue is a multi-platform todo list application in **early development stage** (currently ~3% complete - only scaffolding exists). The project uses a monorepo structure with three main components:

- **Backend**: Java Spring Boot 3.5.7 with MySQL
- **Web**: React 19.1.1 + TypeScript + Vite
- **Mobile**: Flutter (iOS/Android)

**Important**: This codebase contains comprehensive requirements (requirements.md) and a detailed 23-phase implementation plan (todo.md), but minimal actual implementation. Only boilerplate code exists - all core features, API endpoints, database entities, and UI components need to be built.

## Repository Structure

```
/todue/
├── backend/todue/          # Spring Boot backend (Java 21)
├── web/                    # React + TypeScript frontend
├── mobile/                 # Flutter mobile app
├── requirements.md         # Complete technical specification (504 lines)
├── todo.md                 # 23-phase implementation plan (1,719 lines)
└── README.md               # Minimal project description
```

## Development Commands

### Backend (Spring Boot)

```bash
cd backend/todue

# Build the project
./mvnw clean package

# Run development server
./mvnw spring-boot:run

# Run with specific profile
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# Run tests
./mvnw test

# Run specific test class
./mvnw test -Dtest=UserServiceTest

# Clean build artifacts
./mvnw clean
```

**Current State**: Only `TodueApplication.java` exists (13 lines boilerplate). No entities, repositories, services, or controllers implemented yet.

### Web Frontend (React + Vite)

```bash
cd web

# Install dependencies
npm install

# Run development server (http://localhost:5173)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint
```

**Current State**: Default Vite + React counter demo. No custom components, routing, API integration, or authentication implemented yet.

### Mobile (Flutter)

```bash
cd mobile

# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on web browser
flutter run -d chrome

# Build for release
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web

# Run tests
flutter test

# Analyze code
flutter analyze
```

**Current State**: Default Flutter counter demo. No custom screens, API integration, state management, or offline support implemented yet.

## Architecture & Key Concepts

### Database Schema (Planned - Not Implemented)

The system uses **MySQL database** (`td-db`) with five tables:

1. **users** - User accounts with timezone support
2. **password_reset_tokens** - Password reset functionality
3. **recurring_todos** - Recurrence patterns (DAILY, WEEKLY, BIWEEKLY, MONTHLY, YEARLY)
4. **todos** - Materialized todo instances with two critical date fields:
   - `assigned_date`: Current date the todo appears on (changes during rollover)
   - `instance_date`: Original occurrence date (NEVER changes - preserves which instance this was)
5. **skip_recurring** - Tracks skipped instances of recurring todos

**Critical Design Patterns**:

- **Virtual Todos**: Backend dynamically generates todo instances from recurring patterns when querying. Virtual todos only exist in memory until interacted with (completed, edited, reordered).
- **Materialization**: Virtual todos become "real" (persisted) when user interacts with them OR during rollover.
- **Rollover Logic**: Incomplete todos automatically move to current date:
  1. Materialize up to 1 past virtual instance (oldest first)
  2. Roll forward existing incomplete real todos
  3. Both get `is_rolled_over=true` flag and very negative positions (-1000, -999, -998...) to appear at top

### Recurrence Pattern Parsing

Text-based patterns (no UI dropdowns):
- "every day" → DAILY
- "every week" → WEEKLY (same day of week from start_date)
- "every other week" → BIWEEKLY
- "every month" → MONTHLY (same day of month)
- "every year" → YEARLY

Backend strips pattern from text before storing (e.g., "mow lawn every week" → "mow lawn").

### Real-time Synchronization

- WebSocket endpoint `/ws` pushes invalidation signals to clients (no polling)
- Message types:
  - `TODOS_CHANGED` - Single date changed, includes date in payload → client refetches that date
  - `RECURRING_CHANGED` - Recurring pattern changed → client refetches all currently visible dates
- Each user subscribes to their own channel only (complete data isolation)
- "Dirty state" approach: server signals what changed, client refetches data (simpler and more robust than sending full data)

### Position Management

- Todos ordered by single integer position field per (user_id, assigned_date)
- Lower position = higher in list
- Sort order: `position ASC`, `id ASC` (simple!)
- **Position values**:
  - Materialized rolled-over virtuals: -1000 (oldest)
  - Rolled-over existing todos: -999, -998, -997... (sorted by original date)
  - Recurring todos (virtual & materialized): 0 (sort by recurring_todo ID for creation order)
  - Regular todos: 10, 20, 30, 40... (gaps allow easy insertion)
- When dragging todos, only the moved todo's position updates
- Negative positions naturally sort first, recurring todos (position=0) appear in middle

## API Endpoints (Planned - Not Implemented)

```
# Authentication
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/reset-password-request
POST   /api/auth/reset-password

# User
GET    /api/user/me
GET    /api/user/current-date        # Current date in user's timezone
PUT    /api/user/timezone

# Todos
GET    /api/todos?date=2024-01-15
GET    /api/todos?start_date=2024-01-15&end_date=2024-01-21
POST   /api/todos
PUT    /api/todos/{id}/text
PUT    /api/todos/{id}/position
POST   /api/todos/{id}/complete
DELETE /api/todos/{id}?delete_all_future=true

# WebSocket
/ws    - Real-time updates channel
```

## Environment Configuration

### Backend (.env file needed)

```bash
DB_HOST=mysql-host-address
DB_PORT=3306
DB_NAME=td_db
DB_USERNAME=td_user
DB_PASSWORD=td-password
JWT_SECRET=jwt-secret-key
```

Template available in `backend/todue/.env.example`. Note: `application.properties` currently only contains `spring.application.name=todue` - database config needs to be added.

### Web & Mobile

No environment configuration set up yet. Will need API endpoint URLs when backend is deployed.

## Key Dependencies

### Backend (pom.xml)
- Spring Boot 3.5.7 (Java 21)
- Spring Data JPA (database ORM)
- Spring Security (authentication)
- Spring WebSocket (real-time updates)
- MySQL Connector
- Lombok (code generation)
- **Missing**: JWT library (io.jsonwebtoken:jjwt) needs to be added

### Web (package.json)
- React 19.1.1
- Vite 7.1.7
- TypeScript 5.9.3
- **Missing**: React Router, Axios, WebSocket client, date-fns/day.js, React DnD, state management

### Mobile (pubspec.yaml)
- Flutter SDK ^3.9.2
- cupertino_icons ^1.0.8
- **Missing**: http/dio, web_socket_channel, provider/riverpod, shared_preferences, sqflite, intl

## Implementation Guidance

### Next Steps (from todo.md Phase 1-3)

1. **Complete Foundation Setup**:
   - Add JWT dependency to backend pom.xml
   - Configure application.properties with database connection
   - Set up environment variable loading in Spring Boot
   - Create proper folder structure in all three projects
   - Install missing dependencies

2. **Backend Database Layer** (Phase 2):
   - Create JPA entities: User, Todo, RecurringTodo, SkipRecurring, PasswordResetToken
   - Create repositories with custom query methods
   - Add proper indices and FK constraints
   - Configure Hibernate ddl-auto

3. **Backend Authentication** (Phase 3):
   - Implement JWT token generation/validation
   - Create Spring Security configuration
   - Build auth endpoints (register, login, password reset)
   - Add BCrypt password hashing

4. **Backend Todo CRUD** (Phase 4-6):
   - Implement basic todo CRUD operations
   - Build recurrence pattern parser
   - Implement virtual todo generation logic
   - Build rollover service

### Important Implementation Notes

- **Virtual vs Real Todos**: Query logic must merge real todos from database with dynamically generated virtual todos. Past dates only return real todos; current/future dates include virtuals.

- **Instance Date Preservation**: When rolling over a todo, `assigned_date` changes but `instance_date` NEVER changes. This preserves which occurrence it was (critical for recurring todos).

- **Orphaning vs Cascading**: When editing a recurring todo instance, it gets "orphaned" (set `recurring_todo_id=NULL` and add skip_recurring entry). Don't cascade delete real todos when parent recurring_todo is deleted.

- **Rollover Timing**: Rollover triggers when user views current date AND (last_rollover_date != current_date). Handle at: page load, API call, or WebSocket midnight event.

- **Position Gaps**: Use gaps in position numbers (0, 10, 20, 30...) to avoid updating all todos when inserting/reordering. Only update the moved todo's position.

## Date & Timezone Handling

- All dates stored as MySQL DATE type (e.g., '2024-01-15')
- User timezone stored in user profile (default 'UTC')
- Backend performs all date calculations in user's timezone
- "Current date" means current date in user's timezone, not server's timezone
- API provides `/api/user/current-date` endpoint for clients

## Testing Strategy

No test infrastructure set up yet. Plan includes:
- Backend: JUnit + MockMvc for controllers, Mockito for services
- Web: Jest + React Testing Library
- Mobile: Flutter test framework
- Integration tests for rollover logic and virtual todo generation

## Deployment

Backend planned for VPS deployment. todo.md includes low-memory configuration for Spring Boot (Java heap limits, connection pool tuning).

## Important Files to Reference

- **requirements.md**: Complete technical specification with detailed examples
- **todo.md**: 23-phase implementation plan broken into 600+ tasks
- **backend/todue/.env.example**: Required environment variables
- **requirements.md lines 275-498**: Detailed "How the System Works" section with complete scenario walkthrough
