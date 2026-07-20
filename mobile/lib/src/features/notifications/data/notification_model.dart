class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  // For type == 'swap_request' this is a SwapRequest.id; for
  // 'delegation_request' it's a DelegationRequest.id. There's no group_id
  // alongside it, so this alone isn't enough to deep-link to the right
  // group's review screen — surfaced for now in case that changes.
  final String? actionId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.actionId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: json['is_read'] == true,
      actionId: json['action_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      actionId: actionId,
      createdAt: createdAt,
    );
  }
}
