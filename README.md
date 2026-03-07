# Todue

A simple, low-friction todo list application with recurring tasks, later lists, routines, multi-device sync, and cross-platform support.

## Overview

Todue is an open-source, self-hostable multi-platform todo application designed for quick, low-friction task management. Own your data, host it yourself.

- **Day-to-Day Todos** - Organize your tasks by date and stay on top of what matters today
- **Later Lists** - Save ideas and tasks for later in organized, custom lists
- **Step-by-Step Routines** - Build repeatable routines and follow them with guided execution
- **Recurring Tasks** - Set tasks to repeat daily, weekly, monthly, or on your own schedule
- **Auto Rollover** - Unfinished todos automatically move to today so nothing slips through
- **Routine Insights** - Track streaks, completion times, and build better habits over time
- **Real-time Sync** - Changes sync instantly across all your devices via WebSocket
- **Web, iOS & Android** - Use Todue anywhere — your tasks are always with you

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
- Flutter (iOS & Android), SDK 3.9.2+
- Offline-first architecture with local SQLite database

## Project Structure

```
todue/
├── backend/todue/     # Spring Boot backend API
├── web/               # React web application
├── mobile/            # Flutter mobile apps
├── .gitignore         # Hide secrets
├── deploy.sh          # Deploys backend+frontend to VPS
├── todue.service      # Systemd config for VPS Process
├── requirements.md    # Complete technical specification
├── CLAUDE.md          # Developer guidance for Claude Code
└── README.md
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

### Later Lists
Capture ideas and tasks that aren't tied to a specific date. Organize them into named lists and check them off when ready.

### Routines
Build step-by-step routines for repeated workflows. Execute them with guided tracking, and view analytics on streaks and completion times.

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

## Prerequisites

### Backend Development
- Java JDK 21 or higher
- Maven 3.6+
- MySQL 8.0+

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

## Contributing

This is currently a personal project. Contributions are not being accepted at this time.

## License

All rights reserved.

## Contact

For questions or issues, please create an issue in the repository.
