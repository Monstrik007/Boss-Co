import 'network_service.dart';

/// Держит один активный сервер — при пересоздании комнаты старый останавливается.
class GameServerRegistry {
  static GameServer? _active;

  static GameServer? get active => _active;

  static Future<void> stopActive() async {
    final old = _active;
    _active = null;
    await old?.stop();
  }

  static void register(GameServer server) {
    _active = server;
  }
}
