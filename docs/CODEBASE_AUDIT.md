# Codebase Audit & Refactoring Roadmap (Student-Scoped)

> **Lưu ý:** File này trước đây chỉ chứa *prompt* yêu cầu audit (xem Appendix bên dưới), chưa có audit thực sự nào được chạy — không có Executive Summary, không có bảng ưu tiên, không có roadmap. Nội dung dưới đây là audit thực tế, chạy trên codebase hiện tại (dựa trên `docs/CODEMAPS/*` + đọc trực tiếp source), và đã áp bộ lọc "student-friendly / không over-engineer" ngay từ đầu thay vì đề xuất một kiến trúc enterprise rồi mới cắt gọt.

## 1. Executive Summary

KidFun v2 là một **monorepo đồ án sinh viên** (không phải SaaS đa tenant quy mô lớn): 1 backend Express monolith, 2 React frontend, 1 app Flutter, dùng chung 1 Postgres (Supabase) qua Prisma. Quy mô thực tế: vài trăm gia đình là nhiều, 1 instance backend, chạy trên Railway.

**Kết luận chính:** kiến trúc hiện tại (routes → middleware → controller → service (một phần) → Prisma → Postgres) là **phù hợp** với quy mô này và **không cần đổi kiến trúc**. Vấn đề thật sự không phải là "thiếu abstraction" mà là:
1. Vài file controller quá tải trách nhiệm (điển hình `childController.js`, 764 dòng).
2. Test coverage gần như bằng 0 trên các flow quan trọng (auth, session, SOS, geofence).
3. Một job (`aiAnalysisWorker`) thiếu self-schedule trong khi job tương tự (`reportWorker`) đã có.

Không có vấn đề kiến trúc mức "phải đổi framework/DB/pattern".

## 2. Đánh giá kiến trúc hiện tại

```
Client (web/mobile) → Express routes → middleware (helmet/cors/rate-limit/auth) 
                     → controller → [service, ở nơi đã có] → Prisma → PostgreSQL
```

- 24 controller, tất cả gọi Prisma trực tiếp — **không có repository/DTO layer**, và điều đó **ổn**: Prisma *đã là* lớp trừu tượng trên SQL; thêm repository layer phía trên Prisma chỉ nhân đôi boilerplate mà không đổi được gì (không có kế hoạch đổi DB/ORM).
- Service layer **đã tồn tại và đang được dùng đúng chỗ**: `aiService`, `reportService`, `geofenceService`, `firebaseService`, `emailService`, `cacheService`, `socketService`. Vấn đề là nó chưa được áp dụng nhất quán — một số controller lớn (child, auth) vẫn ôm hết logic thay vì tách ra service như các domain khác đã làm.
- Socket.IO dùng room theo `family_{userId}` — đơn giản, đúng nhu cầu (không cần message broker).
- Scheduled job dùng `setInterval` tự viết trong `reportWorker.js` — không dùng `node-cron`/queue. Với 1 instance backend, cách này **đủ dùng**, không cần Bull/BullMQ + Redis ở giai đoạn này.

## 3. Findings thực tế (grounded, không phải liệt kê lý thuyết)

