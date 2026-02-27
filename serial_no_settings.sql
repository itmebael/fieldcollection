-- Serial number support for admin settings + auto increment on print
-- Run in Supabase SQL editor.

alter table public.user_settings
  add column if not exists next_serial_no integer not null default 1;

update public.user_settings
set next_serial_no = 1
where next_serial_no is null or next_serial_no < 1;

create or replace function public.consume_next_serial_no(p_profile_key text default 'default')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current integer;
begin
  insert into public.user_settings (profile_key, language, next_serial_no)
  values (p_profile_key, 'English', 1)
  on conflict (profile_key) do nothing;

  update public.user_settings
  set next_serial_no = next_serial_no + 1,
      updated_at = now()
  where profile_key = p_profile_key
  returning next_serial_no - 1 into v_current;

  return v_current;
end;
$$;

grant execute on function public.consume_next_serial_no(text) to anon;
grant execute on function public.consume_next_serial_no(text) to authenticated;

