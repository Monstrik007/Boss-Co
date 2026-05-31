import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Сохранённая сессия подчинённого для повторного входа в комнату.
class SavedPlayerSession {
  const SavedPlayerSession({
    required this.playerName,
    required this.playerId,
    required this.sessionToken,
    required this.roomHost,
    required this.roomPort,
    required this.roomName,
    required this.roomId,
  });

  final String playerName;
  final String playerId;
  final String sessionToken;
  final String roomHost;
  final int roomPort;
  final String roomName;
  final String roomId;

  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'playerId': playerId,
        'sessionToken': sessionToken,
        'roomHost': roomHost,
        'roomPort': roomPort,
        'roomName': roomName,
        'roomId': roomId,
      };

  factory SavedPlayerSession.fromJson(Map<String, dynamic> json) {
    return SavedPlayerSession(
      playerName: json['playerName'] as String? ?? '',
      playerId: json['playerId'] as String? ?? '',
      sessionToken: json['sessionToken'] as String? ?? '',
      roomHost: json['roomHost'] as String? ?? '',
      roomPort: json['roomPort'] as int? ?? 0,
      roomName: json['roomName'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
    );
  }

  bool get isValid =>
      playerName.isNotEmpty &&
      playerId.isNotEmpty &&
      sessionToken.isNotEmpty &&
      roomHost.isNotEmpty &&
      roomPort > 0;
}

class SavedSessionService {
  static const _key = 'saved_player_session';

  static Future<SavedPlayerSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final session = SavedPlayerSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return session.isValid ? session : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SavedPlayerSession session) async {
    if (!session.isValid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