| Priority | Problem | Location | Impact | Recommended Action |
|---|---|---|---|---|
| P1 | God controller: session lifecycle + status + warning + content-filter query + time-limit query gộp trong 1 file | `backend/src/controllers/childController.js` (764 dòng, 11 hàm) | Khó đọc, khó test, mọi thay đổi child-flow đều đụng 1 file lớn | Tách các hàm session-lifecycle (`startSession, heartbeat, endSession, pauseSession, resumeSession, addBonus, calcRemaining`) sang `sessionService.js`, giữ controller mỏng — theo đúng pattern các domain khác đã dùng |
| P1 | Test coverage gần như 0 trên flow rủi ro cao | Backend: 3 file test. Frontend: 0. Mobile: 1 | Bug ở auth/session/SOS/geofence không bị bắt trước khi lên prod | Viết characterization test cho 5 flow rủi ro nhất (xem §6), không cần phủ toàn bộ codebase |
| P1 | Worker thiếu tự động hoá | `aiAnalysisWorker.js` không self-schedule (khác `reportWorker.js` đã có `startScheduler()`) | Phân tích an toàn video YouTube chỉ chạy khi có người gọi `/api/admin/run-ai-analysis` bằng tay | Thêm self-scheduler giống `reportWorker.js` (cùng pattern `setInterval`, không thêm dependency mới) |
| P2 | `authController.js` (414 dòng) cũng đang gộp nhiều trách nhiệm (register/login/google/forgot/reset/logout/profile/change-password) | `backend/src/controllers/authController.js` | Tương tự childController nhưng ít cấp bách hơn vì các hàm đều thuộc domain "auth" nên cohesion vẫn cao | Tách khi nào chạm tới file này lần sau (không cần sprint riêng) |
| P3 | Naming/magic numbers rải rác (chưa audit sâu) | rải rác trong controllers | Thấp | Dọn khi refactor các file liên quan, không cần pass riêng |

## 4. Đề xuất bị loại vì Over-engineering (điểm quan trọng nhất của audit này)

Đây là phần trả lời trực tiếp câu hỏi "có over-engineering không" — không phải trong file cũ (vì file cũ chưa có đề xuất cụ thể nào), mà là những gì bộ rule chung (`~/.claude/rules/ecc/**`, áp cho mọi project) và các audit-prompt kiểu enterprise thường đẩy vào, và **không nên áp cho project này**:

1. **Repository Pattern + DTO layer riêng** — Prisma đã đóng vai trò đó. Thêm layer nữa chỉ tăng số file phải sửa mỗi khi đổi 1 field, không tăng khả năng test hay swap datastore (không có nhu cầu swap datastore).
2. **Clean/Hexagonal Architecture, CQRS, Event Sourcing, Microservices** — đúng như chính cuốn *System Design Interview* (Alex Xu) mở đầu ở Chương 1 "Scale from Zero to Millions of Users": load balancer, sharding, message queue, cache layer riêng... chỉ xuất hiện **khi single-server/single-DB thật sự không chịu tải nổi**. KidFun đang ở giai đoạn "single server + managed Postgres", còn cách rất xa điểm đó. Áp các pattern này bây giờ chỉ tạo ra nhiều lớp gián tiếp mà sinh viên (và cả người review) khó theo dõi hơn.
3. **Mandatory 80% test coverage + TDD bắt buộc cho mọi task** (từ rule global) — hợp lý cho team trả lương ship production liên tục, không hợp lý cho đồ án 1-2 người chạy theo sprint deadline. Nên chuyển sang **risk-based testing**: test kỹ các flow "hại thật nếu sai" (time-limit enforcement, SOS, geofence, auth), bỏ qua CRUD ít rủi ro.
4. **Multi-agent split-role review cho mọi thay đổi** — overhead quy trình không tương xứng với quy mô nhóm. Dùng cho thay đổi thật sự nhạy cảm (auth, enforcement logic), bỏ cho CRUD thường.
5. **"200-400 dòng/file" áp cứng nhắc** — dùng làm tín hiệu cảnh báo, không phải luật cắt file máy móc. Khi tách `childController.js`, tách theo trách nhiệm (session lifecycle vs status/query), không chẻ nhỏ theo số dòng.
6. **Redis + BullMQ/queue system cho scheduled job** — `setInterval` hiện tại đủ dùng với 1 instance. Chỉ cần đổi khi backend chạy nhiều instance (lúc đó `setInterval` sẽ sinh report trùng lặp — xem migration trigger bên dưới).

## 5. Target Architecture (giữ nguyên, hoàn thiện thay vì đổi mới)

Không đề xuất kiến trúc mới. Mục tiêu: **áp dụng nhất quán** pattern service-layer đã có sẵn cho các domain còn lại, chứ không phải thêm layer mới:

