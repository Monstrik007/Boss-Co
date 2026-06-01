import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/game_models.dart';
import '../models/network_message.dart';
import 'line_socket_buffer.dart';
import 'saved_session_service.dart';

class DiscoveredRoom {
  DiscoveredRoom({
    required this.roomId,
    required this.name,
    required this.host,
    required this.port,
  });

  final String roomId;
  final String name;
  final String host;
  final int port;
}

class DiscoveryService {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  final _roomsController = StreamController<List<DiscoveredRoom>>.broadcast();
  final Map<String, DiscoveredRoom> _rooms = {};

  Stream<List<DiscoveredRoom>> get roomsStream => _roomsController.stream;
  List<DiscoveredRoom> get rooms =>
      _rooms.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> startBroadcast({
    required String roomName,
    required String roomId,
    required int port,
    String? hostIp,
  }) async {
    await stopBroadcast();
    final attributes = <String, String>{
      'lib': 'bonsoir',
      'roomId': roomId,
    };
    if (hostIp != null && hostIp.isNotEmpty) {
      attributes['host'] = hostIp;
    }

    final service = BonsoirService(
      name: roomName,
      type: GameConstants.serviceType,
      port: port,
      attributes: attributes,
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    await _broadcast!.start();
  }

  Future<void> stopBroadcast() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  Future<void> startDiscovery() async {
    await stopDiscovery();
    _rooms.clear();
    _emitRooms();

    _discovery = BonsoirDiscovery(type: GameConstants.serviceType);
    await _discovery!.initialize();

    final stream = _discovery!.eventStream;
    if (stream == null) {
      throw StateError('Bonsoir discovery не готов');
    }

    _discoverySubscription = stream.listen((event) async {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent(:final service):
          await service.resolve(_discovery!.serviceResolver);
        case BonsoirDiscoveryServiceResolvedEvent(:final service):
          _upsertRoom(service);
        case BonsoirDiscoveryServiceUpdatedEvent(:final service):
          _upsertRoom(service);
        case BonsoirDiscoveryServiceLostEvent(:final service):
          _removeRoom(service);
        default:
          break;
      }
    });

    await _discovery!.start();
  }

  void _upsertRoom(BonsoirService service) {
    final roomId = service.attributes['roomId'] ?? service.name;
    var host = service.host ?? service.attributes['host'];
    if (host == null || host.isEmpty) return;

    // Одна комната = один roomId (убираем дубли IP/hostname)
    _rooms.removeWhere(
      (_, room) => room.roomId == roomId || (room.name == service.name && room.port == service.port),
    );

    _rooms[roomId] = DiscoveredRoom(
      roomId: roomId,
      name: service.name,
      host: host,
      port: service.port,
    );
    _emitRooms();
  }

  void _removeRoom(BonsoirService service) {
    final roomId = service.attributes['roomId'];
    if (roomId != null) {
      _rooms.remove(roomId);
    } else {
      _rooms.removeWhere((_, r) => r.name == service.name && r.port == service.port);
    }
    _emitRooms();
  }

  Future<void> stopDiscovery() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _discovery?.stop();
    _discovery = null;
    _rooms.clear();
    _emitRooms();
  }

  void _emitRooms() {
    if (!_roomsController.isClosed) {
      _roomsController.add(rooms);
    }
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
    if (!_roomsController.isClosed) {
      await _roomsController.close();
    }
  }
}

Future<String?> getLocalWifiIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {}
  return null;
}

class GameServer {
  GameServer({
    required this.roomName,
    required this.bossName,
  });

  final String roomName;
  final String bossName;
  final _uuid = const Uuid();
  final discovery = DiscoveryService();
  final String roomId = const Uuid().v4();

  ServerSocket? _socket;
  String? localIp;
  final Map<String, Socket> _clients = {};
  final Map<Socket, String> _socketToPlayer = {};
  final Map<Socket, LineSocketBuffer> _clientBuffers = {};
  final _stateController = StreamController<GameState>.broadcast();

  late GameState _state;
  String? bossPlayerId;
  int _stateVersion = 0;
  Timer? _prankTimer;
  bool _includePhotosInNextPush = false;

  Stream<GameState> get stateStream => _stateController.stream;
  GameState get state => _state;

  Future<void> start() async {
    bossPlayerId = _uuid.v4();
    _state = GameState(
      roomId: roomId,
      roomName: roomName,
      hostName: bossName,
      localPlayerId: bossPlayerId,
      players: [
        PlayerModel(
          id: bossPlayerId!,
          name: bossName,
          role: PlayerRole.boss,
          balance: 999999999,
          sessionToken: _uuid.v4(),
        ),
      ],
    );

    _socket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      GameConstants.port,
      shared: true,
    );

    localIp = await getLocalWifiIp();

    await discovery.startBroadcast(
      roomName: roomName,
      roomId: roomId,
      port: GameConstants.port,
      hostIp: localIp,
    );

