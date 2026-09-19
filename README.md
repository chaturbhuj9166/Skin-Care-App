# Skin-Care-App

SkinCare Consultation App — a telemedicine platform connecting patients with dermatologists.

## Structure

- `backend/` — Node.js + Express + Prisma + PostgreSQL API (auth, cases, chat, video calls, notifications, admin)
- `app/` — Flutter app for patients and doctors (single app, role-based after login)
- `admin_dashboard/` — React + Vite admin console (cases, doctors, users, tickets, question builder, notifications)
- `docs/` — project documentation and client-facing checklists

## Getting started

Each subproject has its own setup — see `backend/.env.example` for required environment variables, then:

```bash
# Backend
cd backend && npm install && npm run prisma:migrate && npm run dev

# Admin dashboard
cd admin_dashboard && npm install && npm run dev

# Flutter app
cd app && flutter pub get && flutter run
```
