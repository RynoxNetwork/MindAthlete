from __future__ import annotations

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any, Literal, AsyncGenerator, Tuple
from datetime import datetime, date, time as dt_time, timedelta, timezone
from supabase import create_client, Client
from openai import OpenAI
import os
from dotenv import load_dotenv
import json
import uuid
import re
from uuid import UUID
from cryptography.fernet import Fernet, InvalidToken
import logging

load_dotenv()

app = FastAPI(title="MindAthlete API", version="1.0.0")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mindathlete.api")

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
openai_api_key = os.getenv("OPENAI_API_KEY")
openai_client = OpenAI(api_key=openai_api_key) if openai_api_key else None

USE_MOCK_AI = os.getenv("USE_MOCK_AI", "0") == "1"
CHAT_MODEL = os.getenv("CHAT_MODEL", "gpt-4o-mini")
RECOMMENDATION_MODEL = os.getenv("RECOMMENDATION_MODEL", "gpt-4o-mini")
HABIT_PLAN_MODEL = os.getenv("HABIT_PLAN_MODEL", "gpt-4o-mini")
CHAT_DAILY_FREE_LIMIT = int(os.getenv("CHAT_DAILY_FREE_LIMIT", "10"))
CHAT_RETENTION_DAYS = int(os.getenv("CHAT_RETENTION_DAYS", "90"))
HABIT_PLAN_FREE_COOLDOWN_DAYS = int(os.getenv("HABIT_PLAN_FREE_COOLDOWN_DAYS", "21"))
SPORTS_PSYCHOLOGY_BOOKING_URL = os.getenv("SPORTS_PSYCHOLOGY_BOOKING_URL")
DATA_RETENTION_DAYS = int(os.getenv("DATA_RETENTION_DAYS", str(CHAT_RETENTION_DAYS)))
CHAT_ENCRYPTION_KEY = os.getenv("CHAT_ENCRYPTION_KEY")


class EncryptionHelper:
    def __init__(self, raw_key: Optional[str]):
        self._fernet: Optional[Fernet]
        if raw_key:
            try:
                self._fernet = Fernet(raw_key)
            except (ValueError, InvalidToken) as exc:
                logger.warning("Invalid CHAT_ENCRYPTION_KEY provided: %s", exc)
                self._fernet = None
        else:
            self._fernet = None

    def encrypt(self, text: Optional[str]) -> Optional[str]:
        if not text:
            return text
        if not self._fernet:
            return text
        return self._fernet.encrypt(text.encode("utf-8")).decode("utf-8")

    def decrypt(self, token: Optional[str]) -> Optional[str]:
        if not token:
            return token
        if not self._fernet:
            return token
        try:
            return self._fernet.decrypt(token.encode("utf-8")).decode("utf-8")
        except InvalidToken:
            logger.error("Failed to decrypt payload; returning masked content.")
            return "[unavailable]"


encryption_helper = EncryptionHelper(CHAT_ENCRYPTION_KEY)

EMAIL_PATTERN = re.compile(r"[\w\.-]+@[\w\.-]+")
PHONE_PATTERN = re.compile(r"\+?\d[\d\s\-\(\)]{7,}\d")


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def sanitize_text(text: str) -> str:
    masked = EMAIL_PATTERN.sub("[email]", text)
    masked = PHONE_PATTERN.sub("[phone]", masked)
    return masked