    _socket!.listen(_onClientConnected);
    _pushState();
  }

  void _onClientConnected(Socket client) {
    final buffer = LineSocketBuffer();
    _clientBuffers[client] = buffer;
    client.listen(
      (data) {
        buffer.add(data);
        for (final line in buffer.drainLines()) {
          final msg = NetworkMessage.decode(line);
          if (msg != null) _handleMessage(client, msg);
        }
      },
      onDone: () => _onClientDisconnected(client),
      onError: (_) => _onClientDisconnected(client),
    );
  }

  void _onClientDisconnected(Socket client) {
    _clientBuffers.remove(client);
    final playerId = _socketToPlayer.remove(client);
    _clients.remove(playerId);
    client.destroy();

    if (playerId != null && playerId != bossPlayerId) {
      final idx = _state.players.indexWhere((p) => p.id == playerId);
      if (idx >= 0) {
        final players = List<PlayerModel>.from(_state.players);
        players[idx] = players[idx].copyWith(isConnected: false);
        _state = _state.copyWith(players: players);
        _addEvent('${players[idx].name} отключился (можно вернуться).', '📴');
        _pushState();
      }
    }
  }

  void _handleMessage(Socket client, NetworkMessage msg) {
    switch (msg.type) {
      case MessageType.join:
        _handleJoin(client, msg);
      case MessageType.rejoin:
        _handleRejoin(client, msg);
      case MessageType.completeTask:
        _handleRespondTask(msg);
      case MessageType.resolveTask:
        break;
      case MessageType.buyItem:
        _handleBuyItem(msg);
      case MessageType.prank:
        _handlePrank(msg);
      case MessageType.chat:
        _handleChat(msg);
      case MessageType.officePhoto:
        _handleOfficePhoto(msg);
      case MessageType.officePhotoReaction:
        _handleOfficePhotoReaction(msg);
      case MessageType.officePhotoComment:
        _handleOfficePhotoComment(msg);
      default:
        break;
    }
  }

  void _handleJoin(Socket client, NetworkMessage msg) {
    final name = (msg.payload['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return;

    if (_state.phase != GamePhase.lobby) {
      _send(client, NetworkMessage(
        type: MessageType.error,
        payload: {'message': 'Игра уже началась! Опоздал.'},
      ));
      return;
    }

    if (_state.players.any((p) => !p.isBoss && p.isConnected && p.name == name)) {
      _send(client, NetworkMessage(
        type: MessageType.error,
        payload: {'message': 'Имя «$name» уже занято.'},
      ));
      return;
    }

    final offlineIdx = _state.players.indexWhere(
      (p) => !p.isBoss && !p.isConnected && p.name == name,
    );
    if (offlineIdx >= 0) {
      _attachClientToPlayer(client, offlineIdx);
      return;
    }

    if (_state.subordinates.length >= GameConstants.maxPlayers - 1) {
      _send(client, NetworkMessage(
        type: MessageType.error,
        payload: {'message': 'Комната полна.'},
      ));
      return;
    }

    final playerId = _uuid.v4();
    final sessionToken = _uuid.v4();
    _clients[playerId] = client;
    _socketToPlayer[client] = playerId;
    _state.players.add(PlayerModel(
      id: playerId,
      name: name,
      role: PlayerRole.subordinate,
      sessionToken: sessionToken,
    ));

    _addEvent('$name присоединился. Ждёт, когда босс нажмёт «Начать».', '👋');
    _send(client, NetworkMessage(
      type: MessageType.joinAck,
      payload: {
        'playerId': playerId,
        'sessionToken': sessionToken,
      },
    ));
    _pushState();
    _sendExistingPhotosTo(client);
  }

  void _attachClientToPlayer(Socket client, int playerIdx) {
    final playerId = _state.players[playerIdx].id;
    final token = _state.players[playerIdx].sessionToken;
    final oldSocket = _clients[playerId];
    if (oldSocket != null && oldSocket != client) {
      _socketToPlayer.remove(oldSocket);
      _clientBuffers.remove(oldSocket);
      oldSocket.destroy();
    }

    _clients[playerId] = client;
    _socketToPlayer[client] = playerId;

    final players = List<PlayerModel>.from(_state.players);
    players[playerIdx] = players[playerIdx].copyWith(isConnected: true);
    _state = _state.copyWith(players: players);

    _addEvent('${players[playerIdx].name} вернулся в офис.', '🔄');
    _send(client, NetworkMessage(
      type: MessageType.joinAck,
      payload: {
        'playerId': playerId,
        'sessionToken': token,
        'reconnected': true,
      },
    ));
    _pushState();
    _sendExistingPhotosTo(client);
  }

  int? _findOfflinePlayerIndex({String? token, String? name}) {
    if (token != null && token.isNotEmpty) {
      final idx = _state.players.indexWhere((p) => p.sessionToken == token && !p.isBoss);
      if (idx >= 0) return idx;
    }

    if (name != null && name.isNotEmpty) {
      if (_state.players.any((p) => !p.isBoss && p.isConnected && p.name == name)) {
        return null;
      }
      final idx = _state.players.indexWhere(
        (p) => !p.isBoss && !p.isConnected && p.name == name,
      );
      if (idx >= 0) return idx;
    }

    return null;
  }

  void _handleRejoin(Socket client, NetworkMessage msg) {
    final token = msg.payload['sessionToken'] as String?;
    final name = (msg.payload['name'] as String?)?.trim();

    final idx = _findOfflinePlayerIndex(token: token, name: name);
    if (idx != null) {
      _attachClientToPlayer(client, idx);
      return;
    }

    if (name != null &&
        name.isNotEmpty &&
        _state.players.any((p) => !p.isBoss && p.isConnected && p.name == name)) {
      _send(client, NetworkMessage(
        type: MessageType.error,
        payload: {'message': 'Имя «$name» уже занято другим игроком.'},
      ));
      return;
    }

    if (_state.phase == GamePhase.lobby) {
      _handleJoin(client, msg);
      return;
    }

    _send(client, NetworkMessage(
      type: MessageType.error,
      payload: {'message': 'Не удалось вернуться. Проверь имя или попроси босса не закрывать комнату.'},
    ));
  }

  void startGame() {
    if (_state.phase != GamePhase.lobby) return;
    if (_state.subordinates.where((p) => p.isConnected).isEmpty) return;

    _state = _state.copyWith(phase: GamePhase.playing);
    _addEvent('Игра началась! Зарплата — только по кнопке босса.', '🎮');
    _pushState();
  }

  void paySalary({String? playerId}) {
    if (_state.phase != GamePhase.playing) return;

    final targets = playerId != null
        ? _state.players.where((p) => p.id == playerId && !p.isBoss).toList()
        : _state.subordinates;

    if (targets.isEmpty) return;

    final amount = _state.defaultSalaryAmount;
    if (amount <= 0) return;

    final players = List<PlayerModel>.from(_state.players);
    for (final target in targets) {
      final idx = players.indexWhere((p) => p.id == target.id);
      if (idx >= 0) {
        players[idx] = players[idx].copyWith(
          balance: players[idx].balance + amount,
        );
      }
    }
    _state = _state.copyWith(players: players);

    _addEvent(
      playerId != null
          ? '${targets.first.name} получил $amount₽'
          : 'Зарплата всем: +$amount₽',
      '💸',
    );
    _pushState();
  }

  void setPayDefaults({required int salaryAmount, required int fineAmount}) {
    _state = _state.copyWith(
      defaultSalaryAmount: salaryAmount.clamp(0, 999999999),
      defaultFineAmount: fineAmount.clamp(0, 999999999),
    );
    _pushState();
  }

  void assignTask({required String playerId, required String taskId}) {
    if (_state.phase != GamePhase.playing) return;
    final task = _resolveTask(taskId);
    if (task == null) return;

    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0 || _state.players[idx].isBoss) return;

    final players = List<PlayerModel>.from(_state.players);
    players[idx] = players[idx].copyWith(
      currentTaskId: taskId,
      taskStatus: TaskStatus.active,
    );
    _state = _state.copyWith(players: players);
    _addEvent('Задание «${task.title}» → ${players[idx].name}', '📋');
    _pushState();
  }

  void assignCustomTask({
    required String playerId,
    required String title,
    required String description,
    required int reward,
    required int penalty,
  }) {
    if (_state.phase != GamePhase.playing) return;
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0 || _state.players[idx].isBoss) return;

    final task = BossTask(
      id: 'custom_${_uuid.v4()}',
      title: trimmedTitle,
      description: description.trim().isEmpty ? 'Без описания — классика босса' : description.trim(),
      reward: reward.clamp(0, 999999999),
      penalty: penalty.clamp(0, 999999999),
    );

    final players = List<PlayerModel>.from(_state.players);
    players[idx] = players[idx].copyWith(
      currentTaskId: task.id,
      taskStatus: TaskStatus.active,
    );
    _state = _state.copyWith(
      players: players,
      customTasks: [..._state.customTasks, task],
    );
    _addEvent('Своё задание «${task.title}» → ${players[idx].name}', '📝');
    _pushState();
  }

  BossTask? _resolveTask(String taskId) {
    for (final task in _state.customTasks) {
      if (task.id == taskId) return task;
    }
    return GameContent.taskById(taskId);
  }

  void _handleRespondTask(NetworkMessage msg) {
    if (_state.phase != GamePhase.playing) return;
    final playerId = msg.senderId;
    if (playerId == null) return;

    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;

    final player = _state.players[idx];
    if (player.taskStatus != TaskStatus.active || player.currentTaskId == null) return;

    final task = _resolveTask(player.currentTaskId!);
    if (task == null) return;

    final accepted = msg.payload['accepted'] as bool? ??
        msg.payload['success'] as bool? ??
        true;
    final players = List<PlayerModel>.from(_state.players);
    final current = players[idx];
    if (accepted) {
      players[idx] = current.copyWith(taskStatus: TaskStatus.awaitingBoss);
      _addEvent(
        '${current.name} согласился на «${task.title}» — ждёт твоего решения',
        '✋',
      );
    } else {
      players[idx] = current.copyWith(taskStatus: TaskStatus.refused);
      _addEvent(
        '${current.name} отказался от «${task.title}» — ждёт твоего решения',
        '🙅',
      );
    }

    _state = _state.copyWith(players: players);
    _pushState();
  }

  void resolveTask({
    required String playerId,
    required BossTaskDecision decision,
  }) {
    if (_state.phase != GamePhase.playing) return;

    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;

    final player = _state.players[idx];
    final pending = player.taskStatus == TaskStatus.awaitingBoss ||
        player.taskStatus == TaskStatus.refused;
    if (!pending || player.currentTaskId == null) return;

    final task = _resolveTask(player.currentTaskId!);
    if (task == null) return;

    final players = List<PlayerModel>.from(_state.players);
    final current = players[idx];
    switch (decision) {
      case BossTaskDecision.pay:
        players[idx] = current.copyWith(
          balance: current.balance + task.reward,
          clearTask: true,
        );
        _addEvent(
          'Выплата ${current.name}: +${task.reward}₽ за «${task.title}»',
          '💰',
        );
      case BossTaskDecision.skip:
        players[idx] = current.copyWith(clearTask: true);
        _addEvent(
          'Без выплаты ${current.name} за «${task.title}»',
          '🚫',
        );
      case BossTaskDecision.fine:
        players[idx] = current.copyWith(
          balance: (current.balance - task.penalty).clamp(0, 999999999),
          clearTask: true,
        );
        _addEvent(
          'Штраф ${current.name}: −${task.penalty}₽ за «${task.title}»',
          '⚖️',
        );
    }

    _state = _state.copyWith(players: players);
    _pushState();
  }

  void finePlayer({required String playerId, required int amount}) {
    if (_state.phase != GamePhase.playing) return;
    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0 || _state.players[idx].isBoss) return;

    final players = List<PlayerModel>.from(_state.players);
    final current = players[idx];
    players[idx] = current.copyWith(
      balance: (current.balance - amount).clamp(0, 999999999),
    );
    _state = _state.copyWith(players: players);
    _addEvent('Штраф ${current.name}: $amount₽', '⚖️');
    _pushState();
  }

  void _handleBuyItem(NetworkMessage msg) {
    if (_state.phase != GamePhase.playing) return;
    final playerId = msg.senderId;
    final itemId = msg.payload['itemId'] as String?;
    if (playerId == null || itemId == null) return;

    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;

    final current = _state.players[idx];
    final players = List<PlayerModel>.from(_state.players);

    if (current.isBoss) {
      final elite = GameContent.eliteItemById(itemId);
      if (elite == null || current.ownsItem(itemId)) return;
      players[idx] = current.copyWith(
        ownedItems: [...current.ownedItems, itemId],
      );
      _state = _state.copyWith(players: players);
      _addEvent('Босс купил элиту ${elite.emoji} ${elite.name}', '👑');
      _pushState();
      return;
    }

    ShopItem? item;
    for (final i in GameContent.allItems) {
      if (i.id == itemId) {
        item = i;
        break;
      }
    }
    if (item == null) return;
    if (current.ownsItem(itemId) || current.balance < item.price) return;

    final owned = [...current.ownedItems, itemId];
    players[idx] = current.copyWith(
      balance: current.balance - item.price,
      ownedItems: owned,
    );
    _state = _state.copyWith(players: players);
    _addEvent('${current.name} купил ${item.emoji} ${item.name}', '🛒');

    if (item.id == 'yacht' ||
        owned.where((id) => GameContent.eliteItemById(id) == null).length >=
            GameContent.allItems.length) {
      _state = _state.copyWith(
        phase: GamePhase.finished,
        winnerId: current.id,
        winnerName: current.name,
      );
      _addEvent('🏆 ${current.name} победил!', '🛥️', isFunny: true);
    }
    _pushState();
  }

  void _handlePrank(NetworkMessage msg) {
    if (_state.phase != GamePhase.playing) return;
    final playerId = msg.senderId;
    final prankId = msg.payload['prankId'] as String?;
    if (playerId == null || prankId == null) return;

    final prank = GameContent.prankById(prankId);
    if (prank == null) return;

    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0 || _state.players[idx].isBoss) return;

    final player = _state.players[idx];
    final effect = PrankEffect(
      prankId: prank.id,
      fromName: player.name,
      title: prank.title,
      bossEffect: prank.bossEffect,
      emoji: prank.emoji,
      until: DateTime.now().add(const Duration(seconds: 7)),
    );

    _state = _state.copyWith(activePrank: effect);
    _addEvent('🎭 ${player.name}: ${prank.title}! ${prank.bossEffect}', prank.emoji, isFunny: true);
    _pushState();

    _prankTimer?.cancel();
    _prankTimer = Timer(const Duration(seconds: 7), () {
      if (_state.activePrank?.until == effect.until) {
        _state = _state.copyWith(clearPrank: true);
        _pushState();
      }
    });
  }

  void _handleChat(NetworkMessage msg) {
    final fromId = msg.senderId;
    final text = (msg.payload['text'] as String?)?.trim();
    final toId = msg.payload['toId'] as String?;
    final broadcast = msg.payload['broadcast'] as bool? ?? false;
    if (fromId == null || text == null || text.isEmpty) return;

    final from = _state.players.cast<PlayerModel?>().firstWhere(
          (p) => p?.id == fromId,
          orElse: () => null,
        );
    if (from == null) return;

    final isBroadcast = broadcast && from.isBoss;
    if (!isBroadcast && toId == null) return;

    _state.messages.insert(
      0,
      ChatMessage(
        id: _uuid.v4(),
        fromId: fromId,
        fromName: from.name,
        toId: isBroadcast ? null : toId,
        text: text,
        timestamp: DateTime.now(),
        isBroadcast: isBroadcast,
      ),
    );
    if (_state.messages.length > 100) {
      _state.messages.removeRange(100, _state.messages.length);
    }
    _pushState();
  }

  void sendChat({String? toId, required String text, bool broadcast = false}) {
    _handleChat(NetworkMessage(
      type: MessageType.chat,
      senderId: bossPlayerId,
      payload: {
        'text': text,
        'broadcast': broadcast,
        if (!broadcast && toId != null) 'toId': toId,
      },
    ));
  }

  void postOfficePhoto({
    required String imageBase64,
    required List<DrawStroke> strokes,
    List<PhotoTextOverlay> textOverlays = const [],
    String? caption,
  }) {
    _handleOfficePhoto(NetworkMessage(
      type: MessageType.officePhoto,
      senderId: bossPlayerId,
      payload: {
        'id': _uuid.v4(),
        'imageBase64': imageBase64,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
        if (caption != null) 'caption': caption,
      },
    ));
  }

  void _handleOfficePhoto(NetworkMessage msg) {
    final fromId = msg.senderId;
    if (fromId == null) return;

    final from = _state.players.cast<PlayerModel?>().firstWhere(
          (p) => p?.id == fromId,
          orElse: () => null,
        );
    if (from == null) return;

    final imageBase64 = msg.payload['imageBase64'] as String?;
    if (imageBase64 == null || imageBase64.isEmpty) return;

    final strokesJson = msg.payload['strokes'] as List<dynamic>? ?? [];
    final strokes = strokesJson
        .map((e) => DrawStroke.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final textJson = msg.payload['textOverlays'] as List<dynamic>? ?? [];
    final textOverlays = textJson
        .map((e) => PhotoTextOverlay.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final photo = OfficePhoto(
      id: msg.payload['id'] as String? ?? _uuid.v4(),
      authorId: fromId,
      authorName: from.name,
      imageBase64: imageBase64,
      createdAt: DateTime.now(),
      strokes: strokes,
      textOverlays: textOverlays,
      caption: msg.payload['caption'] as String?,
    );

    _state.officePhotos.removeWhere((p) => p.id == photo.id);
    _state.officePhotos.insert(0, photo);
    if (_state.officePhotos.length > 12) {
      _state.officePhotos.removeRange(12, _state.officePhotos.length);
    }
    _addEvent('${from.name} добавил фото в офис', '📸');
    _broadcastPhoto(photo);
    _includePhotosInNextPush = true;
    _pushState();
  }

  void buyBossItem(String itemId) {
    _handleBuyItem(NetworkMessage(
      type: MessageType.buyItem,
      senderId: bossPlayerId,
      payload: {'itemId': itemId},
    ));
  }

  void _broadcastPhoto(OfficePhoto photo) {
    final msg = NetworkMessage(
      type: MessageType.officePhoto,
      payload: photo.toJson(),
    );
    for (final client in _clients.values) {
      _send(client, msg);
    }
  }

  void _updateOfficePhoto(OfficePhoto photo) {
    final idx = _state.officePhotos.indexWhere((p) => p.id == photo.id);
    if (idx < 0) return;
    final photos = List<OfficePhoto>.from(_state.officePhotos);
    photos[idx] = photo;
    _state = _state.copyWith(officePhotos: photos);
    _broadcastOfficePhotoPatch(photo);
    _pushState();
  }

  void _broadcastOfficePhotoPatch(OfficePhoto photo) {
    final msg = NetworkMessage(
      type: MessageType.officePhotoPatch,
      payload: {
        'id': photo.id,
        'reactions': photo.reactions.map((r) => r.toJson()).toList(),
        'comments': photo.comments.map((c) => c.toJson()).toList(),
      },
    );
    for (final client in _clients.values) {
      _send(client, msg);
    }
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _handleOfficePhotoReaction(NetworkMessage msg) {
    final fromId = msg.senderId;
    final photoId = msg.payload['photoId'] as String?;
    final emoji = msg.payload['emoji'] as String?;
    if (fromId == null || photoId == null || emoji == null) return;
    if (!OfficeReactions.emojis.contains(emoji)) return;

    final idx = _state.officePhotos.indexWhere((p) => p.id == photoId);
    if (idx < 0) return;

    final photo = _state.officePhotos[idx];
    final reactions = List<PhotoReaction>.from(photo.reactions);
    final existing = reactions.indexWhere(
      (r) => r.playerId == fromId && r.emoji == emoji,
    );
    if (existing >= 0) {
      reactions.removeAt(existing);
    } else {
      reactions.add(PhotoReaction(emoji: emoji, playerId: fromId));
    }
    _updateOfficePhoto(photo.copyWith(reactions: reactions));
  }

  void _handleOfficePhotoComment(NetworkMessage msg) {
    final fromId = msg.senderId;
    final photoId = msg.payload['photoId'] as String?;
    final text = (msg.payload['text'] as String?)?.trim();
    if (fromId == null || photoId == null || text == null || text.isEmpty) return;

    final from = _state.players.cast<PlayerModel?>().firstWhere(
          (p) => p?.id == fromId,
          orElse: () => null,
        );
    if (from == null) return;

    final idx = _state.officePhotos.indexWhere((p) => p.id == photoId);
    if (idx < 0) return;

    final photo = _state.officePhotos[idx];
    final comments = List<PhotoComment>.from(photo.comments)
      ..add(PhotoComment(
        id: _uuid.v4(),
        authorId: fromId,
        authorName: from.name,
        text: text,
        createdAt: DateTime.now(),
      ));
    _updateOfficePhoto(photo.copyWith(comments: comments));
  }

  void toggleOfficePhotoReaction(String photoId, String emoji) {
    _handleOfficePhotoReaction(NetworkMessage(
      type: MessageType.officePhotoReaction,
      senderId: bossPlayerId,
      payload: {'photoId': photoId, 'emoji': emoji},
    ));
  }

  void addOfficePhotoComment(String photoId, String text) {
    _handleOfficePhotoComment(NetworkMessage(
      type: MessageType.officePhotoComment,
      senderId: bossPlayerId,
      payload: {'photoId': photoId, 'text': text},
    ));
  }

  void _sendExistingPhotosTo(Socket client) {
    for (final photo in _state.officePhotos) {
      if (photo.hasImage) {
        _send(client, NetworkMessage(
          type: MessageType.officePhoto,
          payload: photo.toJson(),
        ));
      }
    }
  }

  void _addEvent(String message, String emoji, {bool isFunny = false}) {
    _state.events.insert(
      0,
      GameEvent(
        id: _uuid.v4(),
        message: message,
        timestamp: DateTime.now(),
        emoji: emoji,
        isFunny: isFunny,
      ),
    );
    if (_state.events.length > 50) {
      _state.events.removeRange(50, _state.events.length);
    }
  }

  void _pushState() {
    _stateVersion++;
    final includePhotos = _includePhotosInNextPush;
    _includePhotosInNextPush = false;
    final payload = _state.toJson(includePhotoData: includePhotos)
      ..['stateVersion'] = _stateVersion;

    final msg = NetworkMessage(type: MessageType.state, payload: payload);
    for (final client in _clients.values) {
      _send(client, msg);
    }

    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _send(Socket client, NetworkMessage msg) {
    try {
      client.write(msg.encode());
    } catch (_) {}
  }

  Future<void> stop() async {
    _prankTimer?.cancel();
    for (final client in _clients.values) {
      client.destroy();
    }
    _clients.clear();
    await _socket?.close();
    _socket = null;
    await discovery.stopBroadcast();
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
  }
}

class GameClient {
  GameClient({required this.playerName});

  final String playerName;
  final discovery = DiscoveryService();

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  String? playerId;
  String? sessionToken;
  DiscoveredRoom? _room;
  GameState? _state;
  int _lastStateVersion = 0;
  bool _connected = false;
  bool _connecting = false;
  bool _manualDisconnect = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  final _lineBuffer = LineSocketBuffer();

  final _stateController = StreamController<GameState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<GameState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  GameState? get state => _state;
  bool get isConnected => _connected && _socket != null;
  DiscoveredRoom? get room => _room;

  Future<void> startDiscovery() => discovery.startDiscovery();

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    if (!_connectionController.isClosed) {
      _connectionController.add(value);
    }
  }

  void _attachSocket(Socket socket) {
    _socket = socket;
    _lineBuffer.clear();
    _socketSub?.cancel();
    _socketSub = socket.listen(
      (data) {
        _lineBuffer.add(data);
        for (final line in _lineBuffer.drainLines()) {
          final msg = NetworkMessage.decode(line);
          if (msg != null) _handleMessage(msg);
        }
      },
      onDone: _onSocketClosed,
      onError: (_) => _onSocketClosed(),
    );
    _setConnected(true);
  }

  void _onSocketClosed() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
    _setConnected(false);
    if (_manualDisconnect) return;
    if (!_errorController.isClosed) {
      _errorController.add('Соединение потеряно');
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_room == null || _connecting || sessionToken == null) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: 1 << _reconnectAttempt.clamp(0, 4));
    _reconnectTimer = Timer(delay, () {
      reconnect();
    });
  }

  Future<bool> connect(
    DiscoveredRoom room, {
    String? rejoinToken,
    bool tryRejoin = false,
  }) async {
    await disconnect(clearSession: false);
    _room = room;
    _connecting = true;
    if (rejoinToken != null) {
      sessionToken = rejoinToken;
    }
    try {
      final socket = await Socket.connect(
        room.host,
        room.port,
        timeout: const Duration(seconds: 8),
      );
      _attachSocket(socket);
      if (tryRejoin || rejoinToken != null) {
        _send(NetworkMessage(
          type: MessageType.rejoin,
          payload: {
            'name': playerName,
            if (sessionToken != null) 'sessionToken': sessionToken,
          },
        ));
      } else {
        _send(NetworkMessage(
          type: MessageType.join,
          payload: {'name': playerName},
        ));
      }
      _connecting = false;
      return true;
    } catch (e) {
      _connecting = false;
      _errorController.add('Не удалось подключиться: $e');
      return false;
    }
  }

  Future<bool> reconnect() async {
    if (_room == null || _connecting) return false;
    _connecting = true;
    try {
      final socket = await Socket.connect(
        _room!.host,
        _room!.port,
        timeout: const Duration(seconds: 8),
      );
      _attachSocket(socket);
      _send(NetworkMessage(
        type: MessageType.rejoin,
        payload: {
          'name': playerName,
          if (sessionToken != null) 'sessionToken': sessionToken,
        },
      ));
      _connecting = false;
      return true;
    } catch (_) {
      _connecting = false;
      _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 8);
      _scheduleReconnect();
      return false;
    }
  }

  void _handleMessage(NetworkMessage msg) {
    switch (msg.type) {
      case MessageType.joinAck:
        playerId = msg.payload['playerId'] as String?;
        sessionToken = msg.payload['sessionToken'] as String? ?? sessionToken;
        _reconnectAttempt = 0;
        _reconnectTimer?.cancel();
        _persistSession();
      case MessageType.state:
        final version = msg.payload['stateVersion'] as int? ?? 0;
        if (version != 0 && version <= _lastStateVersion) return;
        _lastStateVersion = version;

        _state = _mergeStateFromServer(msg.payload, playerId);
        if (!_stateController.isClosed && _state != null) {
          _stateController.add(_state!);
        }
      case MessageType.officePhoto:
        _mergePhoto(OfficePhoto.fromJson(msg.payload));
      case MessageType.officePhotoPatch:
        _mergePhotoPatch(msg.payload);
      case MessageType.error:
        final message = msg.payload['message'] as String? ?? 'Ошибка';
        if (!_errorController.isClosed) {
          _errorController.add(message);
        }
      default:
        break;
    }
  }

  GameState _mergeStateFromServer(Map<String, dynamic> payload, String? localId) {
    final incoming = GameState.fromJson(payload);
    final oldPhotos = {
      for (final p in _state?.officePhotos ?? []) p.id: p,
    };
    final mergedPhotos = incoming.officePhotos.map<OfficePhoto>((p) {
      final cached = oldPhotos[p.id];
      if (p.hasImage) return p;
      if (cached != null && cached.hasImage) {
        return p.copyWith(
          imageBase64: cached.imageBase64,
          strokes: p.strokes.isNotEmpty ? p.strokes : cached.strokes,
          textOverlays: p.textOverlays.isNotEmpty
              ? p.textOverlays
              : cached.textOverlays,
        );
      }
      return p;
    }).toList();

    return incoming.copyWith(
      officePhotos: mergedPhotos,
      localPlayerId: localId,
    );
  }

  void _mergePhoto(OfficePhoto photo) {
    if (_state == null) {
      _state = GameState(
        roomId: '',
        roomName: '',
        hostName: '',
        players: [],
        officePhotos: [photo],
        localPlayerId: playerId,
      );
    } else {
      final photos = List<OfficePhoto>.from(_state!.officePhotos);
      final idx = photos.indexWhere((p) => p.id == photo.id);
      if (idx >= 0) {
        final old = photos[idx];
        photos[idx] = photo.copyWith(
          imageBase64: photo.hasImage ? photo.imageBase64 : old.imageBase64,
          strokes: photo.strokes.isNotEmpty ? photo.strokes : old.strokes,
          textOverlays: photo.textOverlays.isNotEmpty
              ? photo.textOverlays
              : old.textOverlays,
          reactions: photo.reactions.isNotEmpty ? photo.reactions : old.reactions,
          comments: photo.comments.isNotEmpty ? photo.comments : old.comments,
        );
      } else {
        photos.insert(0, photo);
      }
      if (photos.length > 12) photos.removeRange(12, photos.length);
      _state = _state!.copyWith(officePhotos: photos);
    }
    if (!_stateController.isClosed) {
      _stateController.add(_state!);
    }
  }

  void _mergePhotoPatch(Map<String, dynamic> payload) {
    final id = payload['id'] as String?;
    if (id == null || _state == null) return;

    final photos = List<OfficePhoto>.from(_state!.officePhotos);
    final idx = photos.indexWhere((p) => p.id == id);
    if (idx < 0) return;

    final reactionsJson = payload['reactions'] as List<dynamic>?;
    final commentsJson = payload['comments'] as List<dynamic>?;

    photos[idx] = photos[idx].copyWith(
      reactions: reactionsJson
          ?.map((e) => PhotoReaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      comments: commentsJson
          ?.map((e) => PhotoComment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _state = _state!.copyWith(officePhotos: photos);
    if (!_stateController.isClosed) {
      _stateController.add(_state!);
    }
  }

  void toggleOfficePhotoReaction(String photoId, String emoji) {
    _send(NetworkMessage(
      type: MessageType.officePhotoReaction,
      senderId: playerId,
      payload: {'photoId': photoId, 'emoji': emoji},
    ));
  }

  void addOfficePhotoComment(String photoId, String text) {
    _send(NetworkMessage(
      type: MessageType.officePhotoComment,
      senderId: playerId,
      payload: {'photoId': photoId, 'text': text},
    ));
  }

  void respondToTask({required bool accepted}) {
    _send(NetworkMessage(
      type: MessageType.completeTask,
      senderId: playerId,
      payload: {'accepted': accepted},
    ));
  }

  void buyItem(String itemId) {
    _send(NetworkMessage(
      type: MessageType.buyItem,
      senderId: playerId,
      payload: {'itemId': itemId},
    ));
  }

  void prank(String prankId) {
    _send(NetworkMessage(
      type: MessageType.prank,
      senderId: playerId,
      payload: {'prankId': prankId},
    ));
  }

  void sendChat({String? toId, required String text, bool broadcast = false}) {
    _send(NetworkMessage(
      type: MessageType.chat,
      senderId: playerId,
      payload: {
        'text': text,
        if (toId != null) 'toId': toId,
        'broadcast': broadcast,
      },
    ));
  }

  void postOfficePhoto({
    required String imageBase64,
    required List<DrawStroke> strokes,
    List<PhotoTextOverlay> textOverlays = const [],
    String? caption,
  }) {
    final id = const Uuid().v4();
    _mergePhoto(OfficePhoto(
      id: id,
      authorId: playerId ?? '',
      authorName: playerName,
      imageBase64: imageBase64,
      createdAt: DateTime.now(),
      strokes: strokes,
      textOverlays: textOverlays,
      caption: caption,
    ));
    _send(NetworkMessage(
      type: MessageType.officePhoto,
      senderId: playerId,
      payload: {
        'id': id,
        'imageBase64': imageBase64,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
        if (caption != null) 'caption': caption,
      },
    ));
  }

  Future<void> _persistSession() async {
    if (_room == null || playerId == null || sessionToken == null) return;
    await SavedSessionService.save(SavedPlayerSession(
      playerName: playerName,
      playerId: playerId!,
      sessionToken: sessionToken!,
      roomHost: _room!.host,
      roomPort: _room!.port,
      roomName: _room!.name,
      roomId: _room!.roomId,
    ));
  }

  /// Выход из комнаты с сохранением сессии для повторного входа.
  Future<void> leaveVoluntarily() async {
    await _persistSession();
    await disconnect(clearSession: true);
  }

  Future<bool> rejoinSaved(SavedPlayerSession saved) async {
    final room = DiscoveredRoom(
      roomId: saved.roomId,
      name: saved.roomName,
      host: saved.roomHost,
      port: saved.roomPort,
    );
    return connect(
      room,
      rejoinToken: saved.sessionToken,
      tryRejoin: true,
    );
  }

  void _send(NetworkMessage msg) {
    try {
      _socket?.write(msg.encode());
    } catch (_) {}
  }

  Future<void> disconnect({bool clearSession = true}) async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.close();
    _socket = null;
    _setConnected(false);
    _manualDisconnect = false;
    if (clearSession) {
      playerId = null;
      sessionToken = null;
      _room = null;
      _state = null;
      _lastStateVersion = 0;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await discovery.dispose();
    if (!_stateController.isClosed) await _stateController.close();
    if (!_errorController.isClosed) await _errorController.close();
    if (!_connectionController.isClosed) await _connectionController.close();
  }
}

Future<String?> compressImageForOffice(Uint8List bytes) async {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      if (bytes.length <= 600000) return base64Encode(bytes);
      return null;
    }
    final resized = decoded.width > 960
        ? img.copyResize(decoded, width: 960)
        : decoded;
    final jpg = img.encodeJpg(resized, quality: 78);
    return base64Encode(jpg);
  } catch (_) {
    return null;
  }
}
