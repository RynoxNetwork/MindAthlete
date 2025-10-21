# MindAthlete API - iOS Developer Quick Reference

## 🚀 Getting Started in 5 Minutes

### 1. Configure Base URL
```swift
// NetworkConfig.swift
struct NetworkConfig {
    static let baseURL = "http://localhost:8001/api"
    // Production: "https://your-domain.com/api"
}
```

### 2. Create API Client
```swift
// APIClient.swift
import Foundation

class APIClient {
    static let shared = APIClient()
    let baseURL = NetworkConfig.baseURL
    private var accessToken: String?
    
    func setToken(_ token: String) {
        self.accessToken = token
        KeychainHelper.save(token, forKey: "access_token")
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(error.detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case httpError(Int)
}

struct ErrorResponse: Codable {
    let detail: String
}
```

---

## 🔐 Authentication

### Sign Up
```swift
struct SignupRequest: Codable {
    let email: String
    let password: String
    let fullName: String
    let sport: String?
    let level: String?
    
    enum CodingKeys: String, CodingKey {
        case email, password, sport, level
        case fullName = "full_name"
    }
}

struct AuthResponse: Codable {
    let user: User
    let session: Session
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case user, session
        case accessToken = "access_token"
    }
}

func signup(email: String, password: String, fullName: String) async throws {
    let request = SignupRequest(
        email: email,
        password: password,
        fullName: fullName,
        sport: nil,
        level: nil
    )
    
    let response: AuthResponse = try await APIClient.shared.request(
        endpoint: "/auth/signup",
        method: "POST",
        body: request
    )
    
    APIClient.shared.setToken(response.accessToken)
}
```

### Login
```swift
struct LoginRequest: Codable {
    let email: String
    let password: String
}

func login(email: String, password: String) async throws {
    let request = LoginRequest(email: email, password: password)
    
    let response: AuthResponse = try await APIClient.shared.request(
        endpoint: "/auth/login",
        method: "POST",
        body: request
    )
    
    APIClient.shared.setToken(response.accessToken)
}
```

---

## 📝 Questionnaire (Onboarding)

```swift
struct QuestionnaireData: Codable {
    let sport: String
    let level: String
    let mainGoal: String
    let trainingFrequency: Int
    let stressFactors: [String]
    let restQuality: Int
    let expectations: String
    let academicLoad: String?
    
    enum CodingKeys: String, CodingKey {
        case sport, level, expectations
        case mainGoal = "main_goal"
        case trainingFrequency = "training_frequency"
        case stressFactors = "stress_factors"
        case restQuality = "rest_quality"
        case academicLoad = "academic_load"
    }
}

func saveQuestionnaire(_ data: QuestionnaireData) async throws {
    let _: ProfileResponse = try await APIClient.shared.request(
        endpoint: "/profile/questionnaire",
        method: "POST",
        body: data
    )
}
```

---

## 📅 Schedule Management

### Get All Schedules
```swift
struct Schedule: Codable, Identifiable {
    let id: String
    let dayOfWeek: Int
    let startTime: String
    let endTime: String
    let type: String  // "academic" or "training"
    let title: String
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, notes, type
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

struct SchedulesResponse: Codable {
    let schedules: [Schedule]
}

func getSchedules() async throws -> [Schedule] {
    let response: SchedulesResponse = try await APIClient.shared.request(
        endpoint: "/schedules"
    )
    return response.schedules
}
```

### Create Schedule
```swift
struct CreateScheduleRequest: Codable {
    let dayOfWeek: Int
    let startTime: String
    let endTime: String
    let type: String
    let title: String
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case type, title, notes
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

func createSchedule(
    day: Int,
    start: String,
    end: String,
    type: String,
    title: String
) async throws {
    let request = CreateScheduleRequest(
        dayOfWeek: day,
        startTime: start,
        endTime: end,
        type: type,
        title: title,
        notes: nil
    )
    
    let _: ScheduleResponse = try await APIClient.shared.request(
        endpoint: "/schedules",
        method: "POST",
        body: request
    )
}
```

