create table if not exists public.allowed_email_domains (
  domain text primary key
);

insert into public.allowed_email_domains(domain) values
  ('edu.pe'),
  ('univ.edu')
on conflict do nothing;

alter table public.allowed_email_domains enable row level security;

do $$
begin
  perform 1
  from pg_policies
  where schemaname = 'public'
    and tablename = 'allowed_email_domains'
    and policyname = 'public read domains';

  if not found then
    create policy "public read domains"
    on public.allowed_email_domains
    for select
    using (true);
  end if;
end
$$;