def isoformat(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat()


def determine_subscription_tier(user_id: str) -> str:
    try:
        response = supabase.table("entitlements").select("*").eq("user_id", user_id).eq("active", True).execute()
        for entitlement in response.data or []:
            product = (entitlement or {}).get("product", "")
            if product and "premium" in product.lower():
                return "premium"
    except Exception as exc:
        logger.warning("Failed to determine subscription tier for %s: %s", user_id, exc)
    return "free"


def ensure_chat_quota(user_id: str, tier: str) -> None:
    if tier == "premium":
        return
    start_of_day = utc_now().replace(hour=0, minute=0, second=0, microsecond=0)
    try:
        response = supabase.table("chat_messages") \
            .select("id") \
            .eq("user_id", user_id) \
            .eq("role", "user") \
            .gte("created_at", start_of_day.isoformat()) \
            .execute()
        total = len(response.data or [])
        if total >= CHAT_DAILY_FREE_LIMIT:
            raise HTTPException(
                status_code=402,
                detail=f"Daily chat limit reached. Upgrade to premium for unlimited conversations."
            )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Quota check failed for %s: %s", user_id, exc)


def enforce_habit_plan_cooldown(user_id: str, tier: str) -> None:
    if tier == "premium":
        return
    cutoff = utc_now() - timedelta(days=HABIT_PLAN_FREE_COOLDOWN_DAYS)
    try:
        response = supabase.table("habit_plans") \
            .select("id, created_at") \
            .eq("user_id", user_id) \
            .eq("source", "AI") \
            .gte("created_at", cutoff.isoformat()) \
            .order("created_at", desc=True) \
            .limit(1) \
            .execute()
        if response.data:
            raise HTTPException(
                status_code=402,
                detail="Habit plan recently generated. Try again later or upgrade for unlimited plans."
            )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Habit plan cooldown check failed for %s: %s", user_id, exc)


def apply_retention_policies(user_id: str) -> None:
    cutoff = utc_now() - timedelta(days=DATA_RETENTION_DAYS)
    try:
        supabase.table("chat_messages") \
            .delete() \
            .eq("user_id", user_id) \
            .lt("created_at", cutoff.isoformat()) \
            .execute()
    except Exception as exc:
        logger.warning("Retention cleanup skipped for %s: %s", user_id, exc)


def extract_response_text(response: Any) -> str:
    chunks: List[str] = []
    outputs = getattr(response, "output", None)
    if outputs:
        for output in outputs:
            for content in getattr(output, "content", []) or []:
                if getattr(content, "type", None) == "text" and hasattr(content, "text"):
                    chunks.append(content.text)
                elif hasattr(content, "text"):
                    chunks.append(str(content.text))
    else:
        choices = getattr(response, "choices", None)
        if choices:
            for choice in choices:
                message = getattr(choice, "message", None)
                if message:
                    if isinstance(message, dict) and "content" in message:
                        chunks.append(message["content"])
                    elif hasattr(message, "content"):
                        chunks.append(str(message.content))
        raw = getattr(response, "output", None) or getattr(response, "content", None)
        if raw and isinstance(raw, (str, bytes)):
            chunks.append(raw.decode("utf-8") if isinstance(raw, bytes) else raw)
    return "".join(chunks).strip()


def chunk_text(text: str, size: int = 200) -> List[str]:
    if not text:
        return []
    return [text[i:i + size] for i in range(0, len(text), size)]


def parse_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        normalized = value.replace("Z", "+00:00")
        return datetime.fromisoformat(normalized)
    except ValueError:
        return None


def fetch_events_for_day(user_id: str, target_date: date) -> List[Dict[str, Any]]:
    day_start = datetime.combine(target_date, dt_time.min, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)
    try:
        response = supabase.table("events") \
            .select("*") \
            .eq("user_id", user_id) \
            .gte("starts_at", day_start.isoformat()) \
            .lt("starts_at", day_end.isoformat()) \
            .order("starts_at", desc=False) \
            .execute()
        events: List[Dict[str, Any]] = []
        for event in response.data or []:
            events.append({
                "id": event.get("id"),
                "title": event.get("title"),
                "kind": event.get("kind"),
                "starts_at": parse_datetime(event.get("starts_at")),
                "ends_at": parse_datetime(event.get("ends_at")) or parse_datetime(event.get("starts_at")),
                "notes": event.get("notes"),
            })
        return events
    except Exception as exc:
        logger.error("Failed to load events for %s on %s: %s", user_id, target_date, exc)
        return []


def compute_free_slots(events: List[Dict[str, Any]], day_start: datetime, day_end: datetime) -> List[Tuple[datetime, datetime]]:
    cursor = day_start
    free: List[Tuple[datetime, datetime]] = []
    for event in sorted(events, key=lambda e: e.get("starts_at") or day_start):
        start = event.get("starts_at") or day_start
        end = event.get("ends_at") or start
        if start > cursor:
            free.append((cursor, min(start, day_end)))
        cursor = max(cursor, end if end else cursor)
    if cursor < day_end:
        free.append((cursor, day_end))
    return [slot for slot in free if (slot[1] - slot[0]).total_seconds() >= 15 * 60]


class AgendaRecommendationAgent:
    def __init__(self, client: Optional[OpenAI], model: str, use_mock: bool):
        self.client = client
        self.model = model
        self.use_mock = use_mock or client is None

    def generate(self, user_id: str, target_date: date, tier: str, events: List[Dict[str, Any]]) -> DailyRecommendationResponse:
        day_start = datetime.combine(target_date, dt_time.min, tzinfo=timezone.utc)
        day_end = day_start + timedelta(days=1)
        free_slots = compute_free_slots(events, day_start, day_end)
        event_context = [
            {
                "title": event.get("title"),
                "kind": event.get("kind"),
                "start": (event.get("starts_at") or day_start).isoformat(),
                "end": (event.get("ends_at") or day_start).isoformat(),
                "notes": event.get("notes"),
            }
            for event in events
        ]

        if self.use_mock:
            recommendations = [
                "Programa una respiración cuadrada de 4 minutos en tu primer bloque libre.",
                "Visualiza el entrenamiento clave del día y escribe un objetivo específico."
            ]
            if any(e.get("kind") == "competencia" for e in events):
                recommendations.append("Prepara un ritual de precompetencia 60 minutos antes del evento.")
            rationale = "Basado en tu agenda y tier {}, priorizamos micro-recuperación y foco competitivo.".format(tier)
            return DailyRecommendationResponse(
                recommendations=recommendations,
                rationale=rationale,
                event_context=event_context,
                escalate=False,
                model_version="mock-2024.11"
            )

        payload = {
            "date": target_date.isoformat(),
            "tier": tier,
            "events": event_context,
            "free_slots": [
                {
                    "start": slot[0].isoformat(),
                    "end": slot[1].isoformat(),
                    "minutes": int((slot[1] - slot[0]).total_seconds() // 60)
                }
                for slot in free_slots
            ]
        }
        system_prompt = (
            "Eres el agente de agenda de MindAthlete. Tu tarea es analizar la agenda diaria, "
            "detectar espacios libres y proponer recomendaciones breves, accionables y en español neutro. "
            "Respeta el tier del usuario (free limitado, premium sin restricciones) y evita repetir sugerencias. "
            "Responde únicamente en JSON con este formato: "
            '{"recommendations": [strings], "rationale": "string", "event_context": [...], "escalate": boolean}. '
            "Incluye una recomendación que se ajuste a algún bloque libre cuando exista."
        )

        try:
            response = self.client.responses.create(
                model=self.model,
                input=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": json.dumps(payload, ensure_ascii=False)}
                ],
            )
            content = extract_response_text(response)
            data = {}
            if content:
                try:
                    data = json.loads(content)
                except json.JSONDecodeError:
                    logger.warning("AI recommendation returned non-JSON content; using heuristic parsing.")
                    data = {}
            recommendations = data.get("recommendations") or []
            rationale = data.get("rationale")
            escalate = bool(data.get("escalate"))
            ctx = data.get("event_context") or event_context
            return DailyRecommendationResponse(
                recommendations=recommendations if isinstance(recommendations, list) else [str(recommendations)],
                rationale=rationale,
                event_context=ctx,
                escalate=escalate,
                model_version=self.model
            )
        except Exception as exc:
            logger.error("AI recommendation failed for %s: %s", user_id, exc)
            fallback = DailyRecommendationResponse(
                recommendations=[
                    "Reserva 5 minutos para una respiración 4-7-8 antes de tu próxima actividad.",
                    "Escribe un objetivo SMART para tu sesión principal del día."
                ],
                rationale="Falla temporal del modelo: usando heurísticas locales.",
                event_context=event_context,
                escalate=False,
                model_version="fallback-heuristic"
            )
            return fallback


class CoachChatAgent:
    def __init__(self, client: Optional[OpenAI], model: str, use_mock: bool):
        self.client = client
        self.model = model
        self.use_mock = use_mock or client is None

    def _system_prompt(self, tone: Optional[str]) -> str:
        tone_descriptor = tone or "empathetic"
        return (
            "Eres Kai, el coach IA de MindAthlete con formación en psicología deportiva. "
            "Adopta un tono {} y evita diagnósticos clínicos. "
            "Proporciona estrategias concretas, referencias a rutinas de la app y refuerza la autonomía del atleta. "
            "Siempre responde en JSON plano y válido con esta estructura exacta: "
            "{{\"reply\": \"texto motivacional y práctico\", \"escalate\": false, \"habit_hint\": \"opcional\"}}. "
            "Si no puedes cumplir la solicitud, indica un mensaje empático y marca \\\"escalate\\\": false."
        ).format(tone_descriptor)

    def generate_reply(self, messages: List[CoachChatMessage], tone: Optional[str], target_goal: Optional[str]) -> Dict[str, Any]:
        conversation_payload = [
            {"role": message.role, "content": sanitize_text(message.content)}
            for message in messages
        ]
        if target_goal:
            conversation_payload.append({"role": "user", "content": f"Objetivo declarado: {target_goal}"})

        if self.use_mock:
            reply = (
                "Gracias por compartirlo. Prueba el protocolo de respiración triangular durante 3 minutos "
                "antes de tu siguiente sesión y registra cómo te sientes."
            )
            escalate = any("ansiedad" in msg.content.lower() for msg in messages if msg.role == "user")
            habit_hint = "Respiración triangular antes de entrenar" if escalate else None
            return {"reply": reply, "escalate": escalate, "habit_hint": habit_hint, "model": "mock-2024.11"}

        try:
            response = self.client.responses.create(
                model=self.model,
                input=[
                    {"role": "system", "content": self._system_prompt(tone)},
                    *conversation_payload
                ],
                max_output_tokens=600
            )
            content = extract_response_text(response)
            payload: Dict[str, Any] = {}
            if content:
                try:
                    payload = json.loads(content)
                except json.JSONDecodeError:
                    logger.warning("Chat agent returned non-JSON content: %s", content)
                    payload = {"reply": content, "escalate": False, "habit_hint": None}
            if not isinstance(payload, dict):
                logger.warning("Chat agent returned non-dict payload: %s", payload)
                payload = {"reply": str(payload), "escalate": False, "habit_hint": None}
            payload["model"] = self.model
            return payload
        except Exception as exc:
            logger.error("Chat agent failure: %s", exc, exc_info=True)
            return {
                "reply": "Estoy teniendo dificultades técnicas. Respira profundo y volvamos a intentarlo en unos minutos.",
                "escalate": False,
                "habit_hint": None,
                "model": "fallback-heuristic"
            }


class HabitPlanAgent:
    def __init__(self, client: Optional[OpenAI], model: str, use_mock: bool):
        self.client = client
        self.model = model
        self.use_mock = use_mock or client is None

    def generate(self, timeframe: str, context: Dict[str, Any], tier: str) -> HabitPlanResponse:
        payload = {
            "timeframe": timeframe,
            "context": context,
            "tier": tier
        }

        if self.use_mock:
            habits = [
                HabitPlanItem(title="Respiración 4-7-8", recommended_start_date=date.today(), frequency="daily", rationale="Bajar activación pre-entrenamiento"),
                HabitPlanItem(title="Diario de gratitud", recommended_start_date=date.today(), frequency="daily", rationale="Reforzar enfoque positivo"),
                HabitPlanItem(title="Visualización guiada", recommended_start_date=date.today() + timedelta(days=2), frequency="3x week", rationale="Preparar competencias próximas")
            ]
            return HabitPlanResponse(
                habits=habits,
                summary="Plan breve generado localmente por falta de modelo."
            )

        system_prompt = (
            "Eres el agente planificador de hábitos de MindAthlete. Crea planes accionables, "
            "máximo 5 hábitos, con título, fecha recomendada, frecuencia y racional. "
            "Respeta el tier del usuario (free: prioriza 2 hábitos esenciales). "
            "Responde en JSON coincidiendo con {'habits': [...], 'summary': '...'}."
        )

        try:
            response = self.client.responses.create(
                model=self.model,
                input=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": json.dumps(payload, ensure_ascii=False)}
                ],
                max_output_tokens=700
            )
            content = extract_response_text(response)
            data: Dict[str, Any] = {}
            if content:
                try:
                    data = json.loads(content)
                except json.JSONDecodeError:
                    logger.warning("Habit plan agent returned non-JSON content.")
                    data = {}
            if not isinstance(data, dict):
                logger.warning("Habit plan agent returned non-dict payload: %s", data)
                data = {}
            habits_payload = data.get("habits") or []
            habits: List[HabitPlanItem] = []
            for item in habits_payload:
                recommended = item.get("recommended_start_date")
                parsed = parse_datetime(recommended) if recommended else None
                start_date = parsed.date() if parsed else None
                habits.append(
                    HabitPlanItem(
                        title=item.get("title", "Hábito"),
                        recommended_start_date=start_date,
                        frequency=item.get("frequency", "daily"),
                        rationale=item.get("rationale")
                    )
                )
            if tier == "free" and len(habits) > 2:
                habits = habits[:2]
            return HabitPlanResponse(
                habits=habits,
                summary=data.get("summary")
            )
        except Exception as exc:
            logger.error("Habit plan agent failure: %s", exc)
            return HabitPlanResponse(
                habits=[
                    HabitPlanItem(
                        title="Chequeo de respiración matutina",
                        recommended_start_date=date.today(),
                        frequency="daily",
                        rationale="Mantener estabilidad emocional"
                    )
                ],
                summary="No se pudo generar plan completo; sugerencia mínima."
            )


