from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
from datetime import datetime, date, time as dt_time, timedelta
from supabase import create_client, Client
from openai import OpenAI
import os
from dotenv import load_dotenv
import json

load_dotenv()

app = FastAPI(title="MindAthlete API", version="1.0.0")

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Supabase
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_ANON_KEY")
)

# Initialize OpenAI
openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# ============ MODELS ============

class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    sport: Optional[str] = None
    level: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserProfile(BaseModel):
    full_name: Optional[str] = None
    sport: Optional[str] = None
    level: Optional[str] = None
    goals: Optional[List[str]] = None
    stress_factors: Optional[List[str]] = None
    training_frequency: Optional[int] = None
    questionnaire_data: Optional[Dict[str, Any]] = None

class QuestionnaireData(BaseModel):
    sport: str
    level: str
    main_goal: str
    training_frequency: int
    stress_factors: List[str]
    rest_quality: int
    expectations: str
    academic_load: Optional[str] = None

class ScheduleBlock(BaseModel):
    day_of_week: int  # 0=Monday, 6=Sunday
    start_time: str  # HH:MM format
    end_time: str
    type: str  # "academic" or "training"
    title: str
    notes: Optional[str] = None

class ScheduleUpdate(BaseModel):
    day_of_week: Optional[int] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    type: Optional[str] = None
    title: Optional[str] = None
    notes: Optional[str] = None

class DiaryEntry(BaseModel):
    date: str  # YYYY-MM-DD
    mood: int  # 1-5 scale
    energy: int  # 1-5 scale
    stress: int  # 1-5 scale
    notes: Optional[str] = None
    highlights: Optional[List[str]] = None

class Habit(BaseModel):
    title: str
    description: Optional[str] = None
    frequency: str  # "daily", "weekly"
    category: Optional[str] = None  # "mental", "physical", "recovery"
    target_days: Optional[List[int]] = None  # For weekly habits

class HabitTracking(BaseModel):
    completed: bool
    date: str  # YYYY-MM-DD
    notes: Optional[str] = None

class SessionCompletion(BaseModel):
    session_type: str  # "focus", "calm", "recovery", "pre-competition"
    duration: int  # minutes
    rating: Optional[int] = None  # 1-5
    notes: Optional[str] = None

class AIRecommendationRequest(BaseModel):
    context: Optional[str] = None
    force_refresh: Optional[bool] = False

class AnalyticsEvent(BaseModel):
    event_type: str
    event_data: Optional[Dict[str, Any]] = None

# ============ AUTH HELPERS ============

async def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
    
    token = authorization.replace("Bearer ", "")
    
    try:
        user = supabase.auth.get_user(token)
        if not user:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user.user
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

# ============ AUTH ENDPOINTS ============

@app.post("/api/auth/signup")
async def signup(data: SignupRequest):
    try:
        response = supabase.auth.sign_up({
            "email": data.email,
            "password": data.password
        })
        
        if response.user:
            # Create user profile
            profile_data = {
                "user_id": response.user.id,
                "email": data.email,
                "full_name": data.full_name,
                "sport": data.sport,
                "level": data.level,
                "created_at": datetime.now().isoformat()
            }
            
            supabase.table("user_profiles").insert(profile_data).execute()
            
            return {
                "user": response.user,
                "session": response.session,
                "message": "Account created successfully"
            }
        else:
            raise HTTPException(status_code=400, detail="Signup failed")
            
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/auth/login")
async def login(data: LoginRequest):
    try:
        response = supabase.auth.sign_in_with_password({
            "email": data.email,
            "password": data.password
        })
        
        return {
            "user": response.user,
            "session": response.session,
            "access_token": response.session.access_token
        }
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid credentials")

