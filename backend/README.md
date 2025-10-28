# MindAthlete Backend API

Backend API for MindAthlete iOS app - A mental wellness platform for college athletes.

## 🚀 Features

- **Authentication**: Supabase Auth integration with JWT
- **User Profiles**: Extended profiles with questionnaire data
- **Schedule Management**: Academic + training schedule with load calculation
- **Diary System**: Daily mood, energy, and stress tracking
- **Habits Tracking**: Create and track mental wellness habits
- **Guided Sessions**: Session types and completion tracking
- **AI Coach**: Daily suggestions, chat coaching, habit plans and escalation routing
- **Analytics**: Event tracking and user insights

## 🛠 Tech Stack

- **Framework**: FastAPI (Python)
- **Database**: Supabase (PostgreSQL)
- **Auth**: Supabase Auth
- **AI**: OpenAI GPT-4o
- **Deployment**: Uvicorn

## 📋 Prerequisites

- Python 3.9+
- Supabase account and project
- OpenAI API key

## 🔧 Setup

### 1. Install Dependencies

```bash
cd /app/backend
pip install -r requirements.txt
```

### 2. Configure Environment Variables

The `.env` file is already configured with your credentials:

```env
SUPABASE_URL=https://fgzsxsfoozgzchbkysco.supabase.co
SUPABASE_ANON_KEY=your_anon_key
OPENAI_API_KEY=your_openai_key
BACKEND_PORT=8001
ENVIRONMENT=development
CHAT_ENCRYPTION_KEY=base64_generated_key
CHAT_DAILY_FREE_LIMIT=10
HABIT_PLAN_FREE_COOLDOWN_DAYS=21
```

### 3. Setup Supabase Database

1. Go to your Supabase project: https://supabase.com/dashboard/project/fgzsxsfoozgzchbkysco
2. Navigate to **SQL Editor**
3. Copy the contents of `supabase_schema.sql`
4. Paste and run the SQL commands

This will create:
- All required tables
- Row Level Security (RLS) policies
- Performance indexes

### 4. Start the Server

```bash
python server.py
```

The API will be available at: `http://localhost:8001`

## 📚 API Documentation

Once the server is running, visit:
- **Interactive API Docs**: http://localhost:8001/docs
- **ReDoc**: http://localhost:8001/redoc

## 🔐 Authentication

All endpoints (except `/api/auth/*` and `/api/health`) require authentication.

### Getting a Token

1. **Sign Up**:
```bash
curl -X POST http://localhost:8001/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "athlete@example.com",
    "password": "SecurePassword123",
    "full_name": "John Doe",
    "sport": "Basketball",
    "level": "University"
  }'
```

2. **Login**:
```bash
curl -X POST http://localhost:8001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "athlete@example.com",
    "password": "SecurePassword123"
  }'
```

Response includes `access_token` to use in subsequent requests.

### Using the Token

Include the token in the `Authorization` header:

```bash
curl -X GET http://localhost:8001/api/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## 🎯 API Endpoints

### Authentication
- `POST /api/auth/signup` - Create new account
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Profile
- `PUT /api/profile` - Update profile
- `POST /api/profile/questionnaire` - Save onboarding questionnaire

### Schedule
- `GET /api/schedules` - Get all schedule blocks
- `POST /api/schedules` - Create schedule block
- `PUT /api/schedules/{id}` - Update schedule block
- `DELETE /api/schedules/{id}` - Delete schedule block
- `GET /api/schedules/weekly-load` - Get weekly load calculation

### Diary
- `GET /api/diary/entries` - Get diary entries (last 30 days)
- `POST /api/diary/entries` - Create/update diary entry
- `GET /api/diary/entries/{date}` - Get specific date entry
- `GET /api/diary/weekly-summary` - Get weekly mood summary

### Habits
- `GET /api/habits` - Get active habits
- `POST /api/habits` - Create new habit
- `PUT /api/habits/{id}` - Update habit
- `POST /api/habits/{id}/track` - Track habit completion
- `GET /api/habits/stats` - Get habit statistics

### Sessions
- `GET /api/sessions/types` - Get available session types
- `POST /api/sessions/complete` - Mark session as completed
- `GET /api/sessions/history` - Get session history

### AI Coach
- `POST /api/recommendations/daily` - Contextual daily suggestion based on agenda
- `POST /api/coach/chat` - Streamed chat coaching session (requires Supabase JWT)
- `POST /api/coach/habit-plan` - Generate multi-day habit plan
- `POST /api/escalate` - Trigger escalation workflows for human specialists

### Analytics
- `POST /api/analytics/events` - Track event
- `GET /api/analytics/summary` - Get analytics summary

### Health
- `GET /api/health` - Health check
- `GET /` - API info

## 🧪 Testing Examples

### Complete User Flow

```bash
# 1. Sign up
SIGNUP_RESPONSE=$(curl -s -X POST http://localhost:8001/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@mindathlete.com",
    "password": "Test123456",
    "full_name": "Test Athlete",
    "sport": "Soccer",
    "level": "University"
  }')

# Extract token
TOKEN=$(echo $SIGNUP_RESPONSE | jq -r '.session.access_token')

# 2. Save questionnaire
curl -X POST http://localhost:8001/api/profile/questionnaire \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sport": "Soccer",
    "level": "University",
    "main_goal": "Improve focus during games",
    "training_frequency": 5,
    "stress_factors": ["Exams", "Competition pressure"],
    "rest_quality": 3,
    "expectations": "Better mental preparation",
    "academic_load": "High"
  }'

