import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/clinic.dart';
import '../../services/database_service.dart';
import 'book_clinic_screen.dart';

class ClinicsMapScreen extends StatefulWidget {
  const ClinicsMapScreen({super.key});

  @override
  State<ClinicsMapScreen> createState() => _ClinicsMapScreenState();
}

class _ClinicsMapScreenState extends State<ClinicsMapScreen> {
  final MapController _mapController = MapController();
  List<Clinic> _clinics = [];
  bool _loading = true;
  Clinic? _selectedClinic;

  // Default center: Manila, Philippines
  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);
  static const double _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    setState(() => _loading = true);
    _clinics = await DatabaseService.instance.fetchClinicsWithLocation();
    if (mounted) setState(() => _loading = false);
  }

  void _onMarkerTapped(Clinic clinic) {
    setState(() => _selectedClinic = clinic);
  }

  void _closePopup() {
    setState(() => _selectedClinic = null);
  }

  void _bookClinic(Clinic clinic) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookClinicScreen(clinic: clinic)),
    ).then((_) => _loadClinics());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clinics Map'),
            if (!_loading && _clinics.isNotEmpty)
              Text(
                '${_clinics.length} clinic${_clinics.length != 1 ? 's' : ''} found',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClinics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clinics.isEmpty
              ? _buildEmptyState()
              : _buildMap(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No clinics with locations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clinics will appear here once they set their location.',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadClinics,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: _defaultZoom,
            minZoom: 5.0,
            maxZoom: 18.0,
          ),
          children: [
            // OpenStreetMap tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.my_app',
            ),
            // Clinic markers
            MarkerLayer(
              markers: _clinics.map((clinic) {
                return Marker(
                  point: LatLng(clinic.latitude!, clinic.longitude!),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _onMarkerTapped(clinic),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedClinic?.id == clinic.id
                            ? Colors.teal.shade700
                            : Colors.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_hospital,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Clinic info popup card
        if (_selectedClinic != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildClinicCard(_selectedClinic!),
          ),
      ],
    );
  }

  Widget _buildClinicCard(Clinic clinic) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: Icon(Icons.local_hospital, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (clinic.avgRating > 0) ...[
                        const SizedBox(height: 4),
                        _buildRatingStars(clinic.avgRating, clinic.reviewCount),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _closePopup,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    clinic.address,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (clinic.phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    clinic.phone,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _bookClinic(clinic),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Book Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating, int count) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final full = i < rating.floor();
          final half = !full && i < rating;
          return Icon(
            full
                ? Icons.star
                : half
                    ? Icons.star_half
                    : Icons.star_border,
            size: 14,
            color: Colors.amber.shade700,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : '—',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }
}