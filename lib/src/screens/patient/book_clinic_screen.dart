import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../models/clinic.dart';
import '../../models/clinic_availability.dart';
import '../../models/clinic_service.dart';
import '../../services/database_service.dart';

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
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _selectedSlot;
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
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedSlot = null;
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
        .map((a) => a.appointmentDateTime)
        .map((dt) => DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute))
        .toSet();

    return slots.where((slot) {
      final normalized = DateTime(slot.year, slot.month, slot.day, slot.hour, slot.minute);
      return !bookedTimes.contains(normalized);
    }).toList();
  }

  Future<void> _book() async {
    final user = await DatabaseService.instance.getCurrentUser();
    if (user?.id == null) return;

    if (_selectedService == null) {
      _showMessage('Please select a service.');
      return;
    }
    if (_selectedSlot == null) {
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
          appointmentDateTime: _selectedSlot!,
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
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedService = value),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(onPressed: _pickDate, child: const Text('Change')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Available times', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_availability.isEmpty)
                    const Text('No availability configured for this clinic.')
                  else if (_availableSlots.isEmpty)
                    const Text('No open slots on this date.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableSlots.map((slot) {
                        final selected = _selectedSlot == slot;
                        return ChoiceChip(
                          label: Text(TimeOfDay.fromDateTime(slot).format(context)),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedSlot = slot),
                        );
                      }).toList(),
                    ),
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