class EscalationAgent:
    def decide(self, payload: EscalationRequest, tier: str) -> EscalationResponse:
        context = payload.context or {}
        reason = payload.reason or context.get("reason")
        stress_score = context.get("stress_score") or context.get("poms_total")
        flagged = context.get("flags") or []
        escalate = False

        if isinstance(stress_score, (int, float)) and stress_score >= 65:
            escalate = True
        if any(flag in ("high_anxiety", "self_doubt", "panic") for flag in flagged):
            escalate = True
        if reason and any(term in reason.lower() for term in ["ansiedad", "crisis", "bloqueo", "panic"]):
            escalate = True

        if tier == "free":
            # Only escalate if high severity flagged explicitly
            escalate = escalate and any(flag in ("high_anxiety", "panic") for flag in flagged) or (stress_score and stress_score >= 75)

        if not escalate:
            return EscalationResponse(
                escalate=False,
                booking_url=None,
                message="Se registró el evento; continúa con el plan de autocuidado."
            )

        return EscalationResponse(
            escalate=True,
            booking_url=SPORTS_PSYCHOLOGY_BOOKING_URL,
            message="Recomendamos agendar una sesión con un psicólogo deportivo."
        )


agenda_agent = AgendaRecommendationAgent(openai_client, RECOMMENDATION_MODEL, USE_MOCK_AI)
chat_agent = CoachChatAgent(openai_client, CHAT_MODEL, USE_MOCK_AI)
habit_plan_agent = HabitPlanAgent(openai_client, HABIT_PLAN_MODEL, USE_MOCK_AI)
escalation_agent = EscalationAgent()


