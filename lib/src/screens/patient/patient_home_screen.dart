import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../models/user.dart' as models;
import '../../services/database_service.dart';
import '../../utils/app_date_time.dart';
import '../../widgets/account_menu_button.dart';
import '../change_password_screen.dart';
import '../login_screen.dart';
import 'book_clinic_screen.dart';
import 'my_appointments_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  static const routeName = '/patient';

  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _tabIndex = 0;
  List<Clinic> _clinics = [];
  bool _loading = true;
  models.User? _currentUser;

  // Search & filters
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _addressFilter = '';
  double _minRating = 0;

  @override
  void initState() {
    super.initState();
    _loadClinics();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClinics() async {
    setState(() => _loading = true);
    _clinics = await DatabaseService.instance.searchClinics(
      query: _searchQuery.isNotEmpty ? _searchQuery : null,
      addressFilter: _addressFilter.isNotEmpty ? _addressFilter : null,
      minRating: _minRating > 0 ? _minRating : null,
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await DatabaseService.instance.getCurrentUser();
    if (mounted) setState(() {});
  }

  void _onSearch() {
    _searchQuery = _searchController.text.trim();
    _loadClinics();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _addressFilter = '';
      _minRating = 0;
    });
    _loadClinics();
  }

  Future<void> _logout() async {
    await DatabaseService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  String _appBarTitle() {
    switch (_tabIndex) {
      case 0:
        return 'Find Clinics';
      case 1:
        return 'My Appointments';
      case 2:
        return 'My Profile';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        actions: [
          AccountMenuButton(onLogout: _logout),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildClinicsTab(),
          const MyAppointmentsScreen(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_hospital_outlined), label: 'Clinics'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'My Bookings'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Rating stars widget
  // -------------------------------------------------------------------------

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
            size: 16,
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

  // -------------------------------------------------------------------------
  // Filter bottom sheet
  // -------------------------------------------------------------------------

  void _showFilterSheet() {
    String tempAddress = _addressFilter;
    double tempRating = _minRating;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Extract unique addresses from loaded clinics
            final addresses = _clinics
                .map((c) => c.address.trim())
                .where((a) => a.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempAddress = '';
                            tempRating = 0;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Location', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (addresses.isEmpty)
                    Text('No addresses available', style: TextStyle(color: Colors.grey.shade500))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: tempAddress.isEmpty,
                          onSelected: (_) => setSheetState(() => tempAddress = ''),
                        ),
                        ...addresses.map(
                          (addr) => FilterChip(
                            label: Text(addr.length > 25 ? '${addr.substring(0, 25)}…' : addr),
                            selected: tempAddress == addr,
                            onSelected: (_) => setSheetState(() => tempAddress = addr),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  const Text('Minimum Rating', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final starVal = (i + 1).toDouble();
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            tempRating = tempRating == starVal ? 0 : starVal;
                          }),
                          child: Icon(
                            starVal <= tempRating ? Icons.star : Icons.star_border,
                            size: 32,
                            color: starVal <= tempRating ? Colors.amber.shade700 : Colors.grey.shade400,
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        tempRating > 0 ? '${tempRating.toInt()}+' : 'Any',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _addressFilter = tempAddress;
                          _minRating = tempRating;
                        });
                        _loadClinics();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Hours section
  // -------------------------------------------------------------------------

  Widget _buildHoursSection(Clinic clinic) {
    if (clinic.availability.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Open hours not listed yet',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    final sorted = [...clinic.availability]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                'Open hours',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...sorted.map(
            (slot) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      slot.dayLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  Text(
                    AppDateTime.formatTimeRange(slot.startTime, slot.endTime),
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Clinics tab with search & filters
  // -------------------------------------------------------------------------

  Widget _buildClinicsTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search clinics, address, services…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _onSearch(),
                  onChanged: (value) {
                    if (value.isEmpty && _searchQuery.isNotEmpty) {
                      _onSearch();
                    }
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Filter button
              Badge(
                isLabelVisible: _addressFilter.isNotEmpty || _minRating > 0,
                label: Text(
                  '${(_addressFilter.isNotEmpty ? 1 : 0) + (_minRating > 0 ? 1 : 0)}',
                ),
                child: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: _addressFilter.isNotEmpty || _minRating > 0
                        ? Colors.teal.shade50
                        : Colors.grey.shade100,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Active filter chips
        if (_addressFilter.isNotEmpty || _minRating > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (_addressFilter.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(_addressFilter.length > 20
                          ? '${_addressFilter.substring(0, 20)}…'
                          : _addressFilter),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() => _addressFilter = '');
                        _loadClinics();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (_minRating > 0)
                  Chip(
                    label: Text('${_minRating.toInt()}+ stars'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _minRating = 0);
                      _loadClinics();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),

        // Clinic list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadClinics,
                  child: _clinics.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No clinics match your search.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: _clearFilters,
                                    child: const Text('Clear filters & try again'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _clinics.length,
                          itemBuilder: (context, index) {
                            final clinic = _clinics[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => BookClinicScreen(clinic: clinic)),
                                  );
                                  if (_tabIndex == 1 && mounted) setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.teal.shade50,
                                        child:
                                            Icon(Icons.local_hospital, color: Colors.teal.shade700),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              clinic.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600, fontSize: 16),
                                            ),
                                            const SizedBox(height: 4),
                                            // Rating row
                                            _buildRatingStars(clinic.avgRating, clinic.reviewCount),
                                            const SizedBox(height: 4),
                                            if (clinic.address.isNotEmpty) ...[
                                              Row(
                                                children: [
                                                  Icon(Icons.location_on_outlined,
                                                      size: 14, color: Colors.grey.shade500),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      clinic.address,
                                                      style:
                                                          TextStyle(color: Colors.grey.shade700),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (clinic.description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                clinic.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: Colors.grey.shade600, fontSize: 13),
                                              ),
                                            ],
                                            _buildHoursSection(clinic),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: Colors.grey.shade500),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Profile tab
  // -------------------------------------------------------------------------

  Widget _buildProfileTab() {
    final user = _currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.teal.shade100,
                child: Icon(Icons.person, size: 48, color: Colors.teal.shade700),
              ),
              const SizedBox(height: 16),
              Text(
                user?.fullName ?? 'Loading...',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Patient',
                  style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Account details card
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  child: Text(
                    'Account Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _ProfileInfoTile(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: user?.fullName ?? '---',
                ),
                _ProfileInfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? '---',
                ),
                _ProfileInfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: user?.role.toUpperCase() ?? '---',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Actions card
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.lock_outline, color: Colors.teal.shade700),
                title: const Text('Change Password'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                onTap: () {
                  Navigator.of(context).pushNamed(ChangePasswordScreen.routeName);
                },
              ),
              Divider(height: 1, indent: 56, color: Colors.grey.shade200),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade400),
                title: Text('Logout', style: TextStyle(color: Colors.red.shade400)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}