```
Current:  routes → controller (mixed: HTTP + business logic, ở 1 số domain) → Prisma
Target:   routes → controller (chỉ HTTP: parse/validate/respond) → service (business logic) → Prisma
```

**Migration triggers** — chỉ cân nhắc pattern nặng hơn khi 1 trong các điều kiện sau xảy ra thật (không phải bây giờ):
- Backend cần chạy >1 instance để scale/uptime → lúc đó mới đổi report scheduler từ `setInterval` sang cron/queue thật.
- Khối lượng video cần AI-analyze tăng lớn → lúc đó mới đưa `aiAnalysisWorker` vào queue (BullMQ) thay vì endpoint admin-trigger.
- Có client thứ 3 (ngoài web/mobile) cần đọc data độc lập với Express API → lúc đó repository/interface layer mới thực sự có giá trị.
- Nhóm phát triển lớn hơn (>2-3 người sửa cùng file thường xuyên) → lúc đó siết lại test-gate/review process.

## 6. Roadmap (4 phase, nhỏ, rủi ro thấp — thay vì 8 phase kiểu enterprise)

**Phase 0 — Safety net (test tối thiểu, không phải 80% coverage)**
- Viết test cho 5 flow rủi ro cao nhất: `auth` (login/register), `session` (start/heartbeat/end), `extension request` (approve), `SOS` (create/resolve), `geofence` (enter/exit).
- Verification: test pass, ghi lại behavior hiện tại làm baseline trước khi tách code.

**Phase 1 — Tách `childController.js`**
- Tạo `sessionService.js`, chuyển các hàm session-lifecycle vào đó, controller chỉ còn parse request → gọi service → trả response.
- Files affected: `childController.js`, file mới `services/sessionService.js`, `routes/child.js` (không đổi route contract).
- Risk: thấp (không đổi API, không đổi DB schema). Verify: chạy lại test Phase 0 + smoke test tay trên mobile app (start/heartbeat/end session thật).

**Phase 2 — Fix scheduler gap cho `aiAnalysisWorker.js`**
- Thêm `startScheduler()` theo đúng pattern `reportWorker.js` đã dùng (không thêm dependency).
- Verify: worker tự chạy đúng giờ cấu hình, `/api/admin/ai-status` vẫn phản ánh đúng trạng thái.

**Phase 3 — Tách `authController.js` (làm khi nào chạm tới, không cần lịch riêng)**
- Cùng cách làm như Phase 1, ưu tiên thấp hơn.

Mỗi phase đi theo đúng git workflow đã có trong `CLAUDE.md` (feature branch riêng → PR → develop), không cần quy trình review nhiều agent cho các phase này — review 1 người là đủ với rủi ro thấp như trên.

## 7. Testing Strategy

Không áp coverage % cứng. Ưu tiên theo rủi ro:
- **Phải test:** flow mà bug = trẻ vượt giới hạn thời gian, SOS không gửi được, geofence không cảnh báo, auth bị bypass.
- **Không cần ưu tiên test ngay:** CRUD ít rủi ro (đổi tên profile, danh sách blocked-site, v.v.) — bug ở đây chỉ gây khó chịu, không gây hại.

## 8. Recommended Next Steps

1. Bắt đầu Phase 0 (test tối thiểu) trước khi động vào `childController.js` — để có baseline so sánh behavior.
2. Sau khi có test, thực hiện Phase 1 (tách session logic).
3. Phase 2 (scheduler fix) có thể làm song song, độc lập với Phase 1.
4. Regenerate `docs/CODEMAPS/backend.md` sau khi Phase 1-2 xong (dùng skill `update-codemaps`) để codemap phản ánh đúng service boundary mới.

---

## Appendix — Prompt gốc dùng để chạy audit này

<details>
<summary>Prompt template (Phase 1-10, tiếng Việt) — giữ lại để tái sử dụng cho audit sau này</summary>

# Full Codebase Audit & Refactoring Plan

Bạn là một **Senior Software Engineer / Software Architect**, đồng thời có vai trò như một mentor hướng dẫn một **sinh viên đại học ngành Công nghệ phần mềm**.

