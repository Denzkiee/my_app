-- ============================================================================
-- Run these SQL statements one at a time in the Supabase SQL Editor
-- ============================================================================

-- STEP 1: Add rating columns to existing clinics table
alter table clinics
add column if not exists avg_rating double precision not null default 0,
add column if not exists review_count integer not null default 0;

-- STEP 2: Create clinic_reviews table
create table if not exists clinic_reviews (
  id uuid not null primary key default gen_random_uuid(),
  clinic_id uuid not null references clinics(id) on delete cascade,
  patient_id uuid not null references profiles(id) on delete cascade,
  rating integer not null check (rating >= 1 and rating <= 5),
  review_text text,
  created_at timestamptz not null default now(),
  unique (clinic_id, patient_id)
);

-- STEP 3: Enable RLS and create policies for reviews
alter table clinic_reviews enable row level security;

create policy "Anyone can read reviews"
  on clinic_reviews for select
  using (true);

create policy "Patients can insert own reviews"
  on clinic_reviews for insert with check (
    auth.uid() = patient_id and
    exists (select 1 from profiles where id = auth.uid() and role = 'patient')
  );

create policy "Patients can update own reviews"
  on clinic_reviews for update using (auth.uid() = patient_id);

-- STEP 4: Rating trigger function + triggers
create or replace function update_clinic_ratings()
returns trigger as $$
begin
  update clinics
  set
    avg_rating = coalesce(
      (select round(avg(rating)::numeric, 1)::double precision
       from clinic_reviews where clinic_id = coalesce(new.clinic_id, old.clinic_id)),
      0
    ),
    review_count = coalesce(
      (select count(*) from clinic_reviews
       where clinic_id = coalesce(new.clinic_id, old.clinic_id)),
      0
    )
  where id = coalesce(new.clinic_id, old.clinic_id);
  return coalesce(new, old);
end;
$$ language plpgsql security definer;

drop trigger if exists trg_review_insert_update on clinic_reviews;
create trigger trg_review_insert_update
  after insert or update on clinic_reviews
  for each row execute function update_clinic_ratings();

drop trigger if exists trg_review_delete on clinic_reviews;
create trigger trg_review_delete
  after delete on clinic_reviews
  for each row execute function update_clinic_ratings();