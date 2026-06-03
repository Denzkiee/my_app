-- Supabase schema for role-based dental appointment booking
-- Use Supabase Auth and link profiles to auth.users

create table profiles (
  id uuid not null primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now()
);

create table appointments (
  id uuid not null primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  patient_name text not null,
  service_type text not null,
  dentist_name text not null,
  date_time timestamptz not null,
  contact_number text not null,
  notes text,
  status text not null default 'Scheduled' check (status in ('Scheduled', 'Completed', 'Canceled')),
  created_at timestamptz not null default now()
);

-- Allow users to read only their own bookings
create policy "Users can read own appointments"
  on appointments
  for select
  using (auth.uid() = profile_id);

-- Allow users to insert their own appointments
create policy "Users can insert own appointments"
  on appointments
  for insert
  with check (auth.uid() = profile_id);

-- Allow admins to read all appointments
create policy "Admins can read all appointments"
  on appointments
  for select
  using (
    exists (
      select 1 from profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- Allow admins to manage appointments fully
create policy "Admins can manage appointments"
  on appointments
  for all
  using (
    exists (
      select 1 from profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- Allow users to select their own profile row
create policy "Users can read own profile"
  on profiles
  for select
  using (auth.uid() = id);

-- Allow users to insert their own profile
create policy "Users can insert own profile"
  on profiles
  for insert
  with check (auth.uid() = id);
