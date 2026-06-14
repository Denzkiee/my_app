import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../services/database_service.dart';

class ClinicAppealsScreen extends StatefulWidget {
  const ClinicAppealsScreen({super.key});

  @override
  State<ClinicAppealsScreen> createState() => _ClinicAppealsScreenState();
}

class _ClinicAppealsScreenState extends State<ClinicAppealsScreen> {
  List<Clinic> _appeals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    setState(() => _loading = true);
    _appeals = await DatabaseService.instance.fetchPendingClinicAppeals();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _review(Clinic clinic, bool approved) async {
    if (clinic.id == null) return;

    final notesController = TextEditingController();
    if (!approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject appeal'),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            minLines: 2,
            maxLines: 4,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await DatabaseService.instance.reviewClinicAppeal(
      clinicId: clinic.id!,
      approved: approved,
      adminNotes: notesController.text.trim(),
    );
    await _loadAppeals();
  }

  String _listingLabel(Clinic clinic) {
    if (clinic.isTerminated) return 'Terminated';
    if (clinic.isDisabled) return 'Disabled';
    return clinic.listingStatus;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadAppeals,
      child: _appeals.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No pending clinic appeals.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _appeals.length,
              itemBuilder: (context, index) {
                final clinic = _appeals[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clinic.name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Chip(label: Text(_listingLabel(clinic))),
                        if (clinic.statusReason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Original reason: ${clinic.statusReason}'),
                        ],
                        const SizedBox(height: 8),
                        Text('Appeal message:', style: Theme.of(context).textTheme.labelLarge),
                        Text(clinic.appealMessage),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _review(clinic, false),
                              child: const Text('Reject Appeal'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _review(clinic, true),
                              child: const Text('Approve & Restore'),
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
