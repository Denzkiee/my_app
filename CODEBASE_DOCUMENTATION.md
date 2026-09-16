# Dental Booking System — Codebase Documentation

## Overview

This is a **Flutter mobile application** for a **Dental Booking System** that connects patients with dental clinics. The app uses **Supabase** as the backend (authentication, database, and real-time features) and supports three user roles: **Patient**, **Clinic**, and **Admin**.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Tech Stack](#tech-stack)
3. [Architecture](#architecture)
4. [Data Models](#data-models)
5. [Services](#services)
6. [Utilities](#utilities)
7. [Screens](#screens)
8. [Widgets](#widgets)
9. [Database Schema](#database-schema)
10. [Authentication Flow](#authentication-flow)
11. [Role-Based Features](#role-based-features)
12. [Configuration](#configuration)

---

## Project Structure

```
my_app/
├── android/                    # Android platform configuration
├── ios/                        # iOS platform configuration
├── lib/
│   ├── main.dart               # App entry point & route definitions
│   └── src/
│       ├── assets/             # Static assets (app icons)
│       ├── models/             # Data models
│       ├── screens/            # UI screens
│       ├── services/           # Business logic & data access
│       ├── utils/              # Helper utilities
│       └── widgets/            # Reusable widgets
├── linux/                      # Linux platform configuration
├── macos/                      # macOS platform configuration
├── test/                       # Unit/widget tests
├── web/                        # Web platform configuration
├── windows/                    # Windows platform configuration
├── pubspec.yaml                # Dependencies & project config
├── supabase_schema.sql         # Database schema & triggers
└── README.md                   # Project readme
```

---

## Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework (SDK ^3.12.1) |
| **Dart** | Programming language |
| **Supabase** | Backend-as-a-Service (Auth, PostgreSQL, RLS) |
| **supabase_flutter** | Supabase SDK for Flutter (^2.12.4) |
| **intl** | Date/time formatting (^0.20.2) |
| **Material 3** | UI design system (teal seed color) |

---

## Architecture

The app follows a **layered architecture**:

```
┌─────────────────────────────────────────────┐
│              UI Layer (Screens)             │
│  Auth / Patient / Clinic / Admin screens    │
├─────────────────────────────────────────────┤
│            Service Layer                     │
│  DatabaseService (singleton)                │
├─────────────────────────────────────────────┤
│            Model Layer                       │
│  User, Clinic, Appointment, etc.            │
├─────────────────────────────────────────────┤
│            Backend (Supabase)                │
│  Auth, PostgreSQL, Row Level Security       │
└─────────────────────────────────────────────┘
```

- **Screens** call **DatabaseService** (a singleton) to perform data operations.
- **DatabaseService** returns strongly-typed **model objects**.
- **Utilities** provide date/time handling, routing, and error/idempotency helpers.

---

## Data Models

All models are located in `lib/src/models/`.

### User (`user.dart`)
Represents an authenticated user profile.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String?` | User UUID |
| `fullName` | `String` | Full name |
| `email` | `String` | Email address |
| `role` | `String` | `patient`, `clinic`, or `admin` |

**Helper getters:** `isPatient`, `isClinic`, `isAdmin`

### Clinic (`clinic.dart`)
Represents a dental clinic with application/listing status.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String?` | Clinic UUID |
| `ownerId` | `String` | Owner user ID |
| `name` | `String` | Clinic name |
| `description` | `String` | Description |
| `address` | `String` | Address |
| `phone` | `String` | Phone number |
| `applicationStatus` | `String` | `pending`, `approved`, `rejected` |
| `adminNotes` | `String` | Admin notes |
| `listingStatus` | `String` | `active`, `disabled`, `terminated` |
| `statusReason` | `String` | Reason for status change |
| `appealStatus` | `String` | `none`, `pending`, `approved`, `rejected` |
| `appealMessage` | `String` | Appeal message |
| `avgRating` | `double` | Average rating (0-5) |
| `reviewCount` | `int` | Number of reviews |
| `latitude` | `double?` | Map latitude (`null` until the owner sets a location) |
| `longitude` | `double?` | Map longitude (`null` until the owner sets a location) |
| `establishmentImages` | `List<String>` | Public URLs of clinic photos uploaded for verification (max 5) |
| `createdAt` | `DateTime?` | Application creation timestamp |
| `availability` | `List<ClinicAvailability>` | Operating hours |

**Key getters:** `isApproved`, `isPending`, `isRejected`, `isActiveListing`, `isDisabled`, `isTerminated`, `isHiddenFromPatients`, `hasPendingAppeal`, `canSubmitAppeal`, `hasValidLocation`, `hasEstablishmentImages`, `hoursSummary`

### Appointment (`appointment.dart`)
Represents a booking request.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String?` | Appointment UUID |
| `patientId` | `String` | Patient user ID |
| `clinicId` | `String` | Clinic ID |
| `serviceId` | `String?` | Service ID |
| `serviceName` | `String` | Service name |
| `appointmentDateTime` | `DateTime` | Scheduled date/time |
| `contactNumber` | `String` | Patient contact |
| `notes` | `String` | Optional notes |
| `status` | `String` | `pending`, `accepted`, `denied`, `cancelled`, `completed` |
| `clinicName` | `String?` | Joined clinic name |
| `patientName` | `String?` | Joined patient name |

### ClinicAvailability (`clinic_availability.dart`)
Represents operating hours for a clinic.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String?` | Availability UUID |
| `clinicId` | `String` | Clinic ID |
| `dayOfWeek` | `int` | 0=Sunday ... 6=Saturday |
| `startTime` | `String` | HH:mm format |
| `endTime` | `String` | HH:mm format |
| `slotDurationMinutes` | `int` | Slot duration (default 30) |

**Key methods:** `slotsForDate(DateTime)` — generates available time slots for a date, excluding past times.

### ClinicService (`clinic_service.dart`)
Represents a service offered by a clinic.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String?` | Service UUID |
| `clinicId` | `String` | Clinic ID |
| `name` | `String` | Service name |
| `description` | `String` | Description |
| `price` | `double` | Price in PHP |

**Helper:** `priceLabel` → `₱XX.XX`

### ClinicReview (`clinic_review.dart`)
Represents a patient's rating/review of a clinic.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String?` | Review UUID |
| `clinicId` | `String` | Clinic ID |
| `patientId` | `String` | Patient ID |
| `rating` | `int` | 1-5 stars |
| `reviewText` | `String?` | Optional review text |
| `createdAt` | `DateTime?` | Creation timestamp |

### ActivityLog (`activity_log.dart`)
Represents an audit trail entry.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String?` | Log UUID |
| `actorId` | `String?` | Actor user ID |
| `actorRole` | `String` | Actor role |
| `action` | `String` | Action performed |
| `entityType` | `String` | Entity type affected |
| `entityId` | `String?` | Entity ID |
| `details` | `Map` | Additional details |
| `createdAt` | `DateTime?` | Timestamp |
| `actorName` | `String?` | Joined actor name |

### OTP Flow (`otp_flow.dart`)
```dart
enum OtpFlowType { registration, passwordReset }

class OtpVerificationArgs {
  final String email;
  final OtpFlowType flow;
  final String? fullName;
  final String? role;
}
```

---

## Services

### DatabaseService (`lib/src/services/database_service.dart`)

A **singleton** (`DatabaseService.instance`) that wraps all Supabase operations.

#### Auth & Profiles
| Method | Description |
|--------|-------------|
| `authenticate(email, password)` | Sign in and fetch profile |
| `sendRegistrationOtp(...)` | Send signup OTP |
| `verifyRegistrationOtp(...)` | Verify signup OTP & create profile |
| `resendRegistrationOtp(email)` | Resend signup OTP (rate-limited) |
| `sendPasswordResetOtp(email)` | Send password reset OTP |
| `verifyPasswordResetOtp(...)` | Verify reset OTP & update password |
| `changePassword(...)` | Change password with current password |
| `registerUser(...)` | Direct registration (with retry logic) |
| `getCurrentUser()` | Fetch current authenticated user |
| `logout()` | Sign out |

#### Activity Logs
| Method | Description |
|--------|-------------|
| `logActivity(...)` | Insert activity log entry |
| `fetchActivityLogs()` | Fetch latest 200 logs with actor names |

#### Clinics
| Method | Description |
|--------|-------------|
| `fetchApprovedClinics()` | Fetch approved & active clinics |
| `searchClinics(query, addressFilter, minRating)` | Search with filters |
| `fetchActiveClinicsForAdmin()` | Fetch active clinics for admin |
| `fetchPendingClinicAppeals()` | Fetch pending appeals |
| `fetchPendingClinicApplications()` | Fetch pending applications |
| `fetchClinicByOwner(ownerId)` | Fetch clinic by owner |
| `fetchClinicById(clinicId)` | Fetch clinic by ID |
| `submitClinicApplication(...)` | Submit or resubmit application |
| `reviewClinicApplication(...)` | Approve/reject application |
| `disableClinic(...)` | Disable a clinic |
| `terminateClinic(...)` | Terminate a clinic |
| `reactivateClinic(clinicId)` | Reactivate a clinic |
| `submitClinicAppeal(...)` | Submit an appeal |
| `reviewClinicAppeal(...)` | Approve/reject appeal |
| `updateClinicDetails(...)` | Update clinic details |
| `updateClinicLocation(...)` | Save the clinic's latitude/longitude |
| `fetchClinicsWithLocation()` | Fetch approved clinics that have map coordinates |
| `uploadClinicImage(...)` | Upload a photo to the `clinic_images` bucket and return its public URL |
| `updateClinicImages(...)` | Replace the clinic's stored establishment image URLs |

#### Clinic Services
| Method | Description |
|--------|-------------|
| `fetchClinicServices(clinicId)` | Fetch services |
| `addClinicService(...)` | Add a service |
| `updateClinicService(...)` | Update a service |
| `deleteClinicService(serviceId)` | Delete a service |

#### Clinic Availability
| Method | Description |
|--------|-------------|
| `fetchClinicAvailability(clinicId)` | Fetch operating hours |
| `addClinicAvailability(...)` | Add operating hours |
| `deleteClinicAvailability(availabilityId)` | Delete operating hours |

#### Appointments
| Method | Description |
|--------|-------------|
| `createAppointment(appointment)` | Create booking (validates future date) |
| `fetchPatientAppointments(patientId)` | Fetch patient's bookings |
| `fetchClinicAppointments(clinicId)` | Fetch clinic's bookings |
| `fetchBookedSlots(clinicId, date)` | Fetch booked slots for a date |
| `updateAppointmentStatus(id, status)` | Update booking status |
| `cancelAppointment(id)` | Cancel a booking |

#### Reviews
| Method | Description |
|--------|-------------|
| `submitReview(...)` | Submit/update a review (upsert) |
| `fetchPatientReview(clinicId, patientId)` | Fetch patient's review |
| `fetchClinicReviews(clinicId)` | Fetch all reviews for a clinic |

---

## Utilities

### AppDateTime (`lib/src/utils/app_date_time.dart`)
Handles **Philippine Standard Time (UTC+8, no DST)**.

| Method | Description |
|--------|-------------|
| `philippineNow()` | Current time in PHT |
| `toPhilippine(dateTime)` | Convert to PHT |
| `formatDate(dateTime)` | `MMM d, yyyy` |
| `formatTime(dateTime)` | `hh:mm a` |
| `formatDateTime(dateTime)` | `MMM d, yyyy • hh:mm a` |
| `formatTimeRange(start, end)` | `9:00 AM – 5:00 PM` |
| `formatClockTime(hhmm)` | Convert `HH:mm` to `hh:mm a` |
| `timezoneLabel()` | `Philippine Time (PHT)` |

### AppRouter (`lib/src/utils/app_router.dart`)
Routes users to their role-based home screen.

| Method | Description |
|--------|-------------|
| `homeRouteFor(user)` | Returns route name based on role |
| `navigateToHome(context, user)` | Navigate to home with replacement |
| `navigateToLogin(context)` | Navigate to login with replacement |

### Idempotency (`lib/src/utils/idempotency.dart`)
Prevents rapid duplicate API calls.

| Method | Description |
|--------|-------------|
| `allow(key, {debounceMs})` | Check if operation is allowed (5s default) |
| `reset(key)` | Clear guard for a key |
| `resetAll()` | Clear all guards |

Also exports `friendlyError(dynamic)` which converts raw exceptions into user-friendly messages (handles email conflicts, invalid OTP, rate limits, network errors, etc.).

---

## Screens

### Auth Screens

| Screen | Route | Description |
|--------|-------|-------------|
| `SplashScreen` | `/` | Entry point; checks session and routes accordingly |
| `LoginScreen` | `/login` | Email/password login with forgot password link |
| `RegisterScreen` | `/register` | Registration with role selection (patient/clinic) & OTP |
| `OtpVerificationScreen` | `/otp-verify` | OTP verification for registration & password reset |
| `ForgotPasswordScreen` | `/forgot-password` | Sends OTP to email for password reset |
| `ChangePasswordScreen` | `/change-password` | Change password with current password |

### Admin Screens (`lib/src/screens/admin/`)

| Screen | Description |
|--------|-------------|
| `AdminHomeScreen` | Main admin shell with 4 tabs |
| `ClinicApplicationsScreen` | Review pending clinic applications (approve/reject) |
| `ActiveClinicsScreen` | Manage active clinics (disable/terminate) |
| `ClinicAppealsScreen` | Review clinic appeals (approve & restore/reject) |
| `ActivityLogsScreen` | View audit trail of all system actions |

### Clinic Screens (`lib/src/screens/clinic/`)

| Screen | Description |
|--------|-------------|
| `ClinicHomeScreen` | Main clinic shell with 4 tabs |
| `ClinicApplicationScreen` | Submit/update clinic application, upload establishment images, set map location, view status, submit appeals |
| `ClinicServicesScreen` | Manage clinic services (add/edit/delete) |
| `ClinicAvailabilityScreen` | Set operating hours & slot durations |
| `ClinicBookingsScreen` | View & respond to patient bookings (accept/deny) |

### Patient Screens (`lib/src/screens/patient/`)

| Screen | Description |
|--------|-------------|
| `PatientHomeScreen` | Main patient shell with 3 tabs (Clinics, My Bookings, Profile) |
| `BookClinicScreen` | Browse clinic details, select service/date/time, book appointment |
| `MyAppointmentsScreen` | View & cancel appointments |

---

## Widgets

### AccountMenuButton (`lib/src/widgets/account_menu_button.dart`)
A reusable popup menu button shown in the AppBar with:
- **Change Password** — navigates to `ChangePasswordScreen`
- **Logout** — triggers the provided logout callback

---

## Database Schema

The `supabase_schema.sql` file contains:

### Tables
- **clinics** — with `avg_rating`, `review_count`, `latitude`, `longitude`, and `establishment_images` (`text[]`) columns
- **clinic_reviews** — patient ratings (1-5) with unique constraint on `(clinic_id, patient_id)`

### Storage
- **`clinic_images` bucket** — public bucket holding clinic establishment photos at `{clinicId}/{timestamp}_{fileName}`

### Row Level Security (RLS)
- Anyone can read reviews
- Patients can insert/update their own reviews
- Storage: everyone can read `clinic_images`; authenticated users can insert/update/delete clinic images

### Triggers
- `update_clinic_ratings()` — automatically recalculates `avg_rating` and `review_count` on the `clinics` table whenever reviews are inserted, updated, or deleted.

---

## Authentication Flow

### Registration
1. User fills registration form (name, email, role, password)
2. `sendRegistrationOtp()` sends a 6-digit OTP via Supabase
3. User enters OTP on `OtpVerificationScreen`
4. `verifyRegistrationOtp()` verifies OTP and creates profile
5. User is routed to their role-based home screen

### Login
1. User enters email/password
2. `authenticate()` signs in and fetches profile
3. `AppRouter.navigateToHome()` routes based on role

### Password Reset
1. User enters email on `ForgotPasswordScreen`
2. OTP is sent via `sendPasswordResetOtp()`
3. User enters OTP + new password on `OtpVerificationScreen`
4. `verifyPasswordResetOtp()` updates the password

### Change Password
1. User provides current + new password
2. `changePassword()` re-authenticates then updates password

---

## Role-Based Features

### Patient
- Browse & search clinics (by name, address, rating)
- View clinic details, hours, and ratings
- Book appointments (select service, date, time slot)
- View & cancel appointments
- Discover clinics on the interactive map
- Change password / logout

### Clinic
- Submit clinic application for admin approval
- Upload up to 5 establishment images for verification
- Pin the exact clinic location on a map
- Manage clinic details (after approval)
- Add/edit/delete services
- Set operating hours & slot durations
- View & respond to patient bookings
- Submit appeals if clinic is disabled/terminated

### Admin
- Review & approve/reject clinic applications
- Inspect submitted establishment images and map coordinates before approving
- Manage active clinics (disable/terminate/reactivate)
- Review clinic appeals
- View system-wide activity logs

---

## Configuration

### `pubspec.yaml`
- **App name:** `my_app`
- **Version:** `1.2.1+4`
- **Dart SDK:** `^3.12.1`
- **Dependencies:** `supabase_flutter ^2.12.4`, `intl ^0.20.2`, `cupertino_icons ^1.0.8`
- **Dev dependencies:** `flutter_launcher_icons`, `flutter_lints ^6.0.0`, `rename_app`
- **App icon:** `lib/src/assets/icon/AppLogo.png`

### `main.dart` — Supabase Configuration
```dart
const supabaseUrl = 'https://wfcguwmkllieugahqtax.supabase.co';
const supabaseAnonKey = 'sb_publishable_s54K1YQTlwqPHi-zv8KqHw_VKsIQlr3';
```

### Routes
| Route | Screen |
|-------|--------|
| `/` | SplashScreen |
| `/login` | LoginScreen |
| `/register` | RegisterScreen |
| `/forgot-password` | ForgotPasswordScreen |
| `/change-password` | ChangePasswordScreen |
| `/patient` | PatientHomeScreen |
| `/clinic` | ClinicHomeScreen |
| `/admin` | AdminHomeScreen |

---

## Testing

The project includes a basic widget test at `test/widget_test.dart` (default Flutter counter smoke test). No comprehensive test suite is currently implemented.

---

## Key Design Patterns

1. **Singleton Service** — `DatabaseService.instance` provides a single point of access to all backend operations.
2. **Model-View separation** — Screens never interact directly with Supabase; they go through the service layer.
3. **Role-based routing** — `AppRouter` centralizes navigation logic based on user role.
4. **Idempotency guard** — Prevents duplicate OTP requests and rapid-fire API calls.
5. **Philippine timezone handling** — All date/time operations are normalized to PHT (UTC+8).
6. **Audit logging** — All significant actions are logged to `activity_logs` for admin review.