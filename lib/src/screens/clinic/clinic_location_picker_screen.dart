import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../models/clinic.dart';
import '../../services/database_service.dart';

class ClinicLocationPickerScreen extends StatefulWidget {
  final Clinic? clinic;

  const ClinicLocationPickerScreen({super.key, this.clinic});

  @override
  State<ClinicLocationPickerScreen> createState() => _ClinicLocationPickerScreenState();
}

class _ClinicLocationPickerScreenState extends State<ClinicLocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _saving = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';
  bool _locationPicked = false;

  List<_OSMResult> _searchResults = [];
  Timer? _debounce;
  bool _searching = false;

  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);
  static const double _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    if (widget.clinic != null && widget.clinic!.hasValidLocation) {
      _selectedLatitude = widget.clinic!.latitude;
      _selectedLongitude = widget.clinic!.longitude;
      _selectedAddress = widget.clinic!.address;
      _locationPicked = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _saveLocation() async {
    if (_selectedLatitude == null || _selectedLongitude == null || _selectedAddress.isEmpty) {
      _showMessage('Please select a location on the map.');
      return;
    }
    if (widget.clinic?.id == null) {
      _showMessage('No clinic found. Please submit your application first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.updateClinicLocation(
        clinicId: widget.clinic!.id!,
        latitude: _selectedLatitude!,
        longitude: _selectedLongitude!,
        address: _selectedAddress,
      );
      if (!mounted) return;
      _showMessage('Location saved successfully!');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage('Error saving location: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=ph',
      );
      final response = await http.get(url, headers: {'User-Agent': 'DentalBookingApp/1.0'});
      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        setState(() {
          _searchResults = results.map((r) => _OSMResult(
            displayName: r['display_name'] as String,
            lat: double.parse(r['lat'] as String),
            lon: double.parse(r['lon'] as String),
          )).toList();
        });
      }
    } catch (e) {
      _showMessage('Search failed. Please check your internet connection.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {'User-Agent': 'DentalBookingApp/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
    } catch (e) {
      // fallback
    }
    return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lon.toStringAsFixed(6)}';
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedLatitude = point.latitude;
      _selectedLongitude = point.longitude;
      _locationPicked = true;
    });
    final address = await _getAddressFromCoordinates(point.latitude, point.longitude);
    if (mounted) {
      setState(() { _selectedAddress = address; });
    }
  }

  void _onSearchResultTap(_OSMResult result) {
    _mapController.move(LatLng(result.lat, result.lon), 15.0);
    setState(() {
      _selectedLatitude = result.lat;
      _selectedLongitude = result.lon;
      _selectedAddress = result.displayName;
      _locationPicked = true;
      _searchResults = [];
    });
    _focusNode.unfocus();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Clinic Location'),
        actions: [
          if (_locationPicked)
            TextButton.icon(
              onPressed: _saving ? null : _saveLocation,
              icon: _saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(_saving ? 'Saving...' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.teal.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text('Set Your Clinic Location', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Search for your clinic address or tap on the map to pinpoint your exact location.', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search for address...',
                prefixIcon: _searching
                    ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchResults = []); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 800), () { _searchAddress(value); });
              },
            ),
          ),
          if (_locationPicked && _selectedLatitude != null && _selectedLongitude != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Location Selected', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_selectedAddress, style: const TextStyle(fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Lat: ${_selectedLatitude!.toStringAsFixed(6)}, Lng: ${_selectedLongitude!.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.teal),
                    title: Text(result.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    onTap: () => _onSearchResultTap(result),
                  );
                },
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLatitude != null && _selectedLongitude != null
                    ? LatLng(_selectedLatitude!, _selectedLongitude!)
                    : _defaultCenter,
                initialZoom: _locationPicked ? 15.0 : _defaultZoom,
                minZoom: 5.0,
                maxZoom: 18.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.my_app',
                ),
                if (_locationPicked && _selectedLatitude != null && _selectedLongitude != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_selectedLatitude!, _selectedLongitude!),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OSMResult {
  final String displayName;
  final double lat;
  final double lon;

  _OSMResult({required this.displayName, required this.lat, required this.lon});
}