def get_or_create_chat(user_id: str, chat_id: Optional[UUID], title: Optional[str] = None) -> UUID:
    if chat_id:
        try:
            response = supabase.table("chats") \
                .select("id") \
                .eq("id", str(chat_id)) \
                .eq("user_id", user_id) \
                .limit(1) \
                .execute()
            if response.data:
                return UUID(response.data[0]["id"])
        except Exception as exc:
            logger.warning("Existing chat lookup failed: %s", exc)
    insert_payload = {
        "user_id": user_id,
        "title": title or "Sesión con Kai",
        "last_message_at": utc_now().isoformat(),
        "message_count": 0,
        "is_active": True
    }
    try:
        result = supabase.table("chats").insert(insert_payload).execute()
        if result.data:
            return UUID(result.data[0]["id"])
    except Exception as exc:
        logger.error("Failed to create chat for %s: %s", user_id, exc)
    raise HTTPException(status_code=500, detail="No se pudo iniciar una conversación.")


def record_chat_message(chat_id: UUID, user_id: str, role: str, content: str, metadata: Optional[Dict[str, Any]] = None) -> None:
    encrypted_content = encryption_helper.encrypt(sanitize_text(content))
    payload = {
        "chat_id": str(chat_id),
        "user_id": user_id,
        "role": role,
        "content": encrypted_content,
        "metadata": metadata,
        "created_at": utc_now().isoformat()
    }
    try:
        supabase.table("chat_messages").insert(payload).execute()
        count_response = supabase.table("chat_messages") \
            .select("id") \
            .eq("chat_id", str(chat_id)) \
            .execute()
        supabase.table("chats") \
            .update({
                "last_message_at": utc_now().isoformat(),
                "message_count": len(count_response.data or []),
                "updated_at": utc_now().isoformat()
            }) \
            .eq("id", str(chat_id)) \
            .execute()
    except Exception as exc:
        logger.error("Failed to persist chat message for %s: %s", user_id, exc)


