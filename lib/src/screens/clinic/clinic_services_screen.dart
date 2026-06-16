import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Future<Map<String, String>?> _serviceForm({ClinicService? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final priceController = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Service' : 'Edit Service'),
        content: SingleChildScrollView(
          child: Column(
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
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price (PHP)',
                  prefixText: '₱ ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
                'price': priceController.text.trim().isEmpty ? '0' : priceController.text.trim(),
              });
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addService() async {
    if (_clinic?.id == null || !_clinic!.isApproved) {
      _showMessage('Your clinic must be approved before adding services.');
      return;
    }

    final form = await _serviceForm();
    if (form == null) return;

    await DatabaseService.instance.addClinicService(
      clinicId: _clinic!.id!,
      name: form['name']!,
      description: form['description']!,
      price: double.tryParse(form['price']!) ?? 0,
    );
    await _loadData();
  }

  Future<void> _editService(ClinicService service) async {
    if (service.id == null) return;

    final form = await _serviceForm(existing: service);
    if (form == null) return;

    await DatabaseService.instance.updateClinicService(
      serviceId: service.id!,
      name: form['name']!,
      description: form['description']!,
      price: double.tryParse(form['price']!) ?? 0,
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.priceLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (service.description.isNotEmpty) Text(service.description),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editService(service),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteService(service),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
