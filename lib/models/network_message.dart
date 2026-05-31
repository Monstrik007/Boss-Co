import 'dart:convert';

import '../core/constants.dart';

class NetworkMessage {
  NetworkMessage({
    required this.type,
    this.payload = const {},
    this.senderId,
  });

  final MessageType type;
  final Map<String, dynamic> payload;
  final String? senderId;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
        if (senderId != null) 'senderId': senderId,
      };

  factory NetworkMessage.fromJson(Map<String, dynamic> json) =>
      NetworkMessage(
        type: MessageType.values.byName(json['type'] as String),
        payload: Map<String, dynamic>.from(
          json['payload'] as Map? ?? {},
        ),
        senderId: json['senderId'] as String?,
      );

  String encode() => '${jsonEncode(toJson())}\n';

  static NetworkMessage? decode(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      return NetworkMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
