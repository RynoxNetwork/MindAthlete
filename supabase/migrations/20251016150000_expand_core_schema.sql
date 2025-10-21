-- Ensure pgcrypto extension for gen_random_uuid
create extension if not exists "pgcrypto";

-- Align user_profiles with auth.users
alter table public.user_profiles
  add column if not exists user_id uuid;

alter table public.user_profiles
  drop constraint if exists user_profiles_user_id_fk;

alter table public.user_profiles
  add constraint user_profiles_user_id_fk
  foreign key (user_id) references auth.users(id) on delete cascade;

update public.user_profiles p
set user_id = u.id
from auth.users u
where lower(u.email) = lower(p.email)
  and p.user_id is null;

alter table public.user_profiles
  alter column user_id set not null;

alter table public.user_profiles
  drop constraint if exists user_profiles_user_id_unique;

alter table public.user_profiles
  add constraint user_profiles_user_id_unique unique (user_id);

alter table public.user_profiles enable row level security;

drop policy if exists "User can SELECT own profile" on public.user_profiles;
drop policy if exists "User can INSERT own profile" on public.user_profiles;
drop policy if exists "User can UPDATE own profile" on public.user_profiles;
drop policy if exists "User can DELETE own profile" on public.user_profiles;
drop policy if exists up_select on public.user_profiles;
drop policy if exists up_crud on public.user_profiles;

create policy up_select on public.user_profiles
  for select using (user_id = auth.uid());

create policy up_crud on public.user_profiles
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Core tables
create table if not exists public.intervention_prefs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  modality text check (modality in ('texto','audio','video')) default 'texto',
  preferred_slots int4[] default '{}',
  max_suggestions_per_day int2 not null default 3,
  do_not_disturb_hours int4[] default '{22,23,0,1,2,3}',
  tone text default 'empatico_no_patologizante',
  created_at timestamptz default now()
);

create unique index if not exists intervention_prefs_user_id_idx
  on public.intervention_prefs(user_id);

create table if not exists public.external_calendars (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('google','notion')),
  account_email text,
  access_token text,
  refresh_token text,
  sync_enabled boolean default true,
  last_sync_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists public.availability_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  source text not null check (source in ('computed','manual')),
  created_at timestamptz default now()
);

create table if not exists public.sleep_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  target_wake_time time,
  cycles int2 default 5,
  buffer_minutes int2 default 15,
  updated_at timestamptz default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  kind text check (kind in ('clase','entreno','competencia','examen','otro')) default 'otro',
  starts_at timestamptz not null,
  ends_at timestamptz,
  notes text,
  created_at timestamptz default now()
);

alter table public.moods
  add column if not exists energy int2,
  add column if not exists stress int2,
  add column if not exists focus int2,
  add column if not exists trigger text,
  add column if not exists sleep_hours numeric(4,2),
  add column if not exists sleep_quality int2;

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text,
  active boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  performed_at timestamptz not null default now(),
  adherence int2 check (adherence between 0 and 100),
  notes text
);

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  duration_sec int not null,
  modality text check (modality in ('audio','texto','video')) not null,
  context_tags text[] default '{}',
  premium boolean not null default false,
  content jsonb not null,
  created_at timestamptz default now()
);

create table if not exists public.session_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null references public.sessions(id) on delete cascade,
  started_at timestamptz not null default now(),
  pre_stress int2 check (pre_stress between 0 and 10),
  pre_focus int2 check (pre_focus between 0 and 10),
  finished_at timestamptz,
  post_stress int2 check (post_stress between 0 and 10),
  post_focus int2 check (post_focus between 0 and 10),
  delta_stress int2 generated always as (coalesce(pre_stress,0) - coalesce(post_stress,0)) stored,
  delta_focus int2 generated always as (coalesce(post_focus,0) - coalesce(pre_focus,0)) stored
);

create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  instrument text check (instrument in ('POMS','IDEP','BREVE')) not null,
  taken_at timestamptz not null default now(),
  summary jsonb,
  kind text check (kind in ('IMA','POMS')) default 'IMA'
);

alter table public.assessments
  add column if not exists kind text;

alter table public.assessments
  alter column kind set default 'IMA';

alter table public.assessments
  drop constraint if exists assessments_kind_check;