### Get Weekly Load
```swift
struct WeeklyLoad: Codable {
    let academicHours: Double
    let trainingHours: Double
    let totalHours: Double
    let loadLevel: String  // "low", "moderate", "high"
    let balanceRatio: Double
    
    enum CodingKeys: String, CodingKey {
        case loadLevel = "load_level"
        case balanceRatio = "balance_ratio"
        case academicHours = "academic_hours"
        case trainingHours = "training_hours"
        case totalHours = "total_hours"
    }
}

func getWeeklyLoad() async throws -> WeeklyLoad {
    return try await APIClient.shared.request(endpoint: "/schedules/weekly-load")
}
```

---

## 📖 Diary (Check-in)

### Create Entry
```swift
struct DiaryEntry: Codable {
    let date: String  // "YYYY-MM-DD"
    let mood: Int     // 1-5
    let energy: Int   // 1-5
    let stress: Int   // 1-5
    let notes: String?
    let highlights: [String]?
}

func createDiaryEntry(
    date: Date,
    mood: Int,
    energy: Int,
    stress: Int,
    notes: String? = nil,
    highlights: [String]? = nil
) async throws {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withFullDate]
    
    let entry = DiaryEntry(
        date: dateFormatter.string(from: date),
        mood: mood,
        energy: energy,
        stress: stress,
        notes: notes,
        highlights: highlights
    )
    
    let _: DiaryResponse = try await APIClient.shared.request(
        endpoint: "/diary/entries",
        method: "POST",
        body: entry
    )
}
```

### Get Weekly Summary
```swift
struct DiarySummary: Codable {
    let avgMood: Double
    let avgEnergy: Double
    let avgStress: Double
    let entriesCount: Int
    let trend: String  // "improving", "stable", "needs_attention"
    
    enum CodingKeys: String, CodingKey {
        case trend
        case avgMood = "avg_mood"
        case avgEnergy = "avg_energy"
        case avgStress = "avg_stress"
        case entriesCount = "entries_count"
    }
}

struct WeeklySummaryResponse: Codable {
    let summary: DiarySummary
}

func getWeeklySummary() async throws -> DiarySummary {
    let response: WeeklySummaryResponse = try await APIClient.shared.request(
        endpoint: "/diary/weekly-summary"
    )
    return response.summary
}
```

---

## ✅ Habits

### Get Habits
```swift
struct Habit: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let frequency: String  // "daily" or "weekly"
    let category: String?  // "mental", "physical", "recovery"
    let active: Bool
}

struct HabitsResponse: Codable {
    let habits: [Habit]
}

func getHabits() async throws -> [Habit] {
    let response: HabitsResponse = try await APIClient.shared.request(
        endpoint: "/habits"
    )
    return response.habits
}
```

### Track Habit
```swift
struct HabitTracking: Codable {
    let completed: Bool
    let date: String  // "YYYY-MM-DD"
    let notes: String?
}

func trackHabit(habitId: String, completed: Bool, date: Date) async throws {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withFullDate]
    
    let tracking = HabitTracking(
        completed: completed,
        date: dateFormatter.string(from: date),
        notes: nil
    )
    
    let _: TrackingResponse = try await APIClient.shared.request(
        endpoint: "/habits/\(habitId)/track",
        method: "POST",
        body: tracking
    )
}
```

### Get Stats
```swift
struct HabitStat: Codable {
    let habitId: String
    let title: String
    let completionRate: Double
    let completedCount: Int
    let totalDays: Int
    
    enum CodingKeys: String, CodingKey {
        case title
        case habitId = "habit_id"
        case completionRate = "completion_rate"
        case completedCount = "completed_count"
        case totalDays = "total_days"
    }
}

struct HabitStatsResponse: Codable {
    let stats: [HabitStat]
}

func getHabitStats(days: Int = 30) async throws -> [HabitStat] {
    let response: HabitStatsResponse = try await APIClient.shared.request(
        endpoint: "/habits/stats?days=\(days)"
    )
    return response.stats
}
```

---

## 🎧 Guided Sessions

