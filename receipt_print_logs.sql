-- Receipt print logging table for user print action
-- Run this in Supabase SQL editor.

create table if not exists public.receipt_print_logs (
  id bigserial primary key,
  printed_at timestamptz not null default now(),
  category text,
  marine_flow text,
  serial_no text,
  receipt_date text,
  payor text,
  officer text,
  total_amount numeric(12, 2) not null default 0,
  collection_items jsonb not null default '[]'::jsonb,
  nature_code text,
  payment_method text
);

alter table public.receipt_print_logs
  add column if not exists nature_code text,
  add column if not exists payment_method text;

create index if not exists idx_receipt_print_logs_printed_at
  on public.receipt_print_logs (printed_at desc);

create index if not exists idx_receipt_print_logs_category
  on public.receipt_print_logs (category);

create index if not exists idx_receipt_print_logs_nature_code
  on public.receipt_print_logs (nature_code);

create index if not exists idx_receipt_print_logs_payment_method
  on public.receipt_print_logs (payment_method);

alter table public.receipt_print_logs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'receipt_print_logs'
      and policyname = 'receipt_print_logs_insert_anon'
  ) then
    create policy receipt_print_logs_insert_anon
      on public.receipt_print_logs
      for insert
      to anon
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'receipt_print_logs'
      and policyname = 'receipt_print_logs_select_anon'
  ) then
    create policy receipt_print_logs_select_anon
      on public.receipt_print_logs
      for select
      to anon
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'receipt_print_logs'
      and policyname = 'receipt_print_logs_insert_authenticated'
  ) then
    create policy receipt_print_logs_insert_authenticated
      on public.receipt_print_logs
      for insert
      to authenticated
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'receipt_print_logs'
      and policyname = 'receipt_print_logs_select_authenticated'
  ) then
    create policy receipt_print_logs_select_authenticated
      on public.receipt_print_logs
      for select
      to authenticated
      using (true);
  end if;
end $$;
