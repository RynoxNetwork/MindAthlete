# MindAthlete API Reference

Comprehensive API documentation for iOS developers.

## Base URL

```
Development: http://localhost:8001
Production: https://your-domain.com
```

All endpoints are prefixed with `/api`

## Authentication

### Sign Up

**Endpoint**: `POST /api/auth/signup`

**Request Body**:
```json
{
  "email": "athlete@example.com",
  "password": "SecurePassword123",
  "full_name": "John Doe",
  "sport": "Basketball",
  "level": "University"
}
```

**Response**:
```json
{
  "user": {
    "id": "uuid",
    "email": "athlete@example.com"
  },
  "session": {
    "access_token": "jwt_token",
    "refresh_token": "refresh_token"
  },
  "message": "Account created successfully"
}
```

### Login

**Endpoint**: `POST /api/auth/login`

**Request Body**:
```json
{
  "email": "athlete@example.com",
  "password": "SecurePassword123"
}
```

**Response**:
```json
{
  "user": {
    "id": "uuid",
    "email": "athlete@example.com"
  },
  "session": {
    "access_token": "jwt_token",
    "refresh_token": "refresh_token"
  },
  "access_token": "jwt_token"
}
```

### Get Current User

**Endpoint**: `GET /api/auth/me`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "user": {
    "id": "uuid",
    "email": "athlete@example.com"
  },
  "profile": {
    "user_id": "uuid",
    "full_name": "John Doe",
    "sport": "Basketball",
    "level": "University",
    "goals": ["Improve focus"],
    "questionnaire_data": {}
  }
}
```

## Profile Management

### Update Profile

**Endpoint**: `PUT /api/profile`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "full_name": "John Doe",
  "sport": "Basketball",
  "level": "University",
  "goals": ["Improve focus", "Reduce stress"],
  "stress_factors": ["Exams", "Competition"],
  "training_frequency": 5
}
```

### Save Questionnaire

**Endpoint**: `POST /api/profile/questionnaire`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "sport": "Basketball",
  "level": "University",
  "main_goal": "Improve focus during games",
  "training_frequency": 5,
  "stress_factors": ["Exams", "Competition pressure"],
  "rest_quality": 3,
  "expectations": "Better mental preparation",
  "academic_load": "High"
}
```

## Schedule Management

### Get All Schedules

**Endpoint**: `GET /api/schedules`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "schedules": [
    {
      "id": "uuid",
      "day_of_week": 1,
      "start_time": "08:00",
      "end_time": "10:00",
      "type": "academic",
      "title": "Math Class",
      "notes": "Calculus lecture"
    }
  ]
}
```

### Create Schedule

**Endpoint**: `POST /api/schedules`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "day_of_week": 1,
  "start_time": "08:00",
  "end_time": "10:00",
  "type": "academic",
  "title": "Math Class",
  "notes": "Optional notes"
}
```

**Field Details**:
- `day_of_week`: 0 (Monday) to 6 (Sunday)
- `type`: "academic" or "training"
- `start_time` / `end_time`: "HH:MM" format (24-hour)

### Update Schedule

**Endpoint**: `PUT /api/schedules/{schedule_id}`

**Headers**: `Authorization: Bearer {token}`

**Request Body**: (all fields optional)
```json
{
  "title": "Updated Title",
  "start_time": "09:00"
}
```

### Delete Schedule

**Endpoint**: `DELETE /api/schedules/{schedule_id}`

**Headers**: `Authorization: Bearer {token}`

### Get Weekly Load

**Endpoint**: `GET /api/schedules/weekly-load`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "academic_hours": 20.5,
  "training_hours": 12.0,
  "total_hours": 32.5,
  "load_level": "moderate",
  "balance_ratio": 1.71
}
```

**Load Levels**:
- `low`: < 30 hours/week
- `moderate`: 30-40 hours/week
- `high`: > 40 hours/week

## Diary / Check-in

### Get Diary Entries

**Endpoint**: `GET /api/diary/entries?limit=30`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "entries": [
    {
      "id": "uuid",
      "date": "2025-01-15",
      "mood": 4,
      "energy": 3,
      "stress": 2,
      "notes": "Good day overall",
      "highlights": ["Great practice", "Felt focused"]
    }
  ]
}
```

### Create/Update Diary Entry

**Endpoint**: `POST /api/diary/entries`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "date": "2025-01-15",
  "mood": 4,
  "energy": 3,
  "stress": 2,
  "notes": "Optional notes",
  "highlights": ["Highlight 1", "Highlight 2"]
}
```

**Scale**: All ratings are 1-5 (1=low, 5=high)

### Get Specific Entry

**Endpoint**: `GET /api/diary/entries/{date}`

**Headers**: `Authorization: Bearer {token}`

**Example**: `GET /api/diary/entries/2025-01-15`

### Get Weekly Summary

**Endpoint**: `GET /api/diary/weekly-summary`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "summary": {
    "avg_mood": 3.7,
    "avg_energy": 3.2,
    "avg_stress": 2.8,
    "entries_count": 5,
    "trend": "improving"
  }
}
```

**Trend Values**:
- `improving`: avg_mood > 3.5
- `stable`: avg_mood 2.5-3.5
- `needs_attention`: avg_mood < 2.5

## Habits

### Get Habits

**Endpoint**: `GET /api/habits`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "habits": [
    {
      "id": "uuid",
      "title": "Morning meditation",
      "description": "10 minutes mindfulness",
      "frequency": "daily",
      "category": "mental",
      "active": true
    }
  ]
}
```

### Create Habit

