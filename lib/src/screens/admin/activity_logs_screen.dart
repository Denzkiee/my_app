import 'package:flutter/material.dart';

import '../../models/activity_log.dart';
import '../../services/database_service.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  List<ActivityLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    _logs = await DatabaseService.instance.fetchActivityLogs();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: _logs.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No activity recorded yet.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('${log.action} • ${log.entityType}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By: ${log.actorName ?? log.actorId ?? 'Unknown'} (${log.actorRole})'),
                        if (log.createdAt != null) Text('At: ${log.createdAt!.toLocal()}'),
                        if (log.details.isNotEmpty) Text('Details: ${log.details}'),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
