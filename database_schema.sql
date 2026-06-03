-- Dental Office Booking System SQL Schema
-- Run these commands in MySQL, PostgreSQL, or SQLite with minor adjustments.

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL
);

CREATE TABLE appointments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_name TEXT NOT NULL,
  service_type TEXT NOT NULL,
  dentist_name TEXT NOT NULL,
  date_time TEXT NOT NULL,
  contact_number TEXT NOT NULL,
  notes TEXT NOT NULL,
  status TEXT NOT NULL
);

-- Example seed user:
-- INSERT INTO users (full_name, email, password_hash, salt)
-- VALUES ('Admin User', 'admin@dentaloffice.com', '<hashed password>', '<salt>');

-- Example appointment:
-- INSERT INTO appointments (patient_name, service_type, dentist_name, date_time, contact_number, notes, status)
-- VALUES ('John Doe', 'Cleaning', 'Dr. Smith', '2026-07-01T10:00:00.000', '+1234567890', 'First-time patient', 'Scheduled');
