# MindAthlete Backend Setup Guide

## 🎯 Quick Start

Follow these steps to get your MindAthlete backend API running:

### Step 1: Database Setup (REQUIRED)

Your Supabase database needs to be set up before the API can work properly.

#### Option A: Using Supabase Dashboard (Recommended)

1. **Go to your Supabase project**:
   - URL: https://supabase.com/dashboard/project/fgzsxsfoozgzchbkysco
   - Navigate to **SQL Editor** (left sidebar)

2. **Create the database schema**:
   - Click **New Query**
   - Copy the entire contents of `supabase_schema.sql` file
   - Paste into the SQL editor
   - Click **Run** or press `Ctrl/Cmd + Enter`

3. **Verify tables were created**:
   - Navigate to **Table Editor** (left sidebar)
   - You should see 8 new tables:
     - `user_profiles`
     - `schedules`
     - `diary_entries`
     - `habits`
     - `habit_tracking`
     - `session_completions`
     - `ai_recommendations`
     - `analytics_events`

#### Option B: Using Supabase CLI

```bash
# Install Supabase CLI (if not installed)
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref fgzsxsfoozgzchbkysco

# Run migrations
supabase db push --file /app/backend/supabase_schema.sql
```

### Step 2: Verify Backend is Running

The backend should already be running on port 8001.

```bash
# Check if server is healthy
curl http://localhost:8001/api/health

# Expected response:
# {
#   "status": "healthy",
#   "service": "MindAthlete API",
#   "version": "1.0.0"
# }
```

If the server is not running:

```bash
cd /app/backend
python server.py
```

### Step 3: Test the API

Once the database is set up, test the complete flow:

```bash
# Run the test script
cd /app/backend
chmod +x test_api.sh
./test_api.sh
```

Or test manually:

```bash
# 1. Create an account
curl -X POST http://localhost:8001/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "your.email@example.com",
    "password": "SecurePassword123",
    "full_name": "Your Name",
    "sport": "Your Sport",
    "level": "University"
  }'

# 2. Use the access_token from the response for subsequent requests
```

### Step 4: View API Documentation

Open your browser and visit:

- **Interactive Docs**: http://localhost:8001/docs
- **ReDoc**: http://localhost:8001/redoc

The interactive docs allow you to test all endpoints directly from your browser.

## 📱 iOS App Integration

### Update Your iOS App Configuration

In your iOS app, update the API base URL:

```swift
// In your NetworkManager or Configuration file
let apiBaseURL = "http://localhost:8001/api"

// For production deployment, update to:
// let apiBaseURL = "https://your-production-domain.com/api"
```

### Example iOS Request

```swift
import Foundation

class MindAthleteAPI {
    static let shared = MindAthleteAPI()
    let baseURL = "http://localhost:8001/api"
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
    
    func generateRecommendation(token: String, context: String?) async throws -> AIRecommendation {
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
        return try JSONDecoder().decode(AIRecommendation.self, from: data)
    }
}

// Response Models
struct AuthResponse: Codable {
    let user: User
    let session: Session
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case user, session
        case accessToken = "access_token"
    }
}

struct User: Codable {
    let id: String
    let email: String
}

struct Session: Codable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct AIRecommendation: Codable {
    let recommendation: String
    let context: RecommendationContext
    let generatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case recommendation, context
        case generatedAt = "generated_at"
    }
}

struct RecommendationContext: Codable {
    let mood: Double
    let energy: Double
    let stress: Double
    let totalHours: Double
    let habitCompletion: Double
    
    enum CodingKeys: String, CodingKey {
        case mood, energy, stress
        case totalHours = "total_hours"
        case habitCompletion = "habit_completion"
    }
}

enum APIError: Error {
    case invalidResponse
    case invalidData
}
```

## 🔧 Troubleshooting

### Issue: "Could not find the table 'public.user_profiles'"

**Solution**: The database schema hasn't been set up yet.
- Follow **Step 1** above to create the tables in Supabase

