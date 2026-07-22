enum MessageType {
  press,
  ack,
  ping,
  pong,
  reset,
  winnerBroadcast,
  groupUpdate,
  kicked,
}

class SocketMessage {
  final MessageType type;
  final String senderId;
  final String sequenceId;
  final Map<String, dynamic> payload;
  final int timestamp;

  SocketMessage({
    required this.type,
    required this.senderId,
    required this.sequenceId,
    this.payload = const {},
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'senderId': senderId,
        'sequenceId': sequenceId,
        'payload': payload,
        'timestamp': timestamp,
      };

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    return SocketMessage(
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.ack,
      ),
      senderId: json['senderId'] as String? ?? 'unknown',
      sequenceId: json['sequenceId'] as String? ?? '',
      payload: Map<String, dynamic>.from(
          (json['payload'] as Map?)?.cast<String, dynamic>() ?? {}),
      // null-safe: server lama mungkin tidak kirim timestamp
      timestamp: (json['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