@app.get("/api/auth/me")
async def get_me(user = Depends(get_current_user)):
    try:
        profile = supabase.table("user_profiles").select("*").eq("user_id", user.id).execute()
        
        return {
            "user": user,
            "profile": profile.data[0] if profile.data else None
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ PROFILE ENDPOINTS ============

@app.put("/api/profile")
async def update_profile(profile_data: UserProfile, user = Depends(get_current_user)):
    try:
        update_data = profile_data.model_dump(exclude_unset=True)
        update_data["updated_at"] = datetime.now().isoformat()
        
        result = supabase.table("user_profiles").update(update_data).eq("user_id", user.id).execute()
        
        return {"message": "Profile updated", "profile": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/profile/questionnaire")
async def save_questionnaire(questionnaire: QuestionnaireData, user = Depends(get_current_user)):
    try:
        update_data = {
            "sport": questionnaire.sport,
            "level": questionnaire.level,
            "goals": [questionnaire.main_goal],
            "stress_factors": questionnaire.stress_factors,
            "training_frequency": questionnaire.training_frequency,
            "questionnaire_data": questionnaire.model_dump(),
            "questionnaire_completed_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        result = supabase.table("user_profiles").update(update_data).eq("user_id", user.id).execute()
        
        return {"message": "Questionnaire saved", "profile": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ SCHEDULE ENDPOINTS ============

@app.get("/api/schedules")
async def get_schedules(user = Depends(get_current_user)):
    try:
        result = supabase.table("schedules").select("*").eq("user_id", user.id).execute()
        return {"schedules": result.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/schedules")
async def create_schedule(schedule: ScheduleBlock, user = Depends(get_current_user)):
    try:
        schedule_data = schedule.model_dump()
        schedule_data["user_id"] = user.id
        schedule_data["created_at"] = datetime.now().isoformat()
        
        result = supabase.table("schedules").insert(schedule_data).execute()
        
        return {"message": "Schedule created", "schedule": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/api/schedules/{schedule_id}")
async def update_schedule(schedule_id: str, schedule: ScheduleUpdate, user = Depends(get_current_user)):
    try:
        update_data = schedule.model_dump(exclude_unset=True)
        update_data["updated_at"] = datetime.now().isoformat()
        
        result = supabase.table("schedules").update(update_data).eq("id", schedule_id).eq("user_id", user.id).execute()
        
        return {"message": "Schedule updated", "schedule": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/api/schedules/{schedule_id}")
async def delete_schedule(schedule_id: str, user = Depends(get_current_user)):
    try:
        supabase.table("schedules").delete().eq("id", schedule_id).eq("user_id", user.id).execute()
        return {"message": "Schedule deleted"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/schedules/weekly-load")
async def get_weekly_load(user = Depends(get_current_user)):
    try:
        schedules = supabase.table("schedules").select("*").eq("user_id", user.id).execute()
        
        academic_hours = 0
        training_hours = 0
        
        for schedule in schedules.data:
            # Calculate duration
            start = datetime.strptime(schedule["start_time"], "%H:%M")
            end = datetime.strptime(schedule["end_time"], "%H:%M")
            duration = (end - start).seconds / 3600
            
            if schedule["type"] == "academic":
                academic_hours += duration
            elif schedule["type"] == "training":
                training_hours += duration
        
        total_hours = academic_hours + training_hours
        
        # Determine load level
        load_level = "low"
        if total_hours > 40:
            load_level = "high"
        elif total_hours > 30:
            load_level = "moderate"
        
        return {
            "academic_hours": round(academic_hours, 1),
            "training_hours": round(training_hours, 1),
            "total_hours": round(total_hours, 1),
            "load_level": load_level,
            "balance_ratio": round(academic_hours / training_hours, 2) if training_hours > 0 else 0
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ DIARY ENDPOINTS ============

@app.get("/api/diary/entries")
async def get_diary_entries(limit: int = 30, user = Depends(get_current_user)):
    try:
        result = supabase.table("diary_entries").select("*").eq("user_id", user.id).order("date", desc=True).limit(limit).execute()
        return {"entries": result.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/diary/entries")
async def create_diary_entry(entry: DiaryEntry, user = Depends(get_current_user)):
    try:
        entry_data = entry.model_dump()
        entry_data["user_id"] = user.id
        entry_data["created_at"] = datetime.now().isoformat()
        
        # Check if entry exists for this date
        existing = supabase.table("diary_entries").select("*").eq("user_id", user.id).eq("date", entry.date).execute()
        
        if existing.data:
            # Update existing
            entry_data["updated_at"] = datetime.now().isoformat()
            result = supabase.table("diary_entries").update(entry_data).eq("id", existing.data[0]["id"]).execute()
        else:
            # Create new
            result = supabase.table("diary_entries").insert(entry_data).execute()
        
        return {"message": "Diary entry saved", "entry": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/diary/entries/{entry_date}")
async def get_diary_entry(entry_date: str, user = Depends(get_current_user)):
    try:
        result = supabase.table("diary_entries").select("*").eq("user_id", user.id).eq("date", entry_date).execute()
        
        if result.data:
            return {"entry": result.data[0]}
        else:
            return {"entry": None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/diary/weekly-summary")
async def get_weekly_summary(user = Depends(get_current_user)):
    try:
        # Get last 7 days
        week_ago = (datetime.now() - timedelta(days=7)).date().isoformat()
        
        result = supabase.table("diary_entries").select("*").eq("user_id", user.id).gte("date", week_ago).execute()
        
        if not result.data:
            return {"summary": {"avg_mood": 0, "avg_energy": 0, "avg_stress": 0, "entries_count": 0}}
        
        entries = result.data
        avg_mood = sum(e["mood"] for e in entries) / len(entries)
        avg_energy = sum(e["energy"] for e in entries) / len(entries)
        avg_stress = sum(e["stress"] for e in entries) / len(entries)
        
        return {
            "summary": {
                "avg_mood": round(avg_mood, 1),
                "avg_energy": round(avg_energy, 1),
                "avg_stress": round(avg_stress, 1),
                "entries_count": len(entries),
                "trend": "improving" if avg_mood > 3.5 else "stable" if avg_mood > 2.5 else "needs_attention"
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ HABITS ENDPOINTS ============

@app.get("/api/habits")
async def get_habits(user = Depends(get_current_user)):
    try:
        result = supabase.table("habits").select("*").eq("user_id", user.id).eq("active", True).execute()
        return {"habits": result.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/habits")
async def create_habit(habit: Habit, user = Depends(get_current_user)):
    try:
        habit_data = habit.model_dump()
        habit_data["user_id"] = user.id
        habit_data["active"] = True
        habit_data["created_at"] = datetime.now().isoformat()
        
        result = supabase.table("habits").insert(habit_data).execute()
        
        return {"message": "Habit created", "habit": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/api/habits/{habit_id}")
async def update_habit(habit_id: str, habit: Habit, user = Depends(get_current_user)):
    try:
        update_data = habit.model_dump(exclude_unset=True)
        update_data["updated_at"] = datetime.now().isoformat()
        
        result = supabase.table("habits").update(update_data).eq("id", habit_id).eq("user_id", user.id).execute()
        
        return {"message": "Habit updated", "habit": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/habits/{habit_id}/track")
async def track_habit(habit_id: str, tracking: HabitTracking, user = Depends(get_current_user)):
    try:
        tracking_data = tracking.model_dump()
        tracking_data["habit_id"] = habit_id
        tracking_data["user_id"] = user.id
        tracking_data["created_at"] = datetime.now().isoformat()
        
        # Check if tracking exists for this date
        existing = supabase.table("habit_tracking").select("*").eq("habit_id", habit_id).eq("date", tracking.date).execute()
        
        if existing.data:
            result = supabase.table("habit_tracking").update(tracking_data).eq("id", existing.data[0]["id"]).execute()
        else:
            result = supabase.table("habit_tracking").insert(tracking_data).execute()
        
        return {"message": "Habit tracked", "tracking": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/habits/stats")
async def get_habit_stats(days: int = 30, user = Depends(get_current_user)):
    try:
        start_date = (datetime.now() - timedelta(days=days)).date().isoformat()
        
        habits = supabase.table("habits").select("*").eq("user_id", user.id).eq("active", True).execute()
        
        stats = []
        for habit in habits.data:
            tracking = supabase.table("habit_tracking").select("*").eq("habit_id", habit["id"]).gte("date", start_date).execute()
            
            completed_count = sum(1 for t in tracking.data if t["completed"])
            completion_rate = (completed_count / days) * 100 if days > 0 else 0
            
            stats.append({
                "habit_id": habit["id"],
                "title": habit["title"],
                "completion_rate": round(completion_rate, 1),
                "completed_count": completed_count,
                "total_days": days
            })
        
        return {"stats": stats}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ SESSIONS ENDPOINTS ============

@app.get("/api/sessions/types")
async def get_session_types():
    return {
        "types": [
            {"id": "focus", "title": "Enfoque y Concentración", "duration": 15, "description": "Mejora tu concentración para entrenamientos y competencias"},
            {"id": "calm", "title": "Calma y Relajación", "duration": 10, "description": "Reduce el estrés y encuentra equilibrio"},
            {"id": "recovery", "title": "Recuperación Mental", "duration": 12, "description": "Optimiza tu descanso y regeneración"},
            {"id": "pre_competition", "title": "Pre-Competencia", "duration": 8, "description": "Prepárate mentalmente antes de competir"},
            {"id": "visualization", "title": "Visualización", "duration": 10, "description": "Visualiza tu éxito y rendimiento óptimo"}
        ]
    }

@app.post("/api/sessions/complete")
async def complete_session(completion: SessionCompletion, user = Depends(get_current_user)):
    try:
        session_data = completion.model_dump()
        session_data["user_id"] = user.id
        session_data["completed_at"] = datetime.now().isoformat()
        
        result = supabase.table("session_completions").insert(session_data).execute()
        
        return {"message": "Session completed", "session": result.data[0] if result.data else None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/sessions/history")
async def get_session_history(limit: int = 20, user = Depends(get_current_user)):
    try:
        result = supabase.table("session_completions").select("*").eq("user_id", user.id).order("completed_at", desc=True).limit(limit).execute()
        return {"sessions": result.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ AI COACH ENDPOINTS ============

@app.post("/api/ai/recommendations")
async def generate_recommendations(request: AIRecommendationRequest, user = Depends(get_current_user)):
    try:
        # Get user profile
        profile = supabase.table("user_profiles").select("*").eq("user_id", user.id).execute()
        profile_data = profile.data[0] if profile.data else {}
        
        # Get weekly schedule load
        schedules = supabase.table("schedules").select("*").eq("user_id", user.id).execute()
        total_hours = 0
        training_hours = 0
        academic_hours = 0
        
        for schedule in schedules.data:
            start = datetime.strptime(schedule["start_time"], "%H:%M")
            end = datetime.strptime(schedule["end_time"], "%H:%M")
            duration = (end - start).seconds / 3600
            total_hours += duration
            
            if schedule["type"] == "training":
                training_hours += duration
            else:
                academic_hours += duration
        
        # Get weekly mood summary
        week_ago = (datetime.now() - timedelta(days=7)).date().isoformat()
        diary_entries = supabase.table("diary_entries").select("*").eq("user_id", user.id).gte("date", week_ago).execute()
        
        avg_mood = 3
        avg_energy = 3
        avg_stress = 3
        
        if diary_entries.data:
            avg_mood = sum(e["mood"] for e in diary_entries.data) / len(diary_entries.data)
            avg_energy = sum(e["energy"] for e in diary_entries.data) / len(diary_entries.data)
            avg_stress = sum(e["stress"] for e in diary_entries.data) / len(diary_entries.data)
        
        # Get habit completion
        habits = supabase.table("habits").select("*").eq("user_id", user.id).eq("active", True).execute()
        habit_tracking = supabase.table("habit_tracking").select("*").eq("user_id", user.id).gte("date", week_ago).execute()
        
        habit_completion_rate = 0
        if habits.data and habit_tracking.data:
            completed = sum(1 for t in habit_tracking.data if t["completed"])
            total_possible = len(habits.data) * 7
            habit_completion_rate = (completed / total_possible * 100) if total_possible > 0 else 0
        
        # Build AI context
        sport = profile_data.get("sport", "deportista")
        level = profile_data.get("level", "universitario")
        goals = profile_data.get("goals", [])
        stress_factors = profile_data.get("stress_factors", [])
        questionnaire = profile_data.get("questionnaire_data", {})
        
        # Create prompt
        prompt = f"""Eres un coach de bienestar mental especializado en deportistas universitarios.

Perfil del atleta:
- Deporte: {sport}
- Nivel: {level}
- Objetivos: {', '.join(goals) if goals else 'mejorar rendimiento general'}
- Factores de estrés: {', '.join(stress_factors) if stress_factors else 'carga académica y competitiva'}

Carga semanal actual:
- Horas totales: {round(total_hours, 1)} horas
- Entrenamiento: {round(training_hours, 1)} horas
- Académico: {round(academic_hours, 1)} horas
- Nivel de carga: {'alto' if total_hours > 40 else 'moderado' if total_hours > 30 else 'equilibrado'}

Estado emocional (última semana):
- Ánimo promedio: {round(avg_mood, 1)}/5
- Energía promedio: {round(avg_energy, 1)}/5
- Estrés promedio: {round(avg_stress, 1)}/5
- Tendencia: {'positiva' if avg_mood > 3.5 else 'estable' if avg_mood > 2.5 else 'requiere atención'}

Hábitos:
- Tasa de cumplimiento: {round(habit_completion_rate, 1)}%

Contexto adicional: {request.context or 'N/A'}

Genera una recomendación personalizada que:
1. Sea empática y motivadora
2. Considere su carga actual y estado emocional
3. Proporcione 3 pasos concretos y accionables
4. Sea breve (máximo 150 palabras)
5. Incluya una referencia específica a su deporte o situación actual

Formato de respuesta:
[Saludo personalizado y análisis breve]

Pasos recomendados:
1. [Acción específica]
2. [Acción específica]
3. [Acción específica]

[Mensaje motivacional final]"""
        
        # Call OpenAI
        response = openai_client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "Eres un coach de bienestar mental empático y profesional especializado en deportistas universitarios. Tus recomendaciones son personalizadas, accionables y motivadoras."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=400
        )
        
        recommendation_text = response.choices[0].message.content
        
        # Save recommendation
        rec_data = {
            "user_id": user.id,
            "recommendation": recommendation_text,
            "context": {
                "mood": avg_mood,
                "energy": avg_energy,
                "stress": avg_stress,
                "total_hours": total_hours,
                "habit_completion": habit_completion_rate
            },
            "model": "gpt-4o",
            "created_at": datetime.now().isoformat()
        }
        
        supabase.table("ai_recommendations").insert(rec_data).execute()
        
        return {
            "recommendation": recommendation_text,
            "context": rec_data["context"],
            "generated_at": rec_data["created_at"]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI recommendation failed: {str(e)}")

@app.get("/api/ai/recommendations/latest")
async def get_latest_recommendation(user = Depends(get_current_user)):
    try:
        result = supabase.table("ai_recommendations").select("*").eq("user_id", user.id).order("created_at", desc=True).limit(1).execute()
        
        if result.data:
            return {"recommendation": result.data[0]}
        else:
            return {"recommendation": None}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ ANALYTICS ENDPOINTS ============

@app.post("/api/analytics/events")
async def track_event(event: AnalyticsEvent, user = Depends(get_current_user)):
    try:
        event_data = event.model_dump()
        event_data["user_id"] = user.id
        event_data["timestamp"] = datetime.now().isoformat()
        
        supabase.table("analytics_events").insert(event_data).execute()
        
        return {"message": "Event tracked"}
    except Exception as e:
        # Don't fail on analytics errors
        return {"message": "Event tracking failed", "error": str(e)}

@app.get("/api/analytics/summary")
async def get_analytics_summary(days: int = 30, user = Depends(get_current_user)):
    try:
        start_date = (datetime.now() - timedelta(days=days)).isoformat()
        
        events = supabase.table("analytics_events").select("*").eq("user_id", user.id).gte("timestamp", start_date).execute()
        
        event_counts = {}
        for event in events.data:
            event_type = event["event_type"]
            event_counts[event_type] = event_counts.get(event_type, 0) + 1
        
        return {
            "summary": {
                "total_events": len(events.data),
                "event_counts": event_counts,
                "period_days": days
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ============ HEALTH CHECK ============

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "MindAthlete API",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/")
async def root():
    return {
        "message": "MindAthlete API",
        "version": "1.0.0",
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)