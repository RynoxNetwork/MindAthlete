-- Add SELF_ESTEEM instrument to assessments table
alter table public.assessments
  drop constraint if exists assessments_instrument_check;

alter table public.assessments
  add constraint assessments_instrument_check
  check (instrument in ('POMS','IDEP','BREVE','SELF_ESTEEM'));