def record_habit_plan(user_id: str, plan: HabitPlanResponse, timeframe: str) -> None:
    plan_payload = {
        "habits": [
            {
                "title": item.title,
                "recommended_start_date": item.recommended_start_date.isoformat() if item.recommended_start_date else None,
                "frequency": item.frequency,
                "rationale": item.rationale
            }
            for item in plan.habits
        ],
        "summary": plan.summary,
        "timeframe": timeframe
    }
    payload = {
        "user_id": user_id,
        "plan_json": plan_payload,
        "summary": plan.summary,
        "source": "AI",
        "is_active": True,
        "created_at": utc_now().isoformat(),
        "updated_at": utc_now().isoformat()
    }
    try:
        supabase.table("habit_plans").insert(payload).execute()
    except Exception as exc:
        logger.error("Failed to store habit plan for %s: %s", user_id, exc)


def record_escalation(user_id: str, request: EscalationRequest, decision: EscalationResponse) -> None:
    payload = {
        "user_id": user_id,
        "reason": request.reason or request.context.get("reason", "auto_flag"),
        "context": request.context,
        "status": "scheduled" if decision.escalate else "dismissed",
        "booking_url": decision.booking_url,
        "created_at": utc_now().isoformat(),
        "updated_at": utc_now().isoformat(),
        "source": request.context.get("source")
    }
    try:
        supabase.table("escalations").insert(payload).execute()
    except Exception as exc:
        logger.error("Failed to persist escalation for %s: %s", user_id, exc)


