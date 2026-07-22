enum MessageType { press, ack, ping, pong, reset, winnerBroadcast, groupUpdate }

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
      type: MessageType.values.firstWhere((e) => e.name == json['type']),
      senderId: json['senderId'],
      sequenceId: json['sequenceId'],
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      timestamp: json['timestamp'],
    );
  }
}
