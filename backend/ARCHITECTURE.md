# MindAthlete Backend Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         MindAthlete iOS App                              │
│                                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │Onboarding│  │  Home    │  │ Schedule │  │  Diary   │  │  Habits  │ │
│  │  Flow    │  │  Screen  │  │ Manager  │  │ Check-in │  │ Tracker  │ │
│  └─────┬────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│        │            │             │             │             │        │
│        └────────────┴─────────────┴─────────────┴─────────────┘        │
│                              │                                          │
│                      URLSession / Alamofire                             │
│                              │                                          │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
                               │ HTTPS / REST API
                               │ Authorization: Bearer <JWT>
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                      FastAPI Backend (Port 8001)                         │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                        API Routes                                 │  │
│  │                                                                   │  │
│  │  /api/auth/*          Authentication & User Management           │  │
│  │  /api/profile/*       User Profile & Questionnaire               │  │
│  │  /api/schedules/*     Academic & Training Schedule                │  │
│  │  /api/diary/*         Daily Emotional Check-ins                   │  │
│  │  /api/habits/*        Habit Creation & Tracking                   │  │
│  │  /api/sessions/*      Guided Session Types & Completion           │  │
│  │  /api/ai/*            AI Coach Recommendations                    │  │
│  │  /api/analytics/*     Event Tracking & Insights                   │  │
│  │                                                                   │  │
│  └───┬───────────────────────┬──────────────────────┬───────────────┘  │
│      │                       │                      │                   │
│  ┌───▼───┐              ┌────▼─────┐          ┌────▼─────┐            │
│  │ Auth  │              │ Database │          │    AI    │            │
│  │Service│              │ Service  │          │ Service  │            │
│  └───┬───┘              └────┬─────┘          └────┬─────┘            │
│      │                       │                      │                   │
└──────┼───────────────────────┼──────────────────────┼───────────────────┘
       │                       │                      │
       │                       │                      │
┌──────▼───────┐      ┌────────▼─────────┐    ┌──────▼──────┐
│   Supabase   │      │    Supabase      │    │   OpenAI    │
│     Auth     │      │   PostgreSQL     │    │   GPT-4o    │
│              │      │                  │    │             │
│ • JWT Tokens │      │ • user_profiles  │    │ • Context   │
│ • Sessions   │      │ • schedules      │    │ • Analysis  │
│ • Users      │      │ • diary_entries  │    │ • Generate  │
│              │      │ • habits         │    │             │
└──────────────┘      │ • habit_tracking │    └─────────────┘
                      │ • sessions       │
                      │ • ai_recs        │
                      │ • analytics      │
                      │                  │
                      │ • RLS Policies   │
                      │ • Indexes        │
                      └──────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                        Data Flow Example                                 │
│                   AI Recommendation Generation                           │
└─────────────────────────────────────────────────────────────────────────┘

1. iOS App → POST /api/ai/recommendations
            {"context": "Big game tomorrow", "force_refresh": true}

2. Backend → Get User Profile
            SELECT * FROM user_profiles WHERE user_id = ?

3. Backend → Calculate Weekly Load
            SELECT * FROM schedules WHERE user_id = ?
            → Total: 32.5 hrs (20.5 academic + 12 training)

4. Backend → Get Mood Trends
            SELECT * FROM diary_entries WHERE date >= ?
            → Avg: mood=3.7, energy=3.2, stress=2.8

5. Backend → Get Habit Performance
            SELECT * FROM habits, habit_tracking WHERE user_id = ?
            → Completion: 75%

6. Backend → Build Context Prompt
            User: Soccer player, University level
            Goals: Improve focus
            Load: 32.5 hrs/week (moderate)
            Mood: 3.7/5 (stable-improving)
            Context: "Big game tomorrow"

7. Backend → OpenAI GPT-4o
            POST https://api.openai.com/v1/chat/completions
            Model: gpt-4o
            Prompt: [Empathetic Spanish coach with user context]

8. OpenAI → Generate Response
            "¡Hola Carlos! Veo que tienes un juego importante...
            
            Pasos recomendados:
            1. Practica respiración profunda
            2. Visualiza jugadas exitosas
            3. Descansa bien esta noche
            
            ¡Confía en tu preparación!"

9. Backend → Save Recommendation
            INSERT INTO ai_recommendations (user_id, recommendation, context)

10. Backend → Return to iOS
             {
               "recommendation": "...",
               "context": {...},
               "generated_at": "2025-01-15T10:30:00Z"
             }

11. iOS App → Display in Coach Card
              • Show personalized message
              • Highlight 3 action steps
              • Add motivational tone


┌─────────────────────────────────────────────────────────────────────────┐
│                     Security & Authentication Flow                       │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────┐                    ┌─────────┐                    ┌──────────┐
│   iOS   │                    │ FastAPI │                    │ Supabase │
│   App   │                    │ Backend │                    │   Auth   │
└────┬────┘                    └────┬────┘                    └────┬─────┘
     │                              │                              │
     │  1. Sign Up                  │                              │
     ├─────────────────────────────►│                              │
     │  email, password, name       │  2. Create Auth User         │
     │                              ├─────────────────────────────►│
     │                              │                              │
     │                              │  3. Return JWT Token         │
     │  4. Return Token             │◄─────────────────────────────┤
     │◄─────────────────────────────┤                              │
     │  access_token, refresh_token │                              │
     │                              │                              │
     │  5. Store in Keychain        │                              │
     │  ✓ Secure Storage            │                              │
     │                              │                              │
     │  6. API Request with Token   │                              │
     ├─────────────────────────────►│  7. Verify Token             │
     │  Authorization: Bearer <JWT> ├─────────────────────────────►│
     │                              │                              │
     │                              │  8. Token Valid              │
     │                              │◄─────────────────────────────┤
     │                              │  user_id, email              │
     │  9. Return Data              │                              │
     │◄─────────────────────────────┤ 10. Query with RLS          │
     │  (user's data only)          │     WHERE user_id = <token>  │
     │                              │                              │


┌─────────────────────────────────────────────────────────────────────────┐
│                         Technology Stack                                 │
└─────────────────────────────────────────────────────────────────────────┘

Backend:
  • Language: Python 3.11
  • Framework: FastAPI 0.110.1
  • Server: Uvicorn (ASGI)
  • Async: asyncio, async/await

Database:
  • Provider: Supabase
  • Database: PostgreSQL
  • Auth: Supabase Auth (JWT)
  • Security: Row Level Security (RLS)

AI/ML:
  • Provider: OpenAI
  • Model: GPT-4o
  • Language: Spanish
  • Use Case: Mental wellness coaching

iOS App:
  • Language: Swift
  • Framework: SwiftUI
  • Networking: URLSession
  • Security: Keychain

External Services:
  • Supabase (https://fgzsxsfoozgzchbkysco.supabase.co)
  • OpenAI API (https://api.openai.com)


┌─────────────────────────────────────────────────────────────────────────┐
│                      Database Schema Overview                            │
└─────────────────────────────────────────────────────────────────────────┘

user_profiles
├─ user_id (UUID, FK to auth.users)
├─ email
├─ full_name
├─ sport
├─ level
├─ goals (ARRAY)
├─ stress_factors (ARRAY)
├─ training_frequency (INT)
├─ questionnaire_data (JSONB)
└─ timestamps

schedules
├─ user_id (UUID, FK)
├─ day_of_week (0-6)
├─ start_time (HH:MM)
├─ end_time (HH:MM)
├─ type (academic/training)
├─ title
└─ notes

diary_entries
├─ user_id (UUID, FK)
├─ date (DATE)
├─ mood (1-5)
├─ energy (1-5)
├─ stress (1-5)
├─ notes
└─ highlights (ARRAY)

habits
├─ user_id (UUID, FK)
├─ title
├─ description
├─ frequency (daily/weekly)
├─ category
├─ target_days (ARRAY)
└─ active (BOOLEAN)

habit_tracking
├─ habit_id (UUID, FK)
├─ user_id (UUID, FK)
├─ date (DATE)
├─ completed (BOOLEAN)
└─ notes

session_completions
├─ user_id (UUID, FK)
├─ session_type
├─ duration (minutes)
├─ rating (1-5)
└─ completed_at

ai_recommendations
├─ user_id (UUID, FK)
├─ recommendation (TEXT)
├─ context (JSONB)
├─ model
└─ created_at

analytics_events
├─ user_id (UUID, FK)
├─ event_type
├─ event_data (JSONB)
└─ timestamp


┌─────────────────────────────────────────────────────────────────────────┐
│                          API Endpoints Map                               │
└─────────────────────────────────────────────────────────────────────────┘

Authentication & Profile:
  POST   /api/auth/signup                Create account
  POST   /api/auth/login                 Login
  GET    /api/auth/me                    Get current user
  PUT    /api/profile                    Update profile
  POST   /api/profile/questionnaire      Save onboarding

Schedule Management:
  GET    /api/schedules                  Get all schedules
  POST   /api/schedules                  Create schedule
  PUT    /api/schedules/{id}             Update schedule
  DELETE /api/schedules/{id}             Delete schedule
  GET    /api/schedules/weekly-load      Get weekly load

Diary / Check-in:
  GET    /api/diary/entries              Get entries (last 30)
  POST   /api/diary/entries              Create/update entry
  GET    /api/diary/entries/{date}       Get specific date
  GET    /api/diary/weekly-summary       Get weekly summary

Habits:
  GET    /api/habits                     Get active habits
  POST   /api/habits                     Create habit
  PUT    /api/habits/{id}                Update habit
  POST   /api/habits/{id}/track          Track completion
  GET    /api/habits/stats               Get statistics

Sessions:
  GET    /api/sessions/types             Get available types
  POST   /api/sessions/complete          Mark completed
  GET    /api/sessions/history           Get history

AI Coach:
  POST   /api/ai/recommendations         Generate recommendation
  GET    /api/ai/recommendations/latest  Get latest

Analytics:
  POST   /api/analytics/events           Track event
  GET    /api/analytics/summary          Get summary

System:
  GET    /api/health                     Health check
  GET    /                               API info
  GET    /docs                           Interactive docs


┌─────────────────────────────────────────────────────────────────────────┐
│                      Performance & Scalability                           │
└─────────────────────────────────────────────────────────────────────────┘

Async Architecture:
  • Non-blocking I/O for all database operations
  • Concurrent request handling
  • Efficient resource utilization

Database Optimization:
  • Indexes on user_id, date, timestamp fields
  • Query optimization with proper joins
  • Row Level Security at database level

Caching Strategy:
  • AI recommendations cached in database
  • Reuse within same day unless force_refresh
  • Weekly summaries pre-calculated

Scalability:
  • Stateless backend (easy horizontal scaling)
  • Database connection pooling (Supabase)
  • CDN-ready for static assets
  • Microservices-ready architecture


┌─────────────────────────────────────────────────────────────────────────┐
│                      Deployment Checklist                                │
└─────────────────────────────────────────────────────────────────────────┘

Pre-Production:
  ☐ Run Supabase SQL schema
  ☐ Test all API endpoints
  ☐ Verify Supabase RLS policies
  ☐ Test OpenAI integration
  ☐ Configure production CORS
  ☐ Set up error monitoring
  ☐ Configure logging
  ☐ Set up database backups

Production:
  ☐ Deploy to cloud (Render, Railway, AWS, etc.)
  ☐ Configure production environment variables
  ☐ Set up SSL/HTTPS
  ☐ Configure custom domain
  ☐ Set up rate limiting
  ☐ Configure monitoring (Sentry, DataDog, etc.)
  ☐ Set up CI/CD pipeline
  ☐ Load testing
  ☐ Update iOS app with production URL

Post-Launch:
  ☐ Monitor API performance
  ☐ Track error rates
  ☐ Monitor OpenAI costs
  ☐ Review user analytics
  ☐ Gather feedback
  ☐ Plan feature iterations
```
