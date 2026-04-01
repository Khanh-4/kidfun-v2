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

## Git Workflow — BẮT BUỘC

### Quy trình cho MỖI task

**Bước 1: Tạo feature branch**
```bash
git checkout develop
git pull origin develop
git checkout -b feature/<area>/<tên-task>
```

**Bước 2: Code + commit**
```bash
git add -A
git commit -m "feat(area): mô tả ngắn"
```

**Bước 3: Push + tạo PR về develop**
```bash
git push origin feature/<area>/<tên-task>
```

**Bước 4: Review + merge**
- Code của bạn Frontend: Khanh review → approve → merge
- Code của Khanh: Tự review → bypass rules → merge

**Bước 5: Dọn dẹp branch**
```bash
git checkout develop && git pull origin develop
git branch -d feature/<area>/<tên-task-cũ>
```

### KHÔNG ĐƯỢC
- Push thẳng lên `develop` hoặc `main`
- Code trực tiếp trên `develop`
- Merge mà chưa tạo PR
- Bắt đầu task mới khi chưa merge task cũ

### PHẢI LÀM
- Mỗi task = 1 feature branch riêng
- Mỗi feature branch = 1 PR → base: develop
- Pull develop mới nhất TRƯỚC KHI tạo branch
- Commit message format: `feat/fix/chore(area): mô tả`

### Quy ước commit message
```
feat(backend): add Socket.IO device events
feat(mobile): implement device list screen
fix(backend): handle null deviceCode in disconnect
fix(mobile): device status not updating real-time
chore(backend): update prisma schema
docs: update API contract
```

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **kidfun-v2** (744 symbols, 1281 relationships, 23 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/kidfun-v2/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/kidfun-v2/context` | Codebase overview, check index freshness |
| `gitnexus://repo/kidfun-v2/clusters` | All functional areas |
| `gitnexus://repo/kidfun-v2/processes` | All execution flows |
| `gitnexus://repo/kidfun-v2/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