Tôi có một project hiện tại và muốn tiếp tục phát triển project này. Tuy nhiên, codebase đã có một số vấn đề về architecture, structure, readability, maintainability, duplicated code, dependency management và có thể có technical debt.

## Mục tiêu

Trước tiên, hãy **đọc và phân tích TOÀN BỘ PROJECT hiện tại**.

KHÔNG được bắt đầu refactor ngay.

Tôi muốn bạn thực hiện theo quy trình:

1. Khám phá toàn bộ repository.
2. Hiểu architecture hiện tại.
3. Hiểu business logic hiện tại.
4. Hiểu database/data model.
5. Hiểu API/backend/frontend interaction nếu project có.
6. Xác định các vấn đề trong codebase.
7. Đánh giá mức độ nghiêm trọng của từng vấn đề.
8. Đề xuất architecture/structure tốt hơn.
9. Lập kế hoạch refactor theo từng phase nhỏ.
10. Chỉ sau khi có plan rõ ràng mới bắt đầu refactor.

---

# PHASE 1 — FULL CODEBASE DISCOVERY

Hãy đọc toàn bộ project, bao gồm nhưng không giới hạn:

* Source code
* Configuration files
* Project files
* Package/dependency files
* Database configuration
* Entity/Model
* DTO
* Repository
* Service
* Controller
* API
* Middleware
* Authentication/Authorization
* Frontend
* Components
* Pages
* Hooks
* Utilities
* Tests
* Scripts
* Docker files
* Environment configuration
* Documentation
* README
* Migration
* SQL scripts
* CI/CD configuration nếu có

Trước khi đưa ra nhận xét, hãy xác định:

### 1. Tech Stack

Liệt kê:

* Programming languages
* Frameworks
* Libraries
* Database
* ORM
* Authentication mechanism
* API style
* Build tools
* Package manager
* Testing framework
* Deployment mechanism

### 2. Project Structure

Hãy mô tả structure hiện tại.

Ví dụ:

```text
project/
├── ...
├── ...
└── ...
```

Giải thích trách nhiệm của từng folder/module quan trọng.

### 3. Architecture

Xác định project đang sử dụng architecture nào.

Ví dụ:

* Layered Architecture
* MVC
* Clean Architecture
* Hexagonal Architecture
* Modular Monolith
* Microservices
* hoặc architecture tự xây dựng

Nếu architecture hiện tại không rõ ràng, hãy nói rõ.

### 4. Application Flow

Trace các flow quan trọng từ đầu đến cuối.

Ví dụ:

```text
Request
→ Controller
→ Service
→ Repository
→ Database
→ Response
```

Nếu có frontend:

```text
UI
→ API Client
→ Backend
→ Service
→ Repository
→ Database
```

Hãy xác định những dependency giữa các layer/module.

---

# PHASE 2 — CODEBASE HEALTH AUDIT

Đánh giá codebase theo các tiêu chí:

## A. Architecture

Kiểm tra:

* Separation of concerns
* Dependency direction
* Layer boundaries
* Coupling
* Cohesion
* Circular dependencies
* God classes
* God modules
* Leaky abstractions

## B. Code Quality

Tìm:

* Duplicate code
* Dead code
* Unused code
* Long methods
* Large classes
* Large files
* Complex conditions
* Deep nesting
* Magic numbers
* Magic strings
* Poor naming
* Inconsistent naming
* Poor error handling
* Poor exception handling
* Inconsistent coding style

## C. SOLID

Đánh giá:

* SRP
* OCP
* LSP
* ISP
* DIP

Không chỉ nói "vi phạm SOLID".

Hãy chỉ ra:

```text
File:
Class:
Method:

Problem:
Why it is a problem:
Suggested improvement:
```

## D. Design Patterns

Xác định:

* Existing design patterns
* Misused design patterns
* Opportunities for useful patterns

Không được cố nhồi design pattern nếu không cần thiết.

## E. Database

Kiểm tra:

