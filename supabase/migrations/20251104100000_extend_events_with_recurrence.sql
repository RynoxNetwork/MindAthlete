alter table public.events
  add column if not exists frequency text check (frequency in ('none','daily','weekly','biweekly','monthly')) default 'none',
  add column if not exists repeat_days text[] default '{}',
  add column if not exists end_date timestamptz,
  add column if not exists override_parent_id uuid references public.events(id) on delete cascade,
  add column if not exists is_override boolean not null default false;

create index if not exists idx_events_override_parent on public.events(override_parent_id);

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  last_message_at timestamptz default now(),
  message_count int4 not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','assistant','system')),
  content text not null,
  metadata jsonb,
  token_count int4,
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_messages_chat_created on public.chat_messages(chat_id, created_at asc);
create index if not exists idx_chat_messages_user_created on public.chat_messages(user_id, created_at desc);

create table if not exists public.habit_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_json jsonb not null,
  summary text,
  source text not null check (source in ('AI','manual')) default 'AI',
  timeframe text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_habit_plans_user_created on public.habit_plans(user_id, created_at desc);

create table if not exists public.escalations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text,
  reason text not null,
  context jsonb,
  status text not null check (status in ('new','scheduled','dismissed')) default 'new',
  booking_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_escalations_user_status on public.escalations(user_id, status);

alter table public.chats enable row level security;
alter table public.chat_messages enable row level security;
alter table public.habit_plans enable row level security;
alter table public.escalations enable row level security;

drop policy if exists chats_sel on public.chats;
drop policy if exists chats_crud on public.chats;
drop policy if exists chat_messages_sel on public.chat_messages;
drop policy if exists chat_messages_crud on public.chat_messages;
drop policy if exists habit_plans_sel on public.habit_plans;
drop policy if exists habit_plans_crud on public.habit_plans;
drop policy if exists escalations_sel on public.escalations;
drop policy if exists escalations_crud on public.escalations;

create policy chats_sel on public.chats
  for select using (user_id = auth.uid());

create policy chats_crud on public.chats
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy chat_messages_sel on public.chat_messages
  for select using (
    exists (
      select 1
      from public.chats c
      where c.id = public.chat_messages.chat_id
        and c.user_id = auth.uid()
    )
  );

create policy chat_messages_crud on public.chat_messages
  for all using (
    exists (
      select 1
      from public.chats c
      where c.id = public.chat_messages.chat_id
        and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.chats c
      where c.id = public.chat_messages.chat_id
        and c.user_id = auth.uid()
    )
  );

create policy habit_plans_sel on public.habit_plans
  for select using (user_id = auth.uid());

create policy habit_plans_crud on public.habit_plans
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy escalations_sel on public.escalations
  for select using (user_id = auth.uid());

create policy escalations_crud on public.escalations
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());