# 3. Create schedule
curl -X POST http://localhost:8001/api/schedules \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "day_of_week": 1,
    "start_time": "08:00",
    "end_time": "10:00",
    "type": "academic",
    "title": "Math Class",
    "notes": "Calculus lecture"
  }'

# 4. Create diary entry
curl -X POST http://localhost:8001/api/diary/entries \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-01-15",
    "mood": 4,
    "energy": 3,
    "stress": 2,
    "notes": "Good training session today",
    "highlights": ["Great practice", "Felt focused"]
  }'

# 5. Create habit
HABIT_RESPONSE=$(curl -s -X POST http://localhost:8001/api/habits \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Morning meditation",
    "description": "10 minutes of mindfulness",
    "frequency": "daily",
    "category": "mental"
  }')

HABIT_ID=$(echo $HABIT_RESPONSE | jq -r '.habit.id')

# 6. Track habit
curl -X POST http://localhost:8001/api/habits/$HABIT_ID/track \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "completed": true,
    "date": "2025-01-15",
    "notes": "Felt calm and focused"
  }'

# 7. Complete session
curl -X POST http://localhost:8001/api/sessions/complete \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "session_type": "focus",
    "duration": 15,
    "rating": 5,
    "notes": "Very helpful before practice"
  }'

# 8. Get AI recommendation
curl -X POST http://localhost:8001/api/ai/recommendations \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "context": "Big game tomorrow, feeling nervous",
    "force_refresh": true
  }'

# 9. Get weekly load
curl -X GET http://localhost:8001/api/schedules/weekly-load \
  -H "Authorization: Bearer $TOKEN"

# 10. Get analytics
curl -X GET http://localhost:8001/api/analytics/summary?days=7 \
  -H "Authorization: Bearer $TOKEN"
```

## 🤖 AI Coach Context

The AI coach generates personalized recommendations based on:

1. **User Profile**: Sport, level, goals, stress factors
2. **Schedule Load**: Total hours, academic/training balance
3. **Emotional State**: Weekly mood, energy, stress averages
4. **Habit Performance**: Completion rates
5. **Recent Activity**: Sessions completed, diary trends
6. **Custom Context**: User-provided situational context

### AI Response Format

```
[Personalized greeting and brief analysis]

Pasos recomendados:
1. [Specific actionable step]
2. [Specific actionable step]
3. [Specific actionable step]

[Motivational closing message]
```

## 📊 Database Schema

See `supabase_schema.sql` for complete schema with:
- 8 main tables
- Row Level Security (RLS) policies
- Performance indexes
- Foreign key relationships

## 🔒 Security

- **Row Level Security (RLS)**: All tables have RLS policies
- **JWT Authentication**: Supabase Auth with secure tokens
- **Data Isolation**: Users can only access their own data
- **API Key Protection**: Environment variables for sensitive keys

## 🚦 Health Check

```bash
curl http://localhost:8001/api/health
```

Response:
```json
{
  "status": "healthy",
  "service": "MindAthlete API",
  "version": "1.0.0",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

## 📱 iOS Integration

### Base URL Configuration

```swift
// In your iOS app
let baseURL = "http://localhost:8001/api"
// For production:
// let baseURL = "https://your-api-domain.com/api"
```

### Example Swift Request

```swift
import Foundation

func login(email: String, password: String) async throws -> AuthResponse {
    let url = URL(string: "\(baseURL)/auth/login")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["email": email, "password": password]
    request.httpBody = try JSONEncoder().encode(body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(AuthResponse.self, from: data)
    
    return response
}

func getRecommendation(token: String, context: String?) async throws -> AIRecommendation {
    let url = URL(string: "\(baseURL)/ai/recommendations")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
        "context": context ?? "",
        "force_refresh": false
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(AIRecommendation.self, from: data)
    
    return response
}
```

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Verify Supabase URL and keys in `.env`
   - Check if RLS policies are properly set up
   - Ensure tables exist (run `supabase_schema.sql`)

2. **Authentication Errors**
   - Verify JWT token format: `Bearer YOUR_TOKEN`
   - Check token expiration (tokens expire after 1 hour)
   - Ensure user exists in Supabase Auth

3. **OpenAI API Errors**
   - Verify API key is valid
   - Check API quota and billing
   - Ensure model name is correct (`gpt-4o`)

4. **CORS Issues (iOS)**
   - API allows all origins by default
   - For production, restrict origins in `CORSMiddleware`

## 📝 Development Notes

- All timestamps use ISO 8601 format
- Dates use YYYY-MM-DD format
- Time uses HH:MM format (24-hour)
- All responses are JSON
- Error responses include `detail` field

## 🚀 Production Deployment

1. Update `.env` with production values
2. Set `ENVIRONMENT=production`
3. Restrict CORS origins
4. Use HTTPS for all communications
5. Set up monitoring and logging
6. Configure rate limiting
7. Use managed PostgreSQL (Supabase)

## 📞 Support

For issues or questions:
- Check API documentation: http://localhost:8001/docs
- Review Supabase logs
- Check OpenAI usage dashboard

## 📄 License

MindAthlete Backend API - Proprietary

---

**Built with ❤️ for college athletes**
