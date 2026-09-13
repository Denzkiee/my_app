# Map Feature Documentation

## Overview

This document describes the map functionality added to the Dental Booking System. The feature allows:
1. **Clinic Owners** to set their exact location on a map using OpenStreetMap
2. **Patients** to discover clinics visually on an interactive map

---

## Table of Contents

1. [Dependencies](#dependencies)
2. [Database Schema](#database-schema)
3. [Architecture](#architecture)
4. [Phase 1: Provider Location Picker](#phase-1-provider-location-picker)
5. [Phase 2: User-Facing Clinic Map](#phase-2-user-facing-clinic-map)
6. [API Reference](#api-reference)
7. [Usage Guide](#usage-guide)

---

## Dependencies

The following packages were added to `pubspec.yaml`:

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_map` | ^7.0.0 | Renders OpenStreetMap vector tiles |
| `latlong2` | ^0.9.0 | Handles geographic coordinate math |
| `http` | ^1.2.0 | HTTP requests for OpenStreetMap Nominatim geocoding API |

### Installation

Run the following command to install the new dependencies:

```bash
flutter pub get
```

---

## Database Schema

### New Columns Added to `clinics` Table

```sql
ALTER TABLE clinics
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
```

### Clinic Table Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `owner_id` | UUID | References `profiles(id)` |
| `name` | TEXT | Clinic name |
| `description` | TEXT | Clinic description |
| `address` | TEXT | Human-readable address |
| `phone` | TEXT | Contact number |
| `latitude` | DOUBLE PRECISION | Decimal latitude coordinate |
| `longitude` | DOUBLE PRECISION | Decimal longitude coordinate |
| `application_status` | TEXT | `pending`, `approved`, `rejected` |
| `listing_status` | TEXT | `active`, `disabled`, `terminated` |
| `avg_rating` | DOUBLE PRECISION | Average rating (0-5) |
| `review_count` | INTEGER | Number of reviews |

---

## Architecture

### File Structure

```
lib/src/
├── models/
│   └── clinic.dart                    # Updated with latitude/longitude fields
├── screens/
│   ├── clinic/
│   │   ├── clinic_application_screen.dart    # Updated with location picker button
│   │   └── clinic_location_picker_screen.dart # NEW: Location picker for clinics
│   └── patient/
│       ├── clinics_map_screen.dart          # NEW: Map view for patients
│       └── patient_home_screen.dart         # Updated with map tab
└── services/
    └── database_service.dart                # Updated with location methods
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLINIC OWNER FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ClinicApplicationScreen                                         │
│         │                                                        │
│         ▼ (tap "Set Location on Map")                            │
│  ClinicLocationPickerScreen                                      │
│         │                                                        │
│         ▼ (user picks location)                                  │
│  DatabaseService.updateClinicLocation()                          │
│         │                                                        │
│         ▼                                                        │
│  Supabase clinics table (latitude, longitude, address)           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    PATIENT FLOW                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PatientHomeScreen (Map tab)                                     │
│         │                                                        │
│         ▼                                                        │
│  ClinicsMapScreen                                                │
│         │                                                        │
│         ▼                                                        │
│  DatabaseService.fetchClinicsWithLocation()                      │
│         │                                                        │
│         ▼                                                        │
│  FlutterMap with MarkerLayer                                     │
│         │                                                        │
│         ▼ (tap marker)                                           │
│  Clinic Info Card → BookClinicScreen                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Provider Location Picker

### Screen: `ClinicLocationPickerScreen`

**Location:** `lib/src/screens/clinic/clinic_location_picker_screen.dart`

**Purpose:** Allows approved clinic owners to search for their address and pin their exact location on the map — **without requiring GPS permissions**.

> **Note:** This is a custom-built picker using `flutter_map` + OpenStreetMap's Nominatim API. We do NOT use the `osm_search_and_pick` package because it requires device GPS before rendering the map, which causes a "Something went wrong" error on emulators and devices without location services.

#### Features

- **Address Search:** Calls OpenStreetMap Nominatim API directly with debounced input (800ms), limited to Philippines results
- **Map Pin-Picking:** Users can tap anywhere on the map to drop a pin; reverse geocoding automatically resolves the address
- **Location Display:** Shows selected address and coordinates
- **Save Functionality:** Persists location to the database via `DatabaseService.updateClinicLocation()`
- **Pre-population:** If the clinic already has a location, the map opens centered on it with the pin visible

#### UI Components

| Component | Description |
|-----------|-------------|
| Instructions Banner | Explains how to use the location picker |
| Search Bar | Debounced address search with loading indicator |
| Selected Location Panel | Shows selected address and coordinates (green banner) |
| Search Results | Dropdown list of up to 5 matching addresses |
| FlutterMap | Interactive map with OpenStreetMap tiles, defaults to Manila |
| Pin Marker | Red location pin at selected coordinates |
| Save Button | Saves location to database (appears after pinning) |

#### Navigation

```dart
// Navigate to location picker
Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => ClinicLocationPickerScreen(clinic: clinic),
  ),
);

// Returns true if location was saved successfully
```

#### Database Update

```dart
await DatabaseService.instance.updateClinicLocation(
  clinicId: clinicId,
  latitude: 14.5995,
  longitude: 120.9842,
  address: 'Manila, Philippines',
);
```

---

## Phase 2: User-Facing Clinic Map

### Screen: `ClinicsMapScreen`

**Location:** `lib/src/screens/patient/clinics_map_screen.dart`

**Purpose:** Displays all clinics with locations on an interactive map for patients to discover.

#### Features

- **Interactive Map:** Pan, zoom, and tap markers
- **Custom Markers:** Teal-colored circle markers with hospital icon
- **Clinic Info Card:** Bottom popup showing clinic details
- **Book Now Button:** Direct navigation to booking screen
- **Empty State:** Friendly message when no clinics have locations

#### UI Components

| Component | Description |
|-----------|-------------|
| FlutterMap | Main map widget with OpenStreetMap tiles |
| TileLayer | Renders map tiles from OpenStreetMap |
| MarkerLayer | Displays clinic markers |
| GestureDetector | Handles marker tap events |
| Clinic Info Card | Bottom sheet with clinic details |

#### Map Configuration

```dart
FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(14.5995, 120.9842), // Manila
    initialZoom: 12.0,
    minZoom: 5.0,
    maxZoom: 18.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    MarkerLayer(markers: clinicMarkers),
  ],
)
```

#### Marker Customization

```dart
Marker(
  point: LatLng(clinic.latitude!, clinic.longitude!),
  width: 40,
  height: 40,
  child: GestureDetector(
    onTap: () => _onMarkerTapped(clinic),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.teal,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(Icons.local_hospital, color: Colors.white),
    ),
  ),
)
```

---

## API Reference

### DatabaseService Methods

#### `updateClinicLocation()`

Updates the clinic's location coordinates and address.

```dart
Future<Clinic> updateClinicLocation({
  required String clinicId,
  required double latitude,
  required double longitude,
  required String address,
})
```

**Parameters:**
- `clinicId` - The clinic's UUID
- `latitude` - Decimal latitude (e.g., 14.5995)
- `longitude` - Decimal longitude (e.g., 120.9842)
- `address` - Human-readable address string

**Returns:** Updated `Clinic` object

---

#### `fetchClinicsWithLocation()`

Fetches all active clinics that have valid location coordinates.

```dart
Future<List<Clinic>> fetchClinicsWithLocation()
```

**Returns:** List of `Clinic` objects with non-null latitude and longitude

---

### Clinic Model

#### New Fields

```dart
class Clinic {
  // ... existing fields ...
  final double? latitude;
  final double? longitude;
  
  /// Returns true if the clinic has valid coordinates for map display
  bool get hasValidLocation => latitude != null && longitude != null;
}
```

---

## Usage Guide

### For Clinic Owners

1. **Submit Application:** First, submit your clinic application and wait for admin approval
2. **Navigate to Application Screen:** Go to the "Application" tab in the clinic home screen
3. **Tap "Set Location on Map":** Button appears after approval
4. **Search or Tap:** Search for your address or tap directly on the map
5. **Confirm Selection:** Tap "Select This Location" on the map
6. **Save:** Tap the save button in the app bar

### For Patients

1. **Open Map Tab:** Tap the "Map" tab in the bottom navigation
2. **Browse Clinics:** View all clinics with locations on the map
3. **Tap Marker:** Tap any clinic marker to see details
4. **Book Appointment:** Tap "Book Now" to navigate to the booking screen

---

## Configuration

### Default Map Center

The map defaults to Manila, Philippines:

```dart
static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);
static const double _defaultZoom = 12.0;
```

To change the default location, modify these values in `clinics_map_screen.dart`.

### Map Tile Provider

Currently using OpenStreetMap's free tile server:

```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.example.my_app',
)
```

**Note:** For production apps with high traffic, consider using a paid tile provider or self-hosted tiles.

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Map not loading | Check internet connection; OpenStreetMap requires internet |
| Markers not appearing | Ensure clinics have valid latitude/longitude in database |
| Location picker not showing | Clinic must be approved and have active listing |
| "No clinics with locations" | Clinics need to set their location first |
| "Something went wrong" on location picker | **Fixed:** The custom picker no longer requires GPS — it defaults to Manila instead of requesting device location |

### Debug Queries

```sql
-- Check clinics with locations
SELECT id, name, latitude, longitude, address 
FROM clinics 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Check clinic count by location status
SELECT 
  CASE 
    WHEN latitude IS NOT NULL THEN 'Has Location'
    ELSE 'No Location'
  END as location_status,
  COUNT(*) as clinic_count
FROM clinics
GROUP BY location_status;
```

---

## Future Enhancements

Potential improvements for future iterations:

1. **Distance Calculation:** Show distance from user's location
2. **Directions:** Integrate routing to clinics
3. **Clustering:** Group nearby markers at low zoom levels
4. **Search by Radius:** Find clinics within X km
5. **Custom Marker Icons:** Different icons for different clinic types
6. **Offline Maps:** Cache map tiles for offline viewing
7. **Street View:** Show street-level imagery

---

## License & Attribution

- **OpenStreetMap:** Map data © OpenStreetMap contributors
- **flutter_map:** BSD-3-Clause License
- **osm_search_and_pick:** Check package repository for license

---

## Support

For issues or questions regarding the map feature, please refer to:
- [flutter_map documentation](https://docs.fleaflet.dev/)
- [OpenStreetMap help](https://help.openstreetmap.org/)
- [Supabase documentation](https://supabase.com/docs)