def record_daily_recommendation(user_id: str, target_date: date, recommendation: DailyRecommendationResponse) -> None:
    try:
        first_message = recommendation.recommendations[0] if recommendation.recommendations else None
        payload = {
            "user_id": user_id,
            "context": json.dumps({"date": target_date.isoformat()}, ensure_ascii=False),
            "reason": {"rationale": recommendation.rationale, "event_context": recommendation.event_context},
            "message": first_message,
            "created_at": utc_now().isoformat()
        }
        supabase.table("recommendations").insert(payload).execute()
    except Exception as exc:
        logger.warning("Failed to store recommendation for %s: %s", user_id, exc)

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


class RecommendationEventContext(BaseModel):
    title: str
    starts_at: datetime
    ends_at: Optional[datetime] = None
    kind: Optional[str] = None
    notes: Optional[str] = None


class DailyRecommendationRequest(BaseModel):
    user_id: Optional[str] = None
    date: date
    force_refresh: Optional[bool] = False
    include_competitions: Optional[bool] = True
    include_training: Optional[bool] = True


class DailyRecommendationResponse(BaseModel):
    recommendations: List[str]
    rationale: Optional[str] = None
    event_context: List[Dict[str, Any]] = Field(default_factory=list)
    escalate: Optional[bool] = False
    model_version: str = "manual"


class CoachChatMessage(BaseModel):
    role: Literal["user", "assistant", "system"]
    content: str


class CoachChatRequest(BaseModel):
    user_id: Optional[str] = None
    chat_id: Optional[UUID] = None
    messages: List[CoachChatMessage]
    tone: Optional[str] = "empathetic"
    target_goal: Optional[str] = None


class HabitPlanItem(BaseModel):
    title: str
    recommended_start_date: Optional[date] = None
    frequency: str
    rationale: Optional[str] = None


class HabitPlanResponse(BaseModel):
    habits: List[HabitPlanItem]
    summary: Optional[str] = None


class HabitPlanRequest(BaseModel):
    user_id: Optional[str] = None
    timeframe: Optional[str] = Field(default="next 7 days", description="Free-form timeframe description")
    context: Optional[Dict[str, Any]] = None


class EscalationRequest(BaseModel):
    user_id: Optional[str] = None
    context: Dict[str, Any]
    reason: Optional[str] = None


class EscalationResponse(BaseModel):
    escalate: bool
    booking_url: Optional[str] = None
    message: Optional[str] = None

# ============ AUTH HELPERS ============

async def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
    
    token = authorization.replace("Bearer ", "")
    
    try:
        user = supabase.auth.get_user(token)
        if not user:
            raise HTTPException(status_code=401, detail="Invalid token")
        supabase.postgrest.auth(token)
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

# ============ AI COACH ENDPOINTS ============