* Schema
* Relationships
* Primary keys
* Foreign keys
* Indexes
* Constraints
* Normalization
* Naming
* Migration
* Query efficiency
* N+1 queries
* Transaction handling
* Data integrity

## F. API

Nếu project có API, kiểm tra:

* REST conventions
* Endpoint naming
* HTTP methods
* HTTP status codes
* Request validation
* Response structure
* Error response
* DTO usage
* Authentication
* Authorization
* Pagination
* Filtering
* Sorting
* Logging

## G. Security

Kiểm tra ở mức codebase:

* Authentication
* Authorization
* Password handling
* Token/session handling
* Secrets
* Environment variables
* Input validation
* SQL injection
* XSS
* CSRF
* CORS
* Sensitive information exposure
* Insecure configuration

Nếu phát hiện security issue nghiêm trọng, đánh dấu:

```text
CRITICAL
```

## H. Performance

Tìm các vấn đề có khả năng ảnh hưởng:

* Database queries
* N+1 queries
* Unnecessary API calls
* Unnecessary rendering
* Memory usage
* Large payloads
* Blocking operations
* Inefficient algorithms

---

# PHASE 3 — PRIORITIZATION

Không phải vấn đề nào cũng cần sửa ngay.

Hãy phân loại:

### P0 — Critical

Có khả năng:

* Làm application crash
* Làm mất dữ liệu
* Security vulnerability nghiêm trọng
* Architecture blocker

### P1 — High

Ảnh hưởng đáng kể đến:

* Maintainability
* Correctness
* Performance
* Extensibility

### P2 — Medium

Code smell hoặc technical debt nên sửa.

### P3 — Low

Cosmetic hoặc minor improvement.

Tạo bảng:

| Priority | Problem | Location | Impact | Difficulty | Recommended Action |
| -------- | ------- | -------- | ------ | ---------- | ------------------ |

---

# PHASE 4 — STUDENT-FRIENDLY ARCHITECTURE REVIEW

Hãy đánh giá project dưới góc nhìn của một sinh viên Software Engineering.

Không cần biến project thành một enterprise architecture quá phức tạp.

Nguyên tắc:

> Simple > Clever

> Maintainable > Over-engineered

> Understandable > Abstraction-heavy

Hãy trả lời:

1. Architecture hiện tại có phù hợp với quy mô project không?
2. Có đang over-engineering không?
3. Có đang under-engineering không?
4. Layer/module nào đang có vấn đề?
5. Có cần thay đổi architecture không?
6. Có cần tách module không?
7. Có cần thêm abstraction/interface không?
8. Có abstraction nào đang thừa không?

---

# PHASE 5 — TARGET ARCHITECTURE

Đề xuất architecture mục tiêu.

Ví dụ nếu phù hợp:

```text
Presentation
    ↓
Application
    ↓
Domain
    ↓
Infrastructure
```

Hoặc một structure phù hợp hơn với project thực tế.

KHÔNG được áp dụng Clean Architecture/CQRS/Microservices/Event-driven architecture chỉ vì chúng phổ biến.

Chỉ đề xuất khi project thực sự cần.

Hãy đưa ra:

```text
Current Architecture
        ↓
Problems
        ↓
Target Architecture
        ↓
Benefits
        ↓
Migration Strategy
```

---

# PHASE 6 — REFACTORING ROADMAP

Tạo roadmap refactor theo từng phase.

Ví dụ:

```text
Phase 0 — Safety
Phase 1 — Cleanup
Phase 2 — Architecture
Phase 3 — Business Logic
Phase 4 — Database
Phase 5 — API
Phase 6 — Testing
Phase 7 — Documentation
```

Mỗi phase phải có:

* Objective
* Files/modules affected
* Changes
* Risk
* Expected result
* Verification method

Ưu tiên refactor theo nguyên tắc:

```text
Low risk
→ High value
→ Small changes
→ Verify
→ Continue
```

---

# PHASE 7 — DO NOT BREAK EXISTING FUNCTIONALITY

