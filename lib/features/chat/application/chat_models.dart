enum MessageDeliveryStatus { sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.replyToId,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final String? replyToId;
  final MessageDeliveryStatus deliveryStatus;

  bool get isOptimistic => deliveryStatus == MessageDeliveryStatus.sending;
  bool get isFailed => deliveryStatus == MessageDeliveryStatus.failed;

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? createdAt,
    Object? replyToId = _noChange,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      replyToId: identical(replyToId, _noChange)
          ? this.replyToId
          : replyToId as String?,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      content: (map['content'] as String?)?.trim() ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      replyToId: map['reply_to_id'] as String?,
      deliveryStatus: MessageDeliveryStatus.sent,
    );
  }

  static const _noChange = Object();
}

class DuoState {
  const DuoState({required this.currentUserId, required this.activePartnerId});

  final String? currentUserId;
  final String? activePartnerId;

  bool get isReady => currentUserId != null && activePartnerId != null;

  static const empty = DuoState(currentUserId: null, activePartnerId: null);
}
