import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../models/clinic_availability.dart';
import '../../services/database_service.dart';
import '../../utils/app_date_time.dart';

class ClinicAvailabilityScreen extends StatefulWidget {
  const ClinicAvailabilityScreen({super.key});

  @override
  State<ClinicAvailabilityScreen> createState() => _ClinicAvailabilityScreenState();
}

class _ClinicAvailabilityScreenState extends State<ClinicAvailabilityScreen> {
  Clinic? _clinic;
  List<ClinicAvailability> _slots = [];
  bool _loading = true;

  String _formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _displayTimeOfDay(TimeOfDay time) =>
      AppDateTime.formatClockTime(_formatTimeOfDay(time));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final user = await DatabaseService.instance.getCurrentUser();
    if (user?.id != null) {
      _clinic = await DatabaseService.instance.fetchClinicByOwner(user!.id!);
      if (_clinic?.id != null) {
        _slots = await DatabaseService.instance.fetchClinicAvailability(_clinic!.id!);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addAvailability() async {
    if (_clinic?.id == null || !_clinic!.isApproved) {
      _showMessage('Your clinic must be approved before setting hours.');
      return;
    }

    int dayOfWeek = 1;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    int duration = 30;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Availability'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(ClinicAvailability.dayNames[i]),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => dayOfWeek = value);
                  },
                ),
                ListTile(
                  title: Text('Start: ${_displayTimeOfDay(startTime)}'),
                  trailing: TextButton(
                    child: const Text('Pick'),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: startTime);
                      if (picked != null) setDialogState(() => startTime = picked);
                    },
                  ),
                ),
                ListTile(
                  title: Text('End: ${_displayTimeOfDay(endTime)}'),
                  trailing: TextButton(
                    child: const Text('Pick'),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: endTime);
                      if (picked != null) setDialogState(() => endTime = picked);
                    },
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: 'Slot duration (minutes)'),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 min')),
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                    DropdownMenuItem(value: 45, child: Text('45 min')),
                    DropdownMenuItem(value: 60, child: Text('60 min')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => duration = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await DatabaseService.instance.addClinicAvailability(
      clinicId: _clinic!.id!,
      dayOfWeek: dayOfWeek,
      startTime: _formatTimeOfDay(startTime),
      endTime: _formatTimeOfDay(endTime),
      slotDurationMinutes: duration,
    );
    await _loadData();
  }

  Future<void> _deleteSlot(ClinicAvailability slot) async {
    if (slot.id == null) return;
    await DatabaseService.instance.deleteClinicAvailability(slot.id!);
    await _loadData();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clinic == null) {
      return const Center(child: Text('Submit your clinic application first.'));
    }

    if (!_clinic!.isApproved) {
      return const Center(child: Text('Availability can be set after admin approval.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _addAvailability,
            icon: const Icon(Icons.add),
            label: const Text('Add Hours'),
          ),
          const SizedBox(height: 16),
          if (_slots.isEmpty)
            const Center(child: Text('No availability windows configured yet.'))
          else
            ..._slots.map(
              (slot) => Card(
                child: ListTile(
                  title: Text(slot.dayLabel),
                  subtitle: Text(
                    '${AppDateTime.formatTimeRange(slot.startTime, slot.endTime)} (${slot.slotDurationMinutes} min slots)',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteSlot(slot),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
