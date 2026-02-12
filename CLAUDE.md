# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KidFun v2 is a smart parental control system with soft warning technology. Full-stack monorepo with:
- **Backend:** Express.js + Prisma ORM + SQLite + Socket.IO (port 3001)
- **Parent Dashboard:** React 19 + Vite + Material-UI (port 3000)
- **Child Monitor:** React 19 + Vite + Material-UI (port 3002)
- **Real-time:** Socket.IO for parent-child communication (time extension requests)

## Common Commands

### Development
```bash
npm run dev              # Start backend + parent dashboard concurrently
npm run dev:backend      # Backend only (nodemon)
npm run dev:parent       # Parent dashboard only (Vite)
npm run dev:child        # Child monitor only (Vite)
```

### Database (Prisma + SQLite)
```bash
npm run db:migrate       # Run Prisma migrations
npm run db:seed          # Seed database
npm run db:studio        # Open Prisma Studio GUI
npm run db:reset         # Reset database
```

### Testing
```bash
npm run test:backend     # Jest tests for backend
npm run test:frontend    # Jest tests for parent dashboard
cd backend && npx jest --watch              # Watch mode
cd backend && npx jest path/to/test.js      # Single test file
cd backend && npx jest --coverage           # Coverage report
```

### Build & Lint
```bash
npm run build            # Build all (backend + both frontends)
npm run lint             # ESLint check
npm run lint:fix         # ESLint autofix
```

### First-time Setup
```bash
npm run install:all      # Install all dependencies
cp backend/.env.example backend/.env        # Create env file
npm run db:setup         # Initialize database with migrations
```

## Architecture

### Backend (`backend/src/`)
- **server.js** — Express app entry point, mounts middleware (helmet, cors, morgan) and Socket.IO
- **controllers/** — Business logic: `authController`, `deviceController`, `profileController`, `monitoringController`
- **routes/** — REST endpoints under `/api/auth`, `/api/profiles`, `/api/devices`, `/api/monitoring`
- **middleware/auth.js** — JWT authentication (`authenticate`, `authorizeParent`)
- **middleware/validation.js** — express-validator wrapper
- **services/socketService.js** — Socket.IO event handling with family-based rooms (`family_{userId}`)
- **prisma/schema.prisma** — 10 models: User, Profile, Device, TimeLimit, BlockedWebsite, Application, UsageLog, Warning, Notification, Session

### Frontend Pattern (both apps)
- **services/api.js** — Axios instance with JWT interceptor (base URL: `http://localhost:3001/api`), auto-redirect on 401
- **services/socketService.js** — Socket.IO client singleton
- **pages/** — Route-level components
- **components/** — Reusable UI organized by feature
- Auth state persisted in localStorage (token + user object)

### Socket.IO Events Flow
1. Parent/child join `family_{userId}` room on connect
2. Child sends `requestTimeExtension` → parent receives `timeExtensionRequest`
3. Parent sends `respondTimeExtension` → child receives `timeExtensionResponse`

### Key Conventions
- Vietnamese commit messages and UI text
- MUI theme: primary=indigo (#6366f1), secondary=pink (#f472b6)
- Child UI uses large fonts, rounded corners (borderRadius: 16), gradient backgrounds
- Backend uses bcryptjs (salt=10) for passwords, JWT with 24h expiry
- Device linking via unique `deviceCode` (no auth required for `/api/devices/link`)
- TimeLimit has unique constraint on `[profileId, dayOfWeek]`
