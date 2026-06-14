class ActivityLog {
  final String? id;
  final String? actorId;
  final String actorRole;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> details;
  final DateTime? createdAt;
  final String? actorName;

  const ActivityLog({
    this.id,
    this.actorId,
    required this.actorRole,
    required this.action,
    required this.entityType,
    this.entityId,
    this.details = const {},
    this.createdAt,
    this.actorName,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    final profiles = map['profiles'];

    return ActivityLog(
      id: map['id'] as String?,
      actorId: map['actor_id'] as String?,
      actorRole: map['actor_role'] as String,
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      details: map['details'] is Map
          ? Map<String, dynamic>.from(map['details'] as Map)
          : {},
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : null,
      actorName: profiles is Map ? profiles['full_name'] as String? : null,
    );
  }
}
