create or replace function public.enforce_student_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  email_domain text;
begin
  email_domain := substring(new.email from position('@' in new.email) + 1);

  if not exists (
    select 1
    from public.allowed_email_domains d
    where d.domain = email_domain
  ) then
    raise exception 'Email domain % not allowed', email_domain using errcode = '22023';
  end if;

  return new;
end $$;

drop trigger if exists trg_enforce_domain on public.user_profiles;
create trigger trg_enforce_domain
before insert or update of email on public.user_profiles
for each row execute function public.enforce_student_email();
