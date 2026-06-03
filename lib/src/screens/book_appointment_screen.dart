import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../services/database_service.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String userId;

  const BookAppointmentScreen({super.key, required this.userId});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _serviceController = TextEditingController();
  final _dentistController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _saving = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
    });

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final appointment = Appointment(
      userId: widget.userId,
      patientName: _patientNameController.text.trim(),
      serviceType: _serviceController.text.trim(),
      dentistName: _dentistController.text.trim(),
      dateTime: dateTime,
      contactNumber: _contactController.text.trim(),
      notes: _notesController.text.trim(),
      status: 'Scheduled',
    );

    await DatabaseService.instance.createAppointment(appointment);
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _patientNameController,
                    decoration: const InputDecoration(labelText: 'Patient Name'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter the patient name.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _serviceController,
                    decoration: const InputDecoration(labelText: 'Treatment or Service'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter the service type.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dentistController,
                    decoration: const InputDecoration(labelText: 'Assigned Dentist'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter the dentist name.' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Date: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                      ),
                      TextButton(onPressed: _selectDate, child: const Text('Change')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text('Time: ${_selectedTime.format(context)}')),
                      TextButton(onPressed: _selectTime, child: const Text('Change')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Contact Number'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter a contact number.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveAppointment,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Appointment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
