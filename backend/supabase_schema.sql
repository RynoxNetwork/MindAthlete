-- MindAthlete Database Schema for Supabase
-- Run these commands in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    sport TEXT,
    level TEXT,
    goals TEXT[],
    stress_factors TEXT[],
    training_frequency INTEGER,
    questionnaire_data JSONB,
    questionnaire_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Schedules Table (Academic + Training)
CREATE TABLE IF NOT EXISTS schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('academic', 'training')),
    title TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Diary Entries Table
CREATE TABLE IF NOT EXISTS diary_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    mood INTEGER NOT NULL CHECK (mood >= 1 AND mood <= 5),
    energy INTEGER NOT NULL CHECK (energy >= 1 AND energy <= 5),
    stress INTEGER NOT NULL CHECK (stress >= 1 AND stress <= 5),
    notes TEXT,
    highlights TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

-- Habits Table
CREATE TABLE IF NOT EXISTS habits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly')),
    category TEXT,
    target_days INTEGER[],
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habit Tracking Table
CREATE TABLE IF NOT EXISTS habit_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    habit_id UUID REFERENCES habits(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    completed BOOLEAN NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(habit_id, date)
);

-- Session Completions Table
CREATE TABLE IF NOT EXISTS session_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_type TEXT NOT NULL,
    duration INTEGER NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    notes TEXT,
    completed_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI Recommendations Table
CREATE TABLE IF NOT EXISTS ai_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    recommendation TEXT NOT NULL,
    context JSONB,
    model TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Analytics Events Table
CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_data JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Row Level Security (RLS) Policies

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE diary_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE habit_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

-- Schedules Policies
CREATE POLICY "Users can view own schedules" ON schedules
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own schedules" ON schedules
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own schedules" ON schedules
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own schedules" ON schedules
    FOR DELETE USING (auth.uid() = user_id);

-- Diary Entries Policies
CREATE POLICY "Users can view own diary entries" ON diary_entries
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own diary entries" ON diary_entries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own diary entries" ON diary_entries
    FOR UPDATE USING (auth.uid() = user_id);

-- Habits Policies
CREATE POLICY "Users can view own habits" ON habits
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own habits" ON habits
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own habits" ON habits
    FOR UPDATE USING (auth.uid() = user_id);

-- Habit Tracking Policies
CREATE POLICY "Users can view own habit tracking" ON habit_tracking
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own habit tracking" ON habit_tracking
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own habit tracking" ON habit_tracking
    FOR UPDATE USING (auth.uid() = user_id);

-- Session Completions Policies
CREATE POLICY "Users can view own sessions" ON session_completions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON session_completions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- AI Recommendations Policies
CREATE POLICY "Users can view own recommendations" ON ai_recommendations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own recommendations" ON ai_recommendations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Analytics Events Policies
CREATE POLICY "Users can view own events" ON analytics_events
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own events" ON analytics_events
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_schedules_user_id ON schedules(user_id);
CREATE INDEX IF NOT EXISTS idx_diary_entries_user_id ON diary_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_diary_entries_date ON diary_entries(date);
CREATE INDEX IF NOT EXISTS idx_habits_user_id ON habits(user_id);
CREATE INDEX IF NOT EXISTS idx_habit_tracking_user_id ON habit_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_habit_tracking_date ON habit_tracking(date);
CREATE INDEX IF NOT EXISTS idx_session_completions_user_id ON session_completions(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_recommendations_user_id ON ai_recommendations(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_timestamp ON analytics_events(timestamp);

-- Update assessments instrument constraint to include Self-Esteem
ALTER TABLE IF EXISTS assessments
    DROP CONSTRAINT IF EXISTS assessments_instrument_check;

ALTER TABLE IF EXISTS assessments
    ADD CONSTRAINT assessments_instrument_check
    CHECK (instrument IN ('POMS', 'IDEP', 'BREVE', 'SELF_ESTEEM'));