Đây là yêu cầu rất quan trọng.

Trong quá trình refactor:

* Không tự ý thay đổi business rules.
* Không tự ý thay đổi database schema nếu chưa cần.
* Không tự ý đổi API contract.
* Không tự ý đổi authentication flow.
* Không tự ý thay framework.
* Không tự ý upgrade dependencies lớn.
* Không rewrite toàn bộ application.
* Không xóa code chỉ vì bạn cho rằng nó không cần thiết nếu chưa xác minh.
* Không thay đổi behavior chỉ để code "đẹp hơn".

Nếu cần thay đổi behavior, phải nói rõ:

```text
Current behavior:
Expected behavior:
Why change is necessary:
Potential impact:
```

---

# PHASE 8 — TESTING BEFORE REFACTOR

Trước khi refactor những phần quan trọng:

1. Kiểm tra project có build/run được không.
2. Kiểm tra existing tests.
3. Nếu chưa có test, xác định những flow quan trọng cần test trước.
4. Tạo characterization tests hoặc test tối thiểu nếu cần.

Mục tiêu:

```text
Before refactor
    ↓
Known working behavior
    ↓
Refactor
    ↓
Run tests
    ↓
Compare behavior
```

Không refactor mù.

---

# PHASE 9 — OUTPUT REPORT

Sau khi đọc project, tạo một file:

```text
docs/CODEBASE_AUDIT.md
```

File này phải chứa:

1. Executive Summary
2. Tech Stack
3. Current Architecture
4. Project Structure
5. Main Application Flows
6. Dependency Overview
7. Code Quality Assessment
8. SOLID Assessment
9. Database Assessment
10. API Assessment
11. Security Assessment
12. Performance Assessment
13. Technical Debt
14. Problems by Priority
15. Recommended Architecture
16. Refactoring Roadmap
17. Risk Assessment
18. Testing Strategy
19. Recommended Next Steps

---

# PHASE 10 — IMPORTANT: DO NOT MODIFY SOURCE CODE YET

Ở bước đầu tiên này:

**CHỈ ĐỌC + PHÂN TÍCH + LẬP KẾ HOẠCH.**

Không sửa source code.

Không tạo commit.

Không xóa file.

Không rename hàng loạt.

Không migrate database.

Không thay đổi dependency.

Sau khi hoàn thành audit, hãy dừng lại và báo cho tôi:

```text
AUDIT COMPLETED

Project understanding:
...

Critical issues:
...

High priority issues:
...

Recommended architecture:
...

Refactoring phases:
...

Recommended first task:
...
```

Sau đó tôi sẽ review plan và yêu cầu bạn bắt đầu từng phase.

---

# RULES FOR ALL FUTURE REFACTORING

Khi tôi yêu cầu bắt đầu refactor:

1. Chỉ refactor đúng scope tôi yêu cầu.
2. Trước khi sửa file, hãy đọc file đó và các dependency liên quan.
3. Không sửa hàng loạt nếu không cần.
4. Giữ behavior hiện tại.
5. Sau mỗi thay đổi:

   * Build
   * Run tests
   * Check compile errors
   * Check affected functionality
6. Nếu có lỗi, fix trước khi tiếp tục.
7. Giải thích ngắn gọn:

   * What changed
   * Why
   * Before
   * After
   * Risk
8. Nếu có nhiều cách refactor, đưa ra lựa chọn và recommendation.
9. Ưu tiên code dễ hiểu đối với sinh viên.
10. Không over-engineer.

## Coding Philosophy

Hãy ưu tiên:

```text
Readable
Maintainable
Testable
Simple
Consistent
```

thay vì:

```text
Maximum abstraction
Maximum patterns
Maximum complexity
```

## Final Principle

Đừng cố biến project sinh viên thành một hệ thống enterprise.

Hãy biến codebase hiện tại thành một project:

> "Đủ sạch để tiếp tục phát triển, đủ tốt để bảo trì, đủ rõ ràng để sinh viên có thể hiểu và trình bày."

</details>
