import 'package:flutter/material.dart';

import '../../models/clinic.dart';
import '../../services/database_service.dart';

class ClinicApplicationsScreen extends StatefulWidget {
  const ClinicApplicationsScreen({super.key});

  @override
  State<ClinicApplicationsScreen> createState() => _ClinicApplicationsScreenState();
}

class _ClinicApplicationsScreenState extends State<ClinicApplicationsScreen> {
  List<Clinic> _applications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _loading = true);
    _applications = await DatabaseService.instance.fetchPendingClinicApplications();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _review(Clinic clinic, bool approved) async {
    if (clinic.id == null) return;

    final notesController = TextEditingController(text: clinic.adminNotes);
    if (!approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject application'),
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

    await DatabaseService.instance.reviewClinicApplication(
      clinicId: clinic.id!,
      approved: approved,
      adminNotes: notesController.text.trim(),
    );
    await _loadApplications();
  }

  Widget _establishmentImagesPreview(Clinic clinic) {
    if (!clinic.hasEstablishmentImages) {
      return Text(
        'No establishment images submitted.',
        style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Establishment images (${clinic.establishmentImages.length})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: clinic.establishmentImages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = clinic.establishmentImages[index];
              return GestureDetector(
                onTap: () => _viewImage(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(
                            width: 90,
                            height: 90,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                    errorBuilder: (_, _, _) => Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _viewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: _applications.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No pending clinic applications.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _applications.length,
              itemBuilder: (context, index) {
                final clinic = _applications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clinic.name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        if (clinic.description.isNotEmpty) Text(clinic.description),
                        if (clinic.address.isNotEmpty) Text('Address: ${clinic.address}'),
                        if (clinic.phone.isNotEmpty) Text('Phone: ${clinic.phone}'),
                        if (clinic.hasValidLocation) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Map location: '
                            '${clinic.latitude!.toStringAsFixed(5)}, '
                            '${clinic.longitude!.toStringAsFixed(5)}',
                          ),
                        ],
                        const SizedBox(height: 10),
                        _establishmentImagesPreview(clinic),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _review(clinic, false),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _review(clinic, true),
                              child: const Text('Approve'),
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
