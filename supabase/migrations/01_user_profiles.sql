-- Tabla de perfil
create table if not exists public.user_profiles (
  id uuid primary key,
  email text not null unique,
  display_name text,
  university text,
  consent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- trigger updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_set_updated_at on public.user_profiles;
create trigger trg_set_updated_at
before update on public.user_profiles
for each row execute function public.set_updated_at();

-- RLS + policies
alter table public.user_profiles enable row level security;

drop policy if exists "User can SELECT own profile" on public.user_profiles;
create policy "User can SELECT own profile"
on public.user_profiles
for select
using (id = auth.uid());

drop policy if exists "User can INSERT own profile" on public.user_profiles;
create policy "User can INSERT own profile"
on public.user_profiles
for insert
with check (id = auth.uid());

drop policy if exists "User can UPDATE own profile" on public.user_profiles;
create policy "User can UPDATE own profile"
on public.user_profiles
for update
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "User can DELETE own profile" on public.user_profiles;
create policy "User can DELETE own profile"
on public.user_profiles
for delete
using (id = auth.uid());