@app.post("/api/recommendations/daily", response_model=DailyRecommendationResponse)
async def generate_daily_recommendation_endpoint(payload: DailyRecommendationRequest, user = Depends(get_current_user)):
    if payload.user_id and payload.user_id != user.id:
        raise HTTPException(status_code=403, detail="No autorizado para solicitar datos de otro usuario.")
    target_date = payload.date
    tier = determine_subscription_tier(user.id)
    apply_retention_policies(user.id)
    events = fetch_events_for_day(user.id, target_date)
    if payload.include_competitions is False:
        events = [event for event in events if event.get("kind") != "competencia"]
    if payload.include_training is False:
        events = [event for event in events if event.get("kind") != "entreno"]
    recommendation = agenda_agent.generate(user.id, target_date, tier, events)
    record_daily_recommendation(user.id, target_date, recommendation)
    return recommendation


@app.post("/api/coach/chat")
async def coach_chat(payload: CoachChatRequest, user = Depends(get_current_user)):
    if payload.user_id and payload.user_id != user.id:
        raise HTTPException(status_code=403, detail="No autorizado para solicitar datos de otro usuario.")
    if not payload.messages:
        raise HTTPException(status_code=400, detail="Se requiere al menos un mensaje.")

    tier = determine_subscription_tier(user.id)
    ensure_chat_quota(user.id, tier)
    apply_retention_policies(user.id)

    latest_user_message = next((m for m in reversed(payload.messages) if m.role == "user"), None)
    chat_id = get_or_create_chat(user.id, payload.chat_id, title=latest_user_message.content[:80] if latest_user_message else None)

    if latest_user_message:
        record_chat_message(chat_id, user.id, "user", latest_user_message.content, {"source": "app"})

    agent_result = chat_agent.generate_reply(payload.messages, payload.tone, payload.target_goal)
    reply_text = agent_result.get("reply", "")
    escalate_flag = bool(agent_result.get("escalate"))
    habit_hint = agent_result.get("habit_hint")

    metadata = {
        "model": agent_result.get("model"),
        "habit_hint": habit_hint,
        "escalate": escalate_flag
    }
    record_chat_message(chat_id, user.id, "assistant", reply_text, metadata)

    if escalate_flag:
        escalation_payload = EscalationRequest(
            user_id=user.id,
            context={
                "source": "chat",
                "reason": "ai_flag",
                "habit_hint": habit_hint,
                "last_user_message": latest_user_message.content if latest_user_message else None
            },
            reason="ai_flag"
        )
        decision = EscalationResponse(
            escalate=True,
            booking_url=SPORTS_PSYCHOLOGY_BOOKING_URL,
            message="Kai detectó marcadores de estrés elevado."
        )
        record_escalation(user.id, escalation_payload, decision)

    def iterator():
        for chunk in chunk_text(reply_text, size=220):
            yield (json.dumps({
                "chat_id": str(chat_id),
                "delta": chunk,
                "finished": False
            }) + "\n").encode("utf-8")
        yield (json.dumps({
            "chat_id": str(chat_id),
            "finished": True,
            "escalate": escalate_flag,
            "habit_hint": habit_hint,
            "booking_url": SPORTS_PSYCHOLOGY_BOOKING_URL if escalate_flag else None,
            "model": agent_result.get("model")
        }) + "\n").encode("utf-8")

    headers = {"Cache-Control": "no-store"}
    return StreamingResponse(iterator(), media_type="application/json", headers=headers)


@app.post("/api/coach/habit-plan", response_model=HabitPlanResponse)
async def generate_habit_plan_endpoint(payload: HabitPlanRequest, user = Depends(get_current_user)):
    if payload.user_id and payload.user_id != user.id:
        raise HTTPException(status_code=403, detail="No autorizado para solicitar datos de otro usuario.")
    tier = determine_subscription_tier(user.id)
    enforce_habit_plan_cooldown(user.id, tier)
    timeframe = payload.timeframe or "next 7 days"
    context = payload.context or {}
    plan = habit_plan_agent.generate(timeframe, context, tier)
    record_habit_plan(user.id, plan, timeframe)
    return plan


@app.post("/api/escalate", response_model=EscalationResponse)
async def escalate(payload: EscalationRequest, user = Depends(get_current_user)):
    if payload.user_id and payload.user_id != user.id:
        raise HTTPException(status_code=403, detail="No autorizado para solicitar datos de otro usuario.")
    tier = determine_subscription_tier(user.id)
    decision = escalation_agent.decide(payload, tier)
    record_escalation(user.id, payload, decision)
    return decision

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
