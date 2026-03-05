-- Manage Payor schema (Supabase/Postgres)
-- Run in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.payors (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  full_name text not null,
  category text not null default '',
  building text,
  stall text,
  stall_price numeric(12, 2) not null default 0,
  contact text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payors
  add column if not exists building text,
  add column if not exists stall text,
  add column if not exists stall_price numeric(12, 2) not null default 0;

create table if not exists public.payor_schedules (
  id uuid primary key default gen_random_uuid(),
  payor_id uuid not null references public.payors (id) on delete cascade,
  frequency text not null default 'monthly',
  custom_interval_days integer,
  start_date timestamptz not null default now(),
  default_amount numeric(12, 2) not null default 0,
  is_paused boolean not null default false,
  next_due_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payor_schedules_one_per_payor unique (payor_id)
);

create table if not exists public.payor_schedule_occurrences (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.payor_schedules (id) on delete cascade,
  due_date timestamptz not null,
  amount numeric(12, 2) not null default 0,
  paid_at timestamptz,
  status text not null default 'expected',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payor_occurrences_schedule_due_unique unique (schedule_id, due_date)
);

create table if not exists public.payor_payments (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.payor_schedules (id) on delete cascade,
  due_date timestamptz not null,
  paid_at timestamptz not null default now(),
  amount numeric(12, 2) not null default 0,
  method text not null default 'cash',
  note text,
  receipt_serial_no text,
  created_at timestamptz not null default now()
);

create index if not exists idx_payors_owner_id
  on public.payors (owner_id);

create index if not exists idx_payors_created_at
  on public.payors (created_at desc);

create index if not exists idx_payor_schedules_payor_id
  on public.payor_schedules (payor_id);

create index if not exists idx_payor_occurrences_schedule_due
  on public.payor_schedule_occurrences (schedule_id, due_date);

create index if not exists idx_payor_payments_schedule_paid_at
  on public.payor_payments (schedule_id, paid_at desc);

alter table public.payors enable row level security;
alter table public.payor_schedules enable row level security;
alter table public.payor_schedule_occurrences enable row level security;
alter table public.payor_payments enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payors'
      and policyname = 'payors_select_owner'
  ) then
    create policy payors_select_owner
      on public.payors
      for select
      to authenticated
      using (owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payors'
      and policyname = 'payors_insert_owner'
  ) then
    create policy payors_insert_owner
      on public.payors
      for insert
      to authenticated
      with check (owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payors'
      and policyname = 'payors_update_owner'
  ) then
    create policy payors_update_owner
      on public.payors
      for update
      to authenticated
      using (owner_id = auth.uid())
      with check (owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payors'
      and policyname = 'payors_delete_owner'
  ) then
    create policy payors_delete_owner
      on public.payors
      for delete
      to authenticated
      using (owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payor_schedules'
      and policyname = 'payor_schedules_owner_all'
  ) then
    create policy payor_schedules_owner_all
      on public.payor_schedules
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.payors p
          where p.id = payor_schedules.payor_id
            and p.owner_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.payors p
          where p.id = payor_schedules.payor_id
            and p.owner_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payor_schedule_occurrences'
      and policyname = 'payor_occurrences_owner_all'
  ) then
    create policy payor_occurrences_owner_all
      on public.payor_schedule_occurrences
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.payor_schedules ps
          join public.payors p on p.id = ps.payor_id
          where ps.id = payor_schedule_occurrences.schedule_id
            and p.owner_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.payor_schedules ps
          join public.payors p on p.id = ps.payor_id
          where ps.id = payor_schedule_occurrences.schedule_id
            and p.owner_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payor_payments'
      and policyname = 'payor_payments_owner_all'
  ) then
    create policy payor_payments_owner_all
      on public.payor_payments
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.payor_schedules ps
          join public.payors p on p.id = ps.payor_id
          where ps.id = payor_payments.schedule_id
            and p.owner_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.payor_schedules ps
          join public.payors p on p.id = ps.payor_id
          where ps.id = payor_payments.schedule_id
            and p.owner_id = auth.uid()
        )
      );
  end if;
end $$;
