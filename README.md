# Todue

A simple, low-friction todo list application with recurring tasks, multi-device sync, and offline support.

## Overview

Todue is a multi-platform todo application designed for quick, low-friction task management. It features:

- **Text-based recurring patterns** - No dropdowns, just type "every day", "every week", "every month", etc.
- **Smart rollover** - Incomplete tasks automatically roll to today
- **Real-time sync** - Changes sync instantly across all your devices via WebSocket
- **Offline support** - Mobile apps work offline and sync when reconnected
- **Multi-day view** - See your tasks across multiple days at once
- **Drag-and-drop ordering** - Customize your task order

## Tech Stack

### Backend
- Java 21 with Spring Boot 3.5.7
- MySQL database
- WebSocket for real-time updates
- JWT authentication

### Web Frontend
- React 19.1.1 with TypeScript
- Vite build tool
- Real-time WebSocket integration

### Mobile Apps
- Flutter (iOS & Android)
- Offline-first architecture with local SQLite database

## Project Structure

```
todue/
├── backend/todue/     # Spring Boot backend API
├── web/               # React web application
├── mobile/            # Flutter mobile apps
├── requirements.md    # Complete technical specification
├── todo.md            # Implementation plan with tasks
└── CLAUDE.md          # Developer guidance for Claude Code
```

## Prerequisites

### Backend Development
- Java JDK 21 or higher
- Maven 3.6+
- MySQL 8.0+
- Access to `td-db` MySQL database

### Web Development
- Node.js 18+ and npm
- Modern web browser

### Mobile Development
- Flutter SDK 3.9.2+
- Android Studio / Xcode (for mobile development)

## Getting Started

### 1. Backend Setup

```bash
cd backend/todue

# Copy environment template and configure
cp .env.example .env
# Edit .env with your database credentials

# Build the project
./mvnw clean install

# Run the development server
./mvnw spring-boot:run
```

The backend will start on `http://localhost:8080`

**Environment Variables** (`.env` file):
```
DB_HOST=your-mysql-host
DB_PORT=3306
DB_NAME=td_db
DB_USERNAME=your-db-user
DB_PASSWORD=your-db-password
JWT_SECRET=your-secret-key-at-least-256-bits
```

### 2. Web Frontend Setup

```bash
cd web

# Install dependencies
npm install

# Start development server
npm run dev
```

The web app will start on `http://localhost:5173`

### 3. Mobile App Setup

```bash
cd mobile

# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android
```

## Development Commands

### Backend
```bash
cd backend/todue

# Build
./mvnw clean package

# Run tests
./mvnw test

# Run with specific profile
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

### Web
```bash
cd web

# Development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint
```

### Mobile
```bash
cd mobile

# Run tests
flutter test

# Build for release
flutter build apk          # Android
flutter build ios          # iOS

# Analyze code
flutter analyze
```

## Key Features

### Recurring Todos
Create recurring tasks by adding patterns to your task text:
- "Pay rent every month"
- "Exercise every day"
- "Team meeting every week"
- "Dentist appointment every year"
- "Grocery shopping every other week"

The system automatically generates task instances based on the pattern.

### Rollover Logic
Incomplete tasks from previous days automatically appear at the top of today's list. The system:
- Materializes up to 1 past recurring instance (oldest first)
- Rolls forward existing incomplete tasks
- Preserves the original date while displaying them on today

### Virtual vs Materialized Todos
- **Virtual todos**: Generated on-the-fly for future recurring instances
- **Materialized todos**: Become real database entries when interacted with

### Real-time Synchronization
All changes sync instantly across devices using WebSocket connections. No polling, no delays.

## Database Schema

The application uses 5 main tables:
- `users` - User accounts with timezone support
- `todos` - Task instances (both regular and from recurring patterns)
- `recurring_todos` - Recurring pattern definitions
- `skip_recurring` - Skipped instances of recurring tasks
- `password_reset_tokens` - Password reset functionality

For detailed schema information, see `requirements.md` (lines 193-267).

## API Documentation

### Authentication Endpoints
- `POST /api/auth/register` - Create new user account
- `POST /api/auth/login` - Authenticate user
- `POST /api/auth/reset-password-request` - Request password reset
- `POST /api/auth/reset-password` - Complete password reset

### Todo Endpoints
- `GET /api/todos?date=YYYY-MM-DD` - Get todos for a specific date
- `GET /api/todos?start_date=...&end_date=...` - Get todos for date range
- `POST /api/todos` - Create new todo
- `PUT /api/todos/{id}/text` - Update todo text
- `PUT /api/todos/{id}/position` - Update todo order
- `POST /api/todos/{id}/complete` - Mark todo complete
- `DELETE /api/todos/{id}` - Delete todo

### WebSocket
- `/ws` - Real-time update channel (requires JWT authentication)

## Development Status

**Current Phase**: Phase 1 - Foundation & Setup (~40% complete)

This project is in early development. Core scaffolding is in place, but most features are not yet implemented. See `todo.md` for the complete 23-phase implementation plan.

## Documentation

- `requirements.md` - Complete technical specification (504 lines)
- `todo.md` - Detailed implementation plan (1,719 lines with 600+ tasks)
- `CLAUDE.md` - Architecture guide for Claude Code development

## Contributing

This is currently a personal project. Contributions are not being accepted at this time.

## License

All rights reserved.

## Contact

For questions or issues, please create an issue in the repository.
