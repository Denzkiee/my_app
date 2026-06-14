-- Dental Booking System — Supabase / PostgreSQL Schema
-- Paste this entire script into the Supabase SQL Editor and run it once.
-- Uses Supabase Auth (auth.users). Profiles are created by the Flutter app on register.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Drop existing objects (safe re-run for development)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS activity_logs CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS clinic_availability CASCADE;
DROP TABLE IF EXISTS clinic_services CASCADE;
DROP TABLE IF EXISTS clinics CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

DROP FUNCTION IF EXISTS set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- ---------------------------------------------------------------------------
-- Profiles (linked to Supabase Auth)
-- ---------------------------------------------------------------------------
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK (role IN ('patient', 'clinic', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Clinics & clinic applications (same table; status drives approval flow)
-- ---------------------------------------------------------------------------
CREATE TABLE clinics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  application_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (application_status IN ('pending', 'approved', 'rejected')),
  admin_notes TEXT NOT NULL DEFAULT '',
  listing_status TEXT NOT NULL DEFAULT 'active'
    CHECK (listing_status IN ('active', 'disabled', 'terminated')),
  status_reason TEXT NOT NULL DEFAULT '',
  appeal_status TEXT NOT NULL DEFAULT 'none'
    CHECK (appeal_status IN ('none', 'pending', 'approved', 'rejected')),
  appeal_message TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (owner_id)
);

-- ---------------------------------------------------------------------------
-- Services offered by an approved clinic
-- ---------------------------------------------------------------------------
CREATE TABLE clinic_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Weekly availability windows (day 0 = Sunday … 6 = Saturday)
-- ---------------------------------------------------------------------------
CREATE TABLE clinic_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_duration_minutes INTEGER NOT NULL DEFAULT 30 CHECK (slot_duration_minutes > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_time > start_time)
);

-- ---------------------------------------------------------------------------
-- Patient bookings
-- ---------------------------------------------------------------------------
CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  service_id UUID REFERENCES clinic_services(id) ON DELETE SET NULL,
  service_name TEXT NOT NULL,
  appointment_datetime TIMESTAMPTZ NOT NULL,
  contact_number TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'denied', 'cancelled', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Admin audit log
-- ---------------------------------------------------------------------------
CREATE TABLE activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  actor_role TEXT NOT NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX idx_clinics_status ON clinics(application_status);
CREATE INDEX idx_clinics_listing ON clinics(listing_status);
CREATE INDEX idx_clinics_appeal ON clinics(appeal_status);
CREATE INDEX idx_clinics_owner ON clinics(owner_id);
CREATE INDEX idx_clinic_services_clinic ON clinic_services(clinic_id);
CREATE INDEX idx_clinic_availability_clinic ON clinic_availability(clinic_id);
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_clinic ON appointments(clinic_id);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_activity_logs_created ON activity_logs(created_at DESC);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clinics_updated_at
  BEFORE UPDATE ON clinics
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER appointments_updated_at
  BEFORE UPDATE ON appointments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Helper: current user's role
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Profiles
CREATE POLICY "Profiles are viewable by authenticated users"
  ON profiles FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id);

-- Clinics: patients see approved + active listings; owners see own; admins see all
CREATE POLICY "Approved clinics visible to authenticated users"
  ON clinics FOR SELECT TO authenticated
  USING (
    (application_status = 'approved' AND listing_status = 'active')
    OR owner_id = auth.uid()
    OR public.current_user_role() = 'admin'
  );

CREATE POLICY "Clinic owners can insert their application"
  ON clinics FOR INSERT TO authenticated
  WITH CHECK (
    owner_id = auth.uid()
    AND public.current_user_role() = 'clinic'
  );

CREATE POLICY "Clinic owners can update own clinic"
  ON clinics FOR UPDATE TO authenticated
  USING (owner_id = auth.uid() OR public.current_user_role() = 'admin');

CREATE POLICY "Admins can delete clinics"
  ON clinics FOR DELETE TO authenticated
  USING (public.current_user_role() = 'admin');

-- Clinic services
CREATE POLICY "Services visible for visible clinics"
  ON clinic_services FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id
        AND (
          (c.application_status = 'approved' AND c.listing_status = 'active')
          OR c.owner_id = auth.uid()
          OR public.current_user_role() = 'admin'
        )
    )
  );

CREATE POLICY "Clinic owners manage their services"
  ON clinic_services FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id AND c.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id AND c.owner_id = auth.uid()
    )
  );

-- Clinic availability
CREATE POLICY "Availability visible for visible clinics"
  ON clinic_availability FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id
        AND (
          (c.application_status = 'approved' AND c.listing_status = 'active')
          OR c.owner_id = auth.uid()
          OR public.current_user_role() = 'admin'
        )
    )
  );

CREATE POLICY "Clinic owners manage their availability"
  ON clinic_availability FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id AND c.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id AND c.owner_id = auth.uid()
    )
  );

-- Appointments
CREATE POLICY "Patients see own appointments"
  ON appointments FOR SELECT TO authenticated
  USING (
    patient_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id AND c.owner_id = auth.uid()
    )
    OR public.current_user_role() = 'admin'
  );

CREATE POLICY "Patients can book appointments"
  ON appointments FOR INSERT TO authenticated
  WITH CHECK (
    patient_id = auth.uid()
    AND public.current_user_role() = 'patient'
    AND EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id
        AND c.application_status = 'approved'
        AND c.listing_status = 'active'
    )
  );

CREATE POLICY "Patients and clinics can update relevant appointments"
  ON appointments FOR UPDATE TO authenticated
  USING (
    patient_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM clinics c
      WHERE c.id = clinic_id AND c.owner_id = auth.uid()
    )
    OR public.current_user_role() = 'admin'
  );

CREATE POLICY "Patients can delete own pending appointments"
  ON appointments FOR DELETE TO authenticated
  USING (patient_id = auth.uid() AND status IN ('pending', 'accepted'));

-- Activity logs: insert by any authenticated user; read admins only
CREATE POLICY "Authenticated users can write logs"
  ON activity_logs FOR INSERT TO authenticated
  WITH CHECK (actor_id = auth.uid());

CREATE POLICY "Admins can read logs"
  ON activity_logs FOR SELECT TO authenticated
  USING (public.current_user_role() = 'admin');

-- ---------------------------------------------------------------------------
-- Seed an admin account manually after creating the auth user in Supabase:
--
-- 1. Authentication → Users → Add user (email + password)
-- 2. Copy the user's UUID, then run:
--
-- INSERT INTO profiles (id, full_name, email, role)
-- VALUES ('<AUTH_USER_UUID>', 'System Admin', 'admin@dentaloffice.com', 'admin');

-- ---------------------------------------------------------------------------
-- Migration (run ONLY if upgrading an existing database)
-- ---------------------------------------------------------------------------
-- ALTER TABLE clinics ADD COLUMN IF NOT EXISTS listing_status TEXT NOT NULL DEFAULT 'active'
--   CHECK (listing_status IN ('active', 'disabled', 'terminated'));
-- ALTER TABLE clinics ADD COLUMN IF NOT EXISTS status_reason TEXT NOT NULL DEFAULT '';
-- ALTER TABLE clinics ADD COLUMN IF NOT EXISTS appeal_status TEXT NOT NULL DEFAULT 'none'
--   CHECK (appeal_status IN ('none', 'pending', 'approved', 'rejected'));
-- ALTER TABLE clinics ADD COLUMN IF NOT EXISTS appeal_message TEXT NOT NULL DEFAULT '';
-- CREATE INDEX IF NOT EXISTS idx_clinics_listing ON clinics(listing_status);
-- CREATE INDEX IF NOT EXISTS idx_clinics_appeal ON clinics(appeal_status);
