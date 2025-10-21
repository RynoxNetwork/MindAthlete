-- Perfiles de usuario (extiende auth.users)
create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sport text,
  stress_triggers text,
  semester_goal text,
  motivation text,
  created_at timestamptz default now()
);

-- Diario emocional
create table if not exists public.moods (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete cascade,
  mood int check (mood between 1 and 5),
  energy int check (energy between 1 and 5),
  stress int check (stress between 1 and 5),
  notes text,
  created_at timestamptz default now()
);

-- Hábitos
create table if not exists public.habits (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete cascade,
  name text not null,
  schedule jsonb, -- p.ej. { "days": ["mon","wed","fri"] }
  active boolean default true,
  created_at timestamptz default now()
);

-- Logs de hábitos
create table if not exists public.habit_logs (
  id bigserial primary key,
  habit_id bigint references public.habits(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  done_at date not null,
  created_at timestamptz default now(),
  unique (habit_id, done_at)
);

-- Recomendaciones IA
create table if not exists public.recommendations (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete cascade,
  payload jsonb not null, -- { "title": "...", "tips": ["..."] }
  created_at timestamptz default now()
);

-- Activar Row Level Security (RLS)
alter table public.user_profiles enable row level security;
alter table public.moods enable row level security;
alter table public.habits enable row level security;
alter table public.habit_logs enable row level security;
alter table public.recommendations enable row level security;

-- Políticas de seguridad: cada usuario solo ve sus datos
create policy "own_profile" on public.user_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own_rows_moods" on public.moods
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own_rows_habits" on public.habits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own_rows_habit_logs" on public.habit_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own_rows_recommendations" on public.recommendations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