alter table public.assessments
  add constraint assessments_kind_check check (kind in ('IMA','POMS'));

create table if not exists public.assessment_items (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  subscale text not null,
  item_code text,
  raw int2 not null,
  normalized numeric(5,2)
);

create table if not exists public.coach_policies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  max_suggestions_per_day int2 not null default 3,
  priority_policy text default 'context_first_then_thresholds',
  route_context jsonb not null,
  poms_thresholds jsonb,
  conflict_policy text default 'safety_over_performance',
  durations jsonb default jsonb_build_object('micro', ARRAY[60,90], 'breve', ARRAY[180,240], 'completa', ARRAY[480,600]),
  escalation_threshold jsonb,
  created_at timestamptz default now()
);

create unique index if not exists coach_policies_user_id_idx
  on public.coach_policies(user_id);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  body text not null,
  tags text[] default '{}',
  sentiment int2,
  intent jsonb,
  created_at timestamptz default now()
);

create table if not exists public.daily_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action_date date not null,
  code text not null,
  title text not null,
  source text not null check (source in ('ai','rule','manual')),
  is_checked boolean default false,
  created_at timestamptz default now(),
  unique(user_id, action_date, code)
);

create table if not exists public.recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  context text,
  reason jsonb,
  session_id uuid references public.sessions(id),
  habit_id uuid references public.habits(id),
  message text,
  created_at timestamptz default now()
);

create table if not exists public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product text not null,
  active boolean not null default false,
  source text,
  updated_at timestamptz default now()
);

-- Enable RLS and policies
do $$
declare
  t text;
begin
  foreach t in array array['intervention_prefs','external_calendars','availability_blocks','sleep_prefs','events','moods','habits','session_metrics','assessments','coach_policies','journal_entries','recommendations','entitlements','daily_actions']
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists %I_sel on public.%I;', t||'_sel', t);
    execute format('drop policy if exists %I_crud on public.%I;', t||'_crud', t);
    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = t
        and policyname = t||'_sel'
    ) then
      execute format('create policy %I on public.%I for select using (user_id = auth.uid());', t||'_sel', t);
    end if;

    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = t
        and policyname = t||'_crud'
    ) then
      execute format('create policy %I on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid());', t||'_crud', t);
    end if;
  end loop;
end $$;

alter table public.sessions enable row level security;
drop policy if exists sessions_read_all on public.sessions;
create policy sessions_read_all on public.sessions for select using (true);

alter table public.habit_logs enable row level security;
drop policy if exists habit_logs_sel on public.habit_logs;
drop policy if exists habit_logs_crud on public.habit_logs;

create policy habit_logs_sel on public.habit_logs
for select using (
  exists (
    select 1 from public.habits h
    where h.id = public.habit_logs.habit_id
      and h.user_id = auth.uid()
  )
);

create policy habit_logs_crud on public.habit_logs
for all using (
  exists (
    select 1 from public.habits h
    where h.id = public.habit_logs.habit_id
      and h.user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.habits h
    where h.id = public.habit_logs.habit_id
      and h.user_id = auth.uid()
  )
);

-- Indexes
create index if not exists idx_moods_user_created on public.moods (user_id, created_at desc);
create index if not exists idx_habit_logs_habit_time on public.habit_logs (habit_id, performed_at desc);
create index if not exists idx_session_metrics_user_time on public.session_metrics (user_id, started_at desc);
create index if not exists idx_assessments_user_time on public.assessments (user_id, taken_at desc);
create index if not exists idx_events_user_time on public.events (user_id, starts_at desc);

update public.assessments
set kind = 'IMA'
where kind is null;

-- Seeds
insert into public.sessions (slug, title, duration_sec, modality, context_tags, premium, content)
values
  ('micro-reset-90s','Micro reset 90s',90,'audio','{pre_comp,post_entreno}',false,'{"steps":[{"type":"breath","sec":90}]}'),
  ('focus-3m','Enfoque 3–4 min',210,'audio','{estudio}',false,'{"steps":[{"type":"countdown","sec":210}]}'),
  ('recuperacion-10m','Recuperación 8–10 min',540,'audio','{noche}',true,'{"steps":[{"type":"body_scan","sec":540}]}')
on conflict (slug) do nothing;