### Get Session Types
```swift
struct SessionType: Codable, Identifiable {
    let id: String
    let title: String
    let duration: Int  // minutes
    let description: String
}

struct SessionTypesResponse: Codable {
    let types: [SessionType]
}

func getSessionTypes() async throws -> [SessionType] {
    let response: SessionTypesResponse = try await APIClient.shared.request(
        endpoint: "/sessions/types"
    )
    return response.types
}
```

### Complete Session
```swift
struct SessionCompletion: Codable {
    let sessionType: String
    let duration: Int
    let rating: Int?  // 1-5
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case duration, rating, notes
        case sessionType = "session_type"
    }
}

func completeSession(
    type: String,
    duration: Int,
    rating: Int? = nil
) async throws {
    let completion = SessionCompletion(
        sessionType: type,
        duration: duration,
        rating: rating,
        notes: nil
    )
    
    let _: SessionResponse = try await APIClient.shared.request(
        endpoint: "/sessions/complete",
        method: "POST",
        body: completion
    )
}
```

---

## 🤖 AI Coach

### Generate Recommendation
```swift
struct AIRecommendationRequest: Codable {
    let context: String?
    let forceRefresh: Bool
    
    enum CodingKeys: String, CodingKey {
        case context
        case forceRefresh = "force_refresh"
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

func generateRecommendation(context: String? = nil) async throws -> AIRecommendation {
    let request = AIRecommendationRequest(
        context: context,
        forceRefresh: false
    )
    
    return try await APIClient.shared.request(
        endpoint: "/ai/recommendations",
        method: "POST",
        body: request
    )
}
```

---

## 📊 Common SwiftUI Views

### Schedule View
```swift
struct ScheduleView: View {
    @State private var schedules: [Schedule] = []
    @State private var weeklyLoad: WeeklyLoad?
    
    var body: some View {
        VStack {
            if let load = weeklyLoad {
                LoadCard(load: load)
            }
            
            List(schedules) { schedule in
                ScheduleRow(schedule: schedule)
            }
        }
        .task {
            await loadData()
        }
    }
    
    func loadData() async {
        do {
            schedules = try await getSchedules()
            weeklyLoad = try await getWeeklyLoad()
        } catch {
            print("Error: \(error)")
        }
    }
}
```

### AI Coach Card
```swift
struct CoachCard: View {
    @State private var recommendation: AIRecommendation?
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu Coach Mental")
                .font(.headline)
            
            if isLoading {
                ProgressView()
            } else if let rec = recommendation {
                Text(rec.recommendation)
                    .font(.body)
            }
            
            Button("Generar Consejo") {
                Task {
                    await generateAdvice()
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    func generateAdvice() async {
        isLoading = true
        do {
            recommendation = try await generateRecommendation()
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }
}
```

---

## 🔧 Utilities

### Date Formatting
```swift
extension Date {
    func toAPIDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: self)
    }
    
    func toAPITimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

extension String {
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: self)
    }
}
```

### Keychain Helper
```swift
import Security

class KeychainHelper {
    static func save(_ data: String, forKey key: String) {
        guard let data = data.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
```

---

## 🚨 Error Handling

```swift
extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .serverError(let message):
            return message
        case .httpError(let code):
            return "Error HTTP: \(code)"
        }
    }
}

// Usage in SwiftUI
struct ContentView: View {
    @State private var errorMessage: String?
    
    func loadData() async {
        do {
            let data = try await getSchedules()
            // Use data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Error desconocido"
        }
    }
}
```

---

## 📋 Checklist for Integration

- [ ] Configure base URL
- [ ] Create API client
- [ ] Implement authentication flow
- [ ] Store tokens securely (Keychain)
- [ ] Implement auto token refresh
- [ ] Add error handling
- [ ] Create data models
- [ ] Build UI components
- [ ] Test all endpoints
- [ ] Handle offline mode
- [ ] Add loading states
- [ ] Implement pull-to-refresh
- [ ] Add analytics tracking

---

## 🔗 Quick Links

- **API Docs**: http://localhost:8001/docs
- **Base URL**: http://localhost:8001/api
- **Health Check**: http://localhost:8001/api/health

---

**Happy Coding! 🚀**
