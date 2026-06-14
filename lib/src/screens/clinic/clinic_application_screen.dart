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
  final _appealController = TextEditingController();

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
        _appealController.text = _clinic!.appealMessage;
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
    if (_clinic?.id == null || !_clinic!.isApproved || !_clinic!.isActiveListing) return;
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

  Future<void> _submitAppeal() async {
    if (_clinic?.id == null) return;
    if (_appealController.text.trim().isEmpty) {
      _showMessage('Please explain why your clinic should be restored.');
      return;
    }

    setState(() => _saving = true);
    try {
      _clinic = await DatabaseService.instance.submitClinicAppeal(
        clinicId: _clinic!.id!,
        message: _appealController.text.trim(),
      );
      _showMessage('Appeal submitted. An admin will review it.');
      setState(() {});
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

    if (_clinic!.isHiddenFromPatients) {
      color = Colors.red.shade100;
      final action = _clinic!.isTerminated ? 'terminated' : 'disabled';
      message =
          'Your clinic has been $action and is hidden from patients.${_clinic!.statusReason.isNotEmpty ? '\nReason: ${_clinic!.statusReason}' : ''}';
    } else if (_clinic!.isApproved && _clinic!.isActiveListing) {
      color = Colors.green.shade100;
      message = 'Approved — your clinic is visible to patients.';
    } else if (_clinic!.isRejected) {
      color = Colors.red.shade100;
      message =
          'Rejected — update your details and resubmit.${_clinic!.adminNotes.isNotEmpty ? '\nAdmin note: ${_clinic!.adminNotes}' : ''}';
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

  Widget _appealSection() {
    if (_clinic == null || !_clinic!.isHiddenFromPatients) return const SizedBox.shrink();

    if (_clinic!.hasPendingAppeal) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Your appeal is pending admin review.'),
        ),
      );
    }

    if (_clinic!.appealStatus == 'rejected') {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Your last appeal was rejected.${_clinic!.adminNotes.isNotEmpty ? '\nAdmin note: ${_clinic!.adminNotes}' : ''}\nYou may submit a new appeal below.',
          ),
        ),
      );
    }

    if (!_clinic!.canSubmitAppeal) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Submit an appeal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _appealController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Why should your clinic be restored?',
            hintText: 'Explain corrective actions or context for the admin.',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saving ? null : _submitAppeal,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Appeal'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final canEditApproved = _clinic?.isApproved == true && _clinic!.isActiveListing;
    final fieldsEnabled = _clinic == null || !_clinic!.isHiddenFromPatients;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusBanner(),
          const SizedBox(height: 16),
          _appealSection(),
          if (_clinic?.isHiddenFromPatients == true) const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: fieldsEnabled,
            decoration: const InputDecoration(labelText: 'Clinic Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: fieldsEnabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            enabled: fieldsEnabled,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            enabled: fieldsEnabled,
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
          else if (fieldsEnabled)
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
