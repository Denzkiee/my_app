import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../models/user.dart';
import '../../services/database_service.dart';

class ClinicApplicationScreen extends StatefulWidget {
  const ClinicApplicationScreen({super.key});

  @override
  State<ClinicApplicationScreen> createState() => _ClinicApplicationScreenState();
}

class _ClinicApplicationScreenState extends State<ClinicApplicationScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  User? _user;
  Clinic? _clinic;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _user = await DatabaseService.instance.getCurrentUser();
    if (_user?.id != null) {
      _clinic = await DatabaseService.instance.fetchClinicByOwner(_user!.id!);
      if (_clinic != null) {
        _nameController.text = _clinic!.name;
        _descriptionController.text = _clinic!.description;
        _addressController.text = _clinic!.address;
        _phoneController.text = _clinic!.phone;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (_user?.id == null) return;
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Clinic name is required.');
      return;
    }

    setState(() => _saving = true);
    try {
      _clinic = await DatabaseService.instance.submitClinicApplication(
        ownerId: _user!.id!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        existingClinicId: _clinic?.id,
      );
      if (!mounted) return;
      _showMessage('Application submitted. Waiting for admin approval.');
      setState(() {});
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDetails() async {
    if (_clinic?.id == null || !_clinic!.isApproved) return;
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Clinic name is required.');
      return;
    }

    setState(() => _saving = true);
    try {
      _clinic = await DatabaseService.instance.updateClinicDetails(
        clinicId: _clinic!.id!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      _showMessage('Clinic details updated.');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _statusBanner() {
    if (_clinic == null) {
      return const Card(
        color: Color(0xFFE3F2FD),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Submit your clinic details to apply for listing on the patient directory.'),
        ),
      );
    }

    Color color;
    String message;
    if (_clinic!.isApproved) {
      color = Colors.green.shade100;
      message = 'Approved — your clinic is visible to patients.';
    } else if (_clinic!.isRejected) {
      color = Colors.red.shade100;
      message = 'Rejected — update your details and resubmit.${_clinic!.adminNotes.isNotEmpty ? '\nAdmin note: ${_clinic!.adminNotes}' : ''}';
    } else {
      color = Colors.orange.shade100;
      message = 'Pending — an admin is reviewing your application.';
    }

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final canEditApproved = _clinic?.isApproved == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusBanner(),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Clinic Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 20),
          if (canEditApproved)
            ElevatedButton(
              onPressed: _saving ? null : _saveDetails,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Clinic Details'),
            )
          else
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_clinic == null ? 'Submit Application' : 'Resubmit Application'),
            ),
        ],
      ),
    );
  }
}
