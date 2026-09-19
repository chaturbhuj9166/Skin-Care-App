# SkinCare Consultation App — Backend

Node.js + Express + Prisma + PostgreSQL API for the SkinCare Consultation App.
The Flutter frontend currently runs on local mock data and is **not** wired up
to this backend yet — this service is built to be connected later without
changes to its contract.

## Stack

- Node.js 20+, Express 4
- PostgreSQL 16 via Prisma ORM 5
- JWT Bearer auth (separate tokens for Admin / User / Doctor)
- Socket.io for real-time chat + notifications
- bcryptjs for password hashing

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Copy the environment template and fill in your local PostgreSQL connection string:

   ```bash
   cp .env.example .env
   ```

   At minimum, set `DATABASE_URL` to a running PostgreSQL 16 instance, e.g.:

   ```
   DATABASE_URL="postgresql://postgres:postgres@localhost:5432/skincare_app?schema=public"
   ```

3. Create the database schema:

   ```bash
   npx prisma migrate dev --name init
   ```

4. Seed demo data (1 admin, 4 doctors, 3 users, an active question flow, and 3 demo cases in different statuses):

   ```bash
   npm run prisma:seed
   ```

5. Start the server in development (auto-restarts on file changes):

   ```bash
   npm run dev
   ```

   Or for production:

   ```bash
   npm start
   ```

The API listens on `PORT` (default `5000`). Health check: `GET /health`.

## Demo credentials (after seeding)

| Role   | Identifier                        | Password     |
|--------|------------------------------------|---------------|
| Admin  | admin@skincareapp.com              | Admin@123     |
| Doctor | ayesha.khan@skincareapp.com (+3 more) | Doctor@123 |
| User   | +919820000001 (+2 more)            | none — phone-based login |

## Stubbed integrations

Two third-party integrations are referenced by the spec but not yet
connected to real accounts. Both are isolated behind a single service
module each, so wiring in real credentials later requires no changes to
controllers or routes:

- **Firebase Cloud Messaging (push notifications)** — `src/services/fcm.js`.
  Without `FIREBASE_PROJECT_ID` / `FIREBASE_PRIVATE_KEY` / `FIREBASE_CLIENT_EMAIL`
  set, every push just logs to the console (`[FCM STUB] ...`).
- **Agora (video call tokens)** — `src/services/agora.js`. Without
  `AGORA_APP_ID` / `AGORA_APP_CERTIFICATE` set, a clearly-labeled placeholder
  token is generated instead of a real Agora RTC token.

Neither stub blocks any API flow — cases, solutions, and scheduled calls all
persist normally; only the outbound push/token step is mocked.

## Project structure

```
backend/
  prisma/schema.prisma   Data model (Admin, User, Doctor, Case, Message, ...)
  prisma/seed.js         Demo data seeder
  src/config/            Prisma client singleton + env var loading
  src/middleware/        JWT auth + role guards, validation, error handling
  src/routes/            Route definitions grouped by auth/user/doctor/admin
  src/controllers/       Request handlers (business logic)
  src/services/          fcm.js, agora.js (stubs) and socket.js (Socket.io)
  src/utils/             jwt, pagination, asyncHandler, ApiError helpers
  src/app.js             Express app (middleware + route mounting)
  src/server.js          HTTP server + Socket.io bootstrap
```

## Notes

- Questionnaire contract: `GET /api/users/question-flow` returns
  `{ questionFlow }` for the active flow, using a User JWT. Drafts remain
  admin-only. A missing active flow returns 404.
- Builder question types are `text`, `single_choice`, `multiple_choice`,
  `yes_no`, `rating`, and `photo_upload`. Each question retains its `required`
  flag (default true), receives a stable ID if omitted, and preserves array
  order. Choice questions need at least two distinct options.
- Submit answers keyed by question ID: text/single choice as strings,
  multiple choice as a string array, yes/no as a boolean, rating as an integer
  from 1 to 5, and photo upload as an array of uploaded URLs. Optional answers
  can be omitted. Inactive flows and invalid answers are rejected; a case
  permits at most five distinct photos across its upload answers and `photos`.
- Run questionnaire regression checks with `node --test test/questionFlow.test.js`.

- Phone-based user login/registration and OTP verification are mocked:
  there is no real SMS provider wired up, so `POST /api/auth/verify-otp`
  accepts any syntactically valid 6-digit code. See the comment above that
  handler in `src/controllers/auth.controller.js` for details.
- Pagination on list endpoints follows a consistent shape:
  `{ data, total, page, totalPages }`, defaulting to `page=1`, `limit=20`.
