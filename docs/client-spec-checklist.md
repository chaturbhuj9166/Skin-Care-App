# Client specification implementation tracker

Source: `P:/Downloads/SkinCareApp_Developer_Spec.pdf` (16 pages).
Reviewed against the workspace on 2026-09-17. Existing screens and API handlers
are not evidence that the complete workflow works against a live database.

## Required product

- Flutter User and Doctor applications, separate entry points, Android and iOS.
- React 18 admin dashboard with Tailwind 3, Framer Motion, Recharts and Zustand.
- Express / Prisma / PostgreSQL backend; authenticated REST and Socket.io.
- Firebase phone authentication, Storage and FCM; Agora calls; Railway deployment.
- PDF design tokens: teal #0A7C6E, green #22C55E, amber #F59E0B,
  Poppins headings, Inter body, 12px cards and 8px buttons.

## Verified gaps and acceptance criteria

| Area / PDF pages | Current evidence | Remaining acceptance criteria |
| --- | --- | --- |
| Admin dashboard / 6-8 | No `admin_dashboard` directory | Login, protected routes, analytics charts, recent cases/tickets and real-time refresh |
| Case administration / 6 | List, assign and status handlers exist | Search/date filters, case details, timeline, available-doctor selection, CSV export, consistent status transitions |
| Question builder / 7 | CRUD handlers exist; unrestricted type; required flag discarded | Six validated types, required toggle, options, stable IDs, reorder, preview, drafts and one active flow |
| Doctors / 7 | Backend CRUD exists | Cards, editing, availability, deletion confirmation, case totals and performance |
| Users / 7 | Backend list/block exists | Profile and case history, totals, searching and block UI |
| Tickets / 7,12 | Backend CRUD subset and mock mobile UI | Live history/detail/replies, filters, persisted update notifications |
| Notifications / 7,12,15 | Backend records/socket events; FCM logs only | Device registration, actual FCM delivery, delivery history, navigation metadata, unread count |
| Settings / 8 | No admin profile/password routes | Profile editing and old-password-verified password change |
| Mobile login / 10,13 | Boolean session flags and mock login | Firebase phone verification, backend verification of Firebase ID token, real JWT persistence and authenticated routing |
| Mobile API integration / 9-14 | Screens read `mockRepositoryProvider`; no Dio dependency | Models, Dio service, API providers, loading/error/empty states, refresh and real writes |
| Submit problem / 11 | Mock questions; text type lacks input; multiple choice behaves as single choice; photo counter only | Active flow endpoint, all six widgets, actual upload, five-photo limit, required checks, review and case submission |
| User navigation / 10 | Home/Cases/Tips/Profile plus center action | Home/Cases/Chat/Notifications/Profile and real-time notification badge |
| Case detail / 11,13 | Mock case details | Live answers/photos/solution, five-stage timeline, chat and scheduled call access |
| Chat / 11,14 | Local repository messages | Authenticated sockets, room ownership, attachments, typing indicators and read receipts |
| Solutions / 14 | Mock mobile submission; backend handler exists | Prescription rows, follow-up, attachment, preview, persistence and patient notification |
| Calls and appointments / 12-15 | Mock Flutter call UI; backend scheduling and token service | Agora integration, authorized token acquisition/renewal, local/remote video, controls, calendar and past calls |
| Profile / 12,14 | Mock data | Live profile/avatar updates, preferences, password change for doctors, logout confirmation |
| Ratings / 7,14 | Doctor analytics has a placeholder; schema has no ratings | Define rating collection and aggregation before displaying an average |
| Platforms / 15-16 | Android project exists; no iOS project | Separate user/doctor app IDs, Firebase platform files, permissions, iOS setup and release signing |
| Release / 15-16 | No deployment manifests or credentials configured in workspace | Database migration, integration validation, Railway services, policy/screenshots/icons and signed release builds |

## Contract decisions

1. The PDF asks the User app to fetch `/api/admin/question-flows`, but that
   namespace is admin-protected. Expose a user-authenticated active-flow endpoint
   under `/api/users/question-flow` without granting users admin access.
2. Phone numbers and six-digit strings alone do not prove an OTP was verified.
   The backend must verify a Firebase ID token before issuing a user JWT.
3. Keep questionnaire type strings consistent with existing seeds:
   `text`, `multiple_choice`, `single_choice`, `yes_no`, `rating`, `photo_upload`.
4. Deployment and store URLs/costs in the PDF are examples, not verified current
   account details. Actual account setup, secrets and release signing remain external inputs.

## Implementation order

1. Questionnaire and backend contracts; validation and regression checks.
2. Admin dashboard connected to backend APIs.
3. Mobile authentication and API integration; remove simulated successful flows.
4. Storage, notifications, chat and video integrations.
5. End-to-end validation, platform configuration and deployment.

## External inputs needed for live verification

- PostgreSQL connection and permission to use the intended database.
- Firebase project and Android/iOS app configuration; backend service account via environment variables.
- Agora app ID and certificate via environment variables.
- Railway project/access and chosen domains; store accounts and signing materials for publication.

Do not commit secrets. No cloud project, deployment or store submission was performed during this audit.

## Changes completed after the audit

- Builder request validation now supports exactly six types, preserves required
  flags and ordering, generates missing question IDs, rejects duplicate IDs and
  validates choice options. Empty questionnaire updates are rejected.
- Added authenticated `GET /api/users/question-flow` for the active flow.
- Case submission rejects inactive flows, missing required answers, invalid
  answer types/options and more than five photos. Upload answers are included
  in the case photo gallery data.
- Questionnaire regression tests exercise valid and invalid builder payloads
  and answers. Database-backed and mobile end-to-end verification is pending.
