import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../models/clinic_service.dart';
import '../../services/database_service.dart';

class ClinicServicesScreen extends StatefulWidget {
  const ClinicServicesScreen({super.key});

  @override
  State<ClinicServicesScreen> createState() => _ClinicServicesScreenState();
}

class _ClinicServicesScreenState extends State<ClinicServicesScreen> {
  Clinic? _clinic;
  List<ClinicService> _services = [];
  bool _loading = true;

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
        _services = await DatabaseService.instance.fetchClinicServices(_clinic!.id!);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addService() async {
    if (_clinic?.id == null || !_clinic!.isApproved) {
      _showMessage('Your clinic must be approved before adding services.');
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Service name'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty) return;

    await DatabaseService.instance.addClinicService(
      clinicId: _clinic!.id!,
      name: nameController.text.trim(),
      description: descController.text.trim(),
    );
    await _loadData();
  }

  Future<void> _deleteService(ClinicService service) async {
    if (service.id == null) return;
    await DatabaseService.instance.deleteClinicService(service.id!);
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
      return const Center(child: Text('Services can be added after admin approval.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _addService,
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
          ),
          const SizedBox(height: 16),
          if (_services.isEmpty)
            const Center(child: Text('No services listed yet.'))
          else
            ..._services.map(
              (service) => Card(
                child: ListTile(
                  title: Text(service.name),
                  subtitle: service.description.isNotEmpty ? Text(service.description) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteService(service),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
