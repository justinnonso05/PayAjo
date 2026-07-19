class ChatMessage {
  final String id;
  final String groupId;
  final String? senderId;
  final String message;
  final String? imageUrl;
  final bool isSystem;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.message,
    this.imageUrl,
    required this.isSystem,
    this.isEdited = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  ChatMessage copyWith({String? message, bool? isEdited, bool? isDeleted}) {
    return ChatMessage(
      id: id,
      groupId: groupId,
      senderId: senderId,
      message: message ?? this.message,
      imageUrl: imageUrl,
      isSystem: isSystem,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString(),
      message: json['message']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      isSystem: json['is_system'] == true,
      isEdited: json['is_edited'] == true,
      isDeleted: json['is_deleted'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