### Issue: "Authentication failed"

**Solution**: Check that:
- You're including the token in the Authorization header: `Bearer YOUR_TOKEN`
- The token hasn't expired (tokens expire after 1 hour)
- The user exists in Supabase Auth

### Issue: "OpenAI API error"

**Solution**: Verify:
- OpenAI API key is correct in `.env` file
- You have sufficient credits in your OpenAI account
- The model name is correct (`gpt-4o`)

### Issue: Backend not responding

**Solution**:
```bash
# Check if backend is running
ps aux | grep server.py

# Check logs
tail -f /tmp/backend.log

# Restart backend
pkill -f server.py
cd /app/backend && python server.py > /tmp/backend.log 2>&1 &
```

## 📊 Database Tables Overview

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `user_profiles` | Extended user data | sport, level, goals, questionnaire_data |
| `schedules` | Academic + training schedule | day_of_week, start_time, end_time, type |
| `diary_entries` | Daily check-ins | date, mood, energy, stress |
| `habits` | Habit definitions | title, frequency, category |
| `habit_tracking` | Daily habit completions | habit_id, date, completed |
| `session_completions` | Guided session history | session_type, duration, rating |
| `ai_recommendations` | AI coach responses | recommendation, context |
| `analytics_events` | User activity tracking | event_type, event_data |

## 🎯 Key Features Available

✅ **Authentication**
- Sign up with email/password
- Login with JWT tokens
- Secure Row Level Security (RLS)

✅ **User Profile**
- Extended profile with sport, level, goals
- Onboarding questionnaire data storage

✅ **Schedule Management**
- Create academic and training schedules
- Automatic weekly load calculation
- Balance tracking between academic/training

✅ **Diary System**
- Daily mood, energy, stress tracking
- Weekly summaries and trends
- Highlights and notes

✅ **Habits Tracking**
- Create custom habits
- Daily/weekly tracking
- Completion statistics

✅ **Guided Sessions**
- 5 session types (focus, calm, recovery, pre-competition, visualization)
- Completion tracking with ratings
- Session history

✅ **AI Coach (OpenAI GPT-4o)**
- Personalized recommendations
- Context-aware (schedule, mood, habits)
- Spanish language (empathetic tone)
- 3-step actionable advice

✅ **Analytics**
- Event tracking
- Usage summaries
- User insights

## 🚀 Next Steps

1. ✅ Set up Supabase database (run SQL schema)
2. ✅ Test API endpoints
3. 📱 Integrate with your iOS app
4. 🧪 Test complete user flows
5. 🎨 Customize AI coach prompts (optional)
6. 🚀 Deploy to production

## 📖 Additional Resources

- **Full API Reference**: See `API_REFERENCE.md`
- **README**: See `README.md` for detailed documentation
- **Interactive API Docs**: http://localhost:8001/docs
- **Database Schema**: See `supabase_schema.sql`

## 💡 Tips for iOS Development

1. **Token Storage**: Use Keychain to securely store JWT tokens
2. **Token Refresh**: Implement automatic token refresh before expiration
3. **Error Handling**: Parse the `detail` field from error responses
4. **Offline Mode**: Cache data locally using Core Data or SwiftData
5. **Network Layer**: Use Combine or async/await for reactive networking
6. **Date Formatting**: Use ISO8601DateFormatter for consistent date parsing

## 🔒 Security Notes

- All user data is protected by Row Level Security (RLS)
- Users can only access their own data
- JWT tokens expire after 1 hour
- API keys are stored in environment variables (never in code)
- CORS is configured to allow all origins (restrict in production)

## 📞 Support

If you encounter any issues:

1. Check the **Troubleshooting** section above
2. Review the API logs: `tail -f /tmp/backend.log`
3. Check Supabase logs in your dashboard
4. Test endpoints using the interactive docs: http://localhost:8001/docs

---

**Ready to build! 🚀**
