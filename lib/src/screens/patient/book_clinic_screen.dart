import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../models/clinic.dart';
import '../../models/clinic_availability.dart';
import '../../models/clinic_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_date_time.dart';

class BookClinicScreen extends StatefulWidget {
  final Clinic clinic;

  const BookClinicScreen({super.key, required this.clinic});

  @override
  State<BookClinicScreen> createState() => _BookClinicScreenState();
}

class _BookClinicScreenState extends State<BookClinicScreen> {
  List<ClinicService> _services = [];
  List<ClinicAvailability> _availability = [];
  List<Appointment> _bookedSlots = [];
  ClinicService? _selectedService;
  DateTime _selectedDate = AppDateTime.philippineNow().add(const Duration(days: 1));
  double _slotSliderValue = 0;
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    _services = await db.fetchClinicServices(widget.clinic.id!);
    _availability = await db.fetchClinicAvailability(widget.clinic.id!);
    _bookedSlots = await db.fetchBookedSlots(widget.clinic.id!, _selectedDate);
    if (_services.isNotEmpty) _selectedService = _services.first;
    _slotSliderValue = 0;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: AppDateTime.philippineNow(),
      lastDate: AppDateTime.philippineNow().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _slotSliderValue = 0;
    });
    _bookedSlots = await DatabaseService.instance.fetchBookedSlots(widget.clinic.id!, _selectedDate);
    if (mounted) setState(() {});
  }

  List<DateTime> get _availableSlots {
    final slots = <DateTime>[];
    for (final window in _availability) {
      slots.addAll(window.slotsForDate(_selectedDate));
    }
    slots.sort();

    final bookedTimes = _bookedSlots
        .map((a) => AppDateTime.toPhilippine(a.appointmentDateTime))
        .map((dt) => DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute))
        .toSet();

    return slots.where((slot) {
      final phSlot = AppDateTime.toPhilippine(slot);
      final normalized = DateTime(phSlot.year, phSlot.month, phSlot.day, phSlot.hour, phSlot.minute);
      return !bookedTimes.contains(normalized);
    }).toList();
  }

  DateTime? get _selectedSlot {
    final slots = _availableSlots;
    if (slots.isEmpty) return null;
    final index = _slotSliderValue.round().clamp(0, slots.length - 1);
    return slots[index];
  }

  Future<void> _book() async {
    final user = await DatabaseService.instance.getCurrentUser();
    if (user?.id == null) return;

    if (_selectedService == null) {
      _showMessage('Please select a service.');
      return;
    }
    final selectedSlot = _selectedSlot;
    if (selectedSlot == null) {
      _showMessage('Please select an available time slot.');
      return;
    }
    if (_contactController.text.trim().isEmpty) {
      _showMessage('Please enter a contact number.');
      return;
    }

    setState(() => _saving = true);
    try {
      await DatabaseService.instance.createAppointment(
        Appointment(
          patientId: user!.id!,
          clinicId: widget.clinic.id!,
          serviceId: _selectedService!.id,
          serviceName: _selectedService!.name,
          appointmentDateTime: selectedSlot,
          contactNumber: _contactController.text.trim(),
          notes: _notesController.text.trim(),
          status: 'pending',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking submitted. Awaiting clinic approval.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildTimeSlider() {
    final slots = _availableSlots;
    if (_availability.isEmpty) {
      return const Text('No availability configured for this clinic.');
    }
    if (slots.isEmpty) {
      return const Text('No open slots on this date.');
    }

    final selected = _selectedSlot!;
    final first = AppDateTime.formatTime(slots.first);
    final last = AppDateTime.formatTime(slots.last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.teal.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  AppDateTime.formatTime(selected),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppDateTime.formatDate(selected)} (${AppDateTime.timezoneLabel()})',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          value: _slotSliderValue.clamp(0, slots.length - 1),
          min: 0,
          max: (slots.length - 1).toDouble(),
          divisions: slots.length > 1 ? slots.length - 1 : 1,
          label: AppDateTime.formatTime(selected),
          onChanged: (value) => setState(() => _slotSliderValue = value),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(first, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text(last, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Book — ${widget.clinic.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_services.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('This clinic has not listed any services yet.'),
                      ),
                    )
                  else
                    DropdownButtonFormField<ClinicService>(
                      initialValue: _selectedService,
                      decoration: const InputDecoration(labelText: 'Service'),
                      items: _services
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.name} • ${s.priceLabel}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _selectedService = value),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${AppDateTime.formatDate(_selectedDate)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(onPressed: _pickDate, child: const Text('Change')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Select appointment time', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildTimeSlider(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Contact Number'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _book,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Request Appointment'),
                  ),
                ],
              ),
            ),
    );
  }
}
