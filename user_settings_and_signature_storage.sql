-- User settings + collecting officer signature storage
-- Run in Supabase SQL Editor.

-- 1) Settings table
create table if not exists public.user_settings (
  profile_key text primary key default 'default',
  language text not null default 'English',
  collecting_officer_name text,
  signature_image_path text,
  updated_at timestamptz not null default now()
);

alter table public.user_settings enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_select_anon'
  ) then
    create policy user_settings_select_anon
      on public.user_settings
      for select
      to anon
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_select_authenticated'
  ) then
    create policy user_settings_select_authenticated
      on public.user_settings
      for select
      to authenticated
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_insert_anon'
  ) then
    create policy user_settings_insert_anon
      on public.user_settings
      for insert
      to anon
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_insert_authenticated'
  ) then
    create policy user_settings_insert_authenticated
      on public.user_settings
      for insert
      to authenticated
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_update_anon'
  ) then
    create policy user_settings_update_anon
      on public.user_settings
      for update
      to anon
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
      and policyname = 'user_settings_update_authenticated'
  ) then
    create policy user_settings_update_authenticated
      on public.user_settings
      for update
      to authenticated
      using (true)
      with check (true);
  end if;
end $$;

insert into public.user_settings (profile_key, language, collecting_officer_name)
values ('default', 'English', '')
on conflict (profile_key) do nothing;

-- 2) Receipts table additions for officer/signature snapshot
alter table public.receipts
  add column if not exists officer text,
  add column if not exists officer_signature_path text;

-- 3) Supabase Storage bucket for signature images
insert into storage.buckets (id, name, public)
values ('officer-signatures', 'officer-signatures', true)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'officer_signatures_public_read'
  ) then
    create policy officer_signatures_public_read
      on storage.objects
      for select
      to public
      using (bucket_id = 'officer-signatures');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'officer_signatures_anon_insert'
  ) then
    create policy officer_signatures_anon_insert
      on storage.objects
      for insert
      to anon
      with check (bucket_id = 'officer-signatures');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'officer_signatures_anon_update'
  ) then
    create policy officer_signatures_anon_update
      on storage.objects
      for update
      to anon
      using (bucket_id = 'officer-signatures')
      with check (bucket_id = 'officer-signatures');
  end if;
end $$;
