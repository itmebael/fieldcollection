-- Admin user-account management (Supabase/Postgres)
-- Run in Supabase SQL Editor.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('admin', 'staff');
  end if;
end $$;

create table if not exists public.user_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text unique not null,
  full_name text not null default '',
  role public.app_role not null default 'staff',
  is_active boolean not null default true,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (id, email, full_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'staff'
  )
  on conflict (id) do update
    set email = excluded.email;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_auth_user();

create or replace function public.is_admin(p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles up
    where up.id = p_uid
      and up.role = 'admin'
      and up.is_active = true
  );
$$;

alter table public.user_profiles enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_profiles'
      and policyname = 'user_profiles_select_own_or_admin'
  ) then
    create policy user_profiles_select_own_or_admin
      on public.user_profiles
      for select
      to authenticated
      using (id = auth.uid() or public.is_admin(auth.uid()));
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_profiles'
      and policyname = 'user_profiles_update_own_or_admin'
  ) then
    create policy user_profiles_update_own_or_admin
      on public.user_profiles
      for update
      to authenticated
      using (id = auth.uid() or public.is_admin(auth.uid()))
      with check (id = auth.uid() or public.is_admin(auth.uid()));
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'user_profiles'
      and policyname = 'user_profiles_insert_admin_only'
  ) then
    create policy user_profiles_insert_admin_only
      on public.user_profiles
      for insert
      to authenticated
      with check (public.is_admin(auth.uid()));
  end if;
end $$;

create or replace function public.admin_create_user(
  p_email text,
  p_password text,
  p_full_name text,
  p_role public.app_role default 'staff',
  p_email_confirm boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user auth.users;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Only admins can create users';
  end if;

  if p_email is null or length(trim(p_email)) = 0 then
    raise exception 'Email is required';
  end if;

  if p_password is null or length(p_password) < 8 then
    raise exception 'Password must be at least 8 characters';
  end if;

  select *
  into v_user
  from auth.admin_create_user(
    email => lower(trim(p_email)),
    password => p_password,
    email_confirm => p_email_confirm,
    user_metadata => jsonb_build_object('full_name', coalesce(trim(p_full_name), '')),
    app_metadata => jsonb_build_object('role', p_role::text)
  );

  update public.user_profiles
  set
    full_name = coalesce(trim(p_full_name), ''),
    role = p_role,
    created_by = auth.uid(),
    is_active = true
  where id = v_user.id;

  return v_user.id;
end;
$$;

grant execute on function public.admin_create_user(text, text, text, public.app_role, boolean) to authenticated;

-- Per-user receipt serial range assignment
alter table public.user_profiles
  add column if not exists serial_start_no integer,
  add column if not exists serial_end_no integer,
  add column if not exists next_serial_no integer,
  add column if not exists signature_image_path text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_user_profiles_serial_range'
  ) then
    alter table public.user_profiles
      add constraint chk_user_profiles_serial_range
      check (
        (
          serial_start_no is null and
          serial_end_no is null and
          next_serial_no is null
        )
        or
        (
          serial_start_no is not null and
          serial_end_no is not null and
          serial_start_no > 0 and
          serial_end_no >= serial_start_no and
          next_serial_no is not null and
          next_serial_no >= serial_start_no and
          next_serial_no <= serial_end_no + 1
        )
      );
  end if;
end $$;

create or replace function public.admin_set_user_serial_range(
  p_user_id uuid,
  p_serial_start_no integer,
  p_serial_end_no integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'Only admins can assign serial ranges';
  end if;

  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if p_serial_start_no is null or p_serial_start_no < 1 then
    raise exception 'Serial start must be >= 1';
  end if;

  if p_serial_end_no is null or p_serial_end_no < p_serial_start_no then
    raise exception 'Serial end must be >= serial start';
  end if;

  update public.user_profiles
  set
    serial_start_no = p_serial_start_no,
    serial_end_no = p_serial_end_no,
    next_serial_no = p_serial_start_no,
    updated_at = now()
  where id = p_user_id;

  if not found then
    raise exception 'User not found';
  end if;
end;
$$;

grant execute on function public.admin_set_user_serial_range(uuid, integer, integer) to authenticated;

create or replace function public.get_my_serial_status()
returns table (
  serial_start_no integer,
  serial_end_no integer,
  next_serial_no integer,
  remaining_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    up.serial_start_no,
    up.serial_end_no,
    up.next_serial_no,
    case
      when up.serial_start_no is null or up.serial_end_no is null or up.next_serial_no is null then null
      when up.next_serial_no > up.serial_end_no then 0
      else (up.serial_end_no - up.next_serial_no + 1)
    end as remaining_count
  from public.user_profiles up
  where up.id = auth.uid();
$$;

grant execute on function public.get_my_serial_status() to authenticated;

create or replace function public.consume_my_serial_no()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.user_profiles;
  v_current integer;
begin
  select *
  into v_profile
  from public.user_profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'No user profile found for current user';
  end if;

  if not v_profile.is_active then
    raise exception 'User is inactive';
  end if;

  if v_profile.serial_start_no is null or v_profile.serial_end_no is null then
    raise exception 'No serial range assigned for this user';
  end if;

  if v_profile.next_serial_no is null then
    v_profile.next_serial_no := v_profile.serial_start_no;
  end if;

  if v_profile.next_serial_no > v_profile.serial_end_no then
    raise exception 'Serial range exhausted for this user';
  end if;

  v_current := v_profile.next_serial_no;

  update public.user_profiles
  set
    next_serial_no = v_current + 1,
    updated_at = now()
  where id = v_profile.id;

  return v_current;
end;
$$;

grant execute on function public.consume_my_serial_no() to authenticated;

-- Allow authenticated users to upload/update signature images in bucket
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'officer_signatures_authenticated_insert'
  ) then
    create policy officer_signatures_authenticated_insert
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'officer-signatures');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'officer_signatures_authenticated_update'
  ) then
    create policy officer_signatures_authenticated_update
      on storage.objects
      for update
      to authenticated
      using (bucket_id = 'officer-signatures')
      with check (bucket_id = 'officer-signatures');
  end if;
end $$;

-- Bootstrap first admin (replace email before running this line)
-- update public.user_profiles
-- set role = 'admin'
-- where email = 'your_admin_email@example.com';

-- Example call from your admin UI:
-- select public.admin_create_user(
--   p_email => 'newstaff@example.com',
--   p_password => 'TempPass#1234',
--   p_full_name => 'New Staff',
--   p_role => 'staff',
--   p_email_confirm => true
-- );
