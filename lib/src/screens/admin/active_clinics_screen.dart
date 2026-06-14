import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../services/database_service.dart';

class ActiveClinicsScreen extends StatefulWidget {
  const ActiveClinicsScreen({super.key});

  @override
  State<ActiveClinicsScreen> createState() => _ActiveClinicsScreenState();
}

class _ActiveClinicsScreenState extends State<ActiveClinicsScreen> {
  List<Clinic> _clinics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    setState(() => _loading = true);
    _clinics = await DatabaseService.instance.fetchActiveClinicsForAdmin();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _disable(Clinic clinic) async {
    if (clinic.id == null) return;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disable ${clinic.name}?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Why is this clinic being disabled?',
          ),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disable')),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseService.instance.disableClinic(
      clinicId: clinic.id!,
      reason: reasonController.text.trim(),
    );
    await _loadClinics();
  }

  Future<void> _terminate(Clinic clinic) async {
    if (clinic.id == null) return;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terminate ${clinic.name}?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Termination reason (required)',
            hintText: 'Explain why this clinic is being terminated',
          ),
          minLines: 3,
          maxLines: 5,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Terminate')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (reasonController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A termination reason is required.')),
      );
      return;
    }

    await DatabaseService.instance.terminateClinic(
      clinicId: clinic.id!,
      reason: reasonController.text.trim(),
    );
    await _loadClinics();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadClinics,
      child: _clinics.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No active clinics listed.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _clinics.length,
              itemBuilder: (context, index) {
                final clinic = _clinics[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clinic.name, style: Theme.of(context).textTheme.titleMedium),
                        if (clinic.address.isNotEmpty) Text(clinic.address),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                clinic.hoursSummary,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _disable(clinic),
                              child: const Text('Disable'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                              onPressed: () => _terminate(clinic),
                              child: const Text('Terminate'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