**Endpoint**: `POST /api/habits`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "title": "Morning meditation",
  "description": "10 minutes of mindfulness",
  "frequency": "daily",
  "category": "mental",
  "target_days": [1, 3, 5]
}
```

**Categories**: "mental", "physical", "recovery"
**Frequency**: "daily" or "weekly"

### Update Habit

**Endpoint**: `PUT /api/habits/{habit_id}`

**Headers**: `Authorization: Bearer {token}`

### Track Habit

**Endpoint**: `POST /api/habits/{habit_id}/track`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "completed": true,
  "date": "2025-01-15",
  "notes": "Felt great after"
}
```

### Get Habit Stats

**Endpoint**: `GET /api/habits/stats?days=30`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "stats": [
    {
      "habit_id": "uuid",
      "title": "Morning meditation",
      "completion_rate": 85.7,
      "completed_count": 24,
      "total_days": 30
    }
  ]
}
```

## Guided Sessions

### Get Session Types

**Endpoint**: `GET /api/sessions/types`

**No auth required**

**Response**:
```json
{
  "types": [
    {
      "id": "focus",
      "title": "Enfoque y Concentración",
      "duration": 15,
      "description": "Mejora tu concentración"
    },
    {
      "id": "calm",
      "title": "Calma y Relajación",
      "duration": 10,
      "description": "Reduce el estrés"
    }
  ]
}
```

**Available Types**:
- `focus`: Enfoque y Concentración (15 min)
- `calm`: Calma y Relajación (10 min)
- `recovery`: Recuperación Mental (12 min)
- `pre_competition`: Pre-Competencia (8 min)
- `visualization`: Visualización (10 min)

### Complete Session

**Endpoint**: `POST /api/sessions/complete`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "session_type": "focus",
  "duration": 15,
  "rating": 5,
  "notes": "Very helpful"
}
```

### Get Session History

**Endpoint**: `GET /api/sessions/history?limit=20`

**Headers**: `Authorization: Bearer {token}`

## AI Coach

### Generate Recommendation

**Endpoint**: `POST /api/ai/recommendations`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "context": "Big game tomorrow, feeling nervous",
  "force_refresh": false
}
```

**Response**:
```json
{
  "recommendation": "Hola Juan! Veo que tienes un juego importante...\n\nPasos recomendados:\n1. Practica 10 minutos de respiración...\n2. Visualiza tu éxito...\n3. Descansa bien esta noche...\n\n¡Confía en tu preparación!",
  "context": {
    "mood": 3.7,
    "energy": 3.2,
    "stress": 2.8,
    "total_hours": 32.5,
    "habit_completion": 75.0
  },
  "generated_at": "2025-01-15T10:30:00Z"
}
```

**Context Considered**:
- User profile (sport, goals, stress factors)
- Weekly schedule load
- Recent mood/energy trends
- Habit completion rate
- Custom context provided

### Get Latest Recommendation

**Endpoint**: `GET /api/ai/recommendations/latest`

**Headers**: `Authorization: Bearer {token}`

## Analytics

### Track Event

**Endpoint**: `POST /api/analytics/events`

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "event_type": "session_completed",
  "event_data": {
    "session_type": "focus",
    "duration": 15
  }
}
```

**Common Event Types**:
- `session_completed`
- `diary_entry_created`
- `habit_tracked`
- `recommendation_viewed`
- `questionnaire_completed`

### Get Analytics Summary

**Endpoint**: `GET /api/analytics/summary?days=30`

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "summary": {
    "total_events": 145,
    "event_counts": {
      "session_completed": 23,
      "diary_entry_created": 28,
      "habit_tracked": 94
    },
    "period_days": 30
  }
}
```

## Health Check

### Health Status

**Endpoint**: `GET /api/health`

**No auth required**

**Response**:
```json
{
  "status": "healthy",
  "service": "MindAthlete API",
  "version": "1.0.0",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

## Error Responses

All errors follow this format:

```json
{
  "detail": "Error message"
}
```

**Common Status Codes**:
- `400`: Bad Request (invalid data)
- `401`: Unauthorized (missing/invalid token)
- `404`: Not Found
- `500`: Internal Server Error

## Rate Limiting

No rate limiting in development.
Production limits: TBD

## Pagination

Use `limit` query parameter where available:

```
GET /api/diary/entries?limit=10
GET /api/sessions/history?limit=20
```

Default limits:
- Diary entries: 30
- Sessions: 20
- Analytics: 30 days

## Date & Time Formats

- **Dates**: `YYYY-MM-DD` (e.g., "2025-01-15")
- **Times**: `HH:MM` 24-hour (e.g., "14:30")
- **Timestamps**: ISO 8601 (e.g., "2025-01-15T10:30:00Z")
- **Day of Week**: 0 (Monday) to 6 (Sunday)

## iOS Integration Tips

### 1. Token Management

```swift
class AuthManager {
    private var accessToken: String?
    
    func saveToken(_ token: String) {
        accessToken = token
        KeychainHelper.save(token, key: "access_token")
    }
    
    func getAuthHeader() -> String? {
        guard let token = accessToken else { return nil }
        return "Bearer \(token)"
    }
}
```

### 2. API Client

```swift
class MindAthleteAPI {
    static let baseURL = "http://localhost:8001/api"
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthManager.shared.getAuthHeader() {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### 3. Error Handling

```swift
struct APIError: Decodable {
    let detail: String
}

do {
    let response: ProfileResponse = try await api.request(endpoint: "/profile")
} catch {
    if let data = (error as? URLError)?.errorUserInfo[NSURLErrorFailingURLPairKey] as? Data {
        let apiError = try? JSONDecoder().decode(APIError.self, from: data)
        print("API Error: \(apiError?.detail ?? "Unknown")")
    }
}
```

---

**For interactive documentation, visit**: http://localhost:8001/docs