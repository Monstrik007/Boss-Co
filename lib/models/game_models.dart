import '../core/constants.dart';

TaskStatus _parseTaskStatus(String? name) {
  switch (name) {
    case 'active':
      return TaskStatus.active;
    case 'awaitingBoss':
      return TaskStatus.awaitingBoss;
    case 'refused':
      return TaskStatus.refused;
    case 'done':
    case 'failed':
      return TaskStatus.none;
    default:
      return TaskStatus.none;
  }
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.description,
    required this.tier,
  });

  final String id;
  final String name;
  final String emoji;
  final int price;
  final String description;
  final int tier;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'price': price,
        'description': description,
        'tier': tier,
      };

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        price: json['price'] as int,
        description: json['description'] as String,
        tier: json['tier'] as int,
      );
}

class BossTask {
  const BossTask({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.penalty,
  });

  final String id;
  final String title;
  final String description;
  final int reward;
  final int penalty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'reward': reward,
        'penalty': penalty,
      };

  factory BossTask.fromJson(Map<String, dynamic> json) => BossTask(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        reward: (json['reward'] as num?)?.toInt() ?? 0,
        penalty: (json['penalty'] as num?)?.toInt() ?? 0,
      );
}

class Prank {
  const Prank({
    required this.id,
    required this.title,
    required this.description,
    required this.bossEffect,
    required this.emoji,
  });

  final String id;
  final String title;
  final String description;
  final String bossEffect;
  final String emoji;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'bossEffect': bossEffect,
        'emoji': emoji,
      };

  factory Prank.fromJson(Map<String, dynamic> json) => Prank(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        bossEffect: json['bossEffect'] as String,
        emoji: json['emoji'] as String,
      );
}

class DrawPoint {
  const DrawPoint({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory DrawPoint.fromJson(Map<String, dynamic> json) => DrawPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );
}

class DrawStroke {
  DrawStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<DrawPoint> points;
  final int color;
  final double width;

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'color': color,
        'width': width,
      };

  factory DrawStroke.fromJson(Map<String, dynamic> json) => DrawStroke(
        points: (json['points'] as List<dynamic>)
            .map((e) => DrawPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        color: json['color'] as int,
        width: (json['width'] as num).toDouble(),
      );
}

/// Текст на фото в редакторе поста (позиция — центр, 0…1).
class PhotoTextOverlay {
  const PhotoTextOverlay({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.scale = 1,
    this.color = 0xFFFFFFFF,
    this.fontSize = 28,
  });

  final String id;
  final String text;
  final double x;
  final double y;
  final double rotation;
  final double scale;
  final int color;
  final double fontSize;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'rotation': rotation,
        'scale': scale,
        'color': color,
        'fontSize': fontSize,
      };

  factory PhotoTextOverlay.fromJson(Map<String, dynamic> json) =>
      PhotoTextOverlay(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1,
        color: json['color'] as int? ?? 0xFFFFFFFF,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28,
      );

  PhotoTextOverlay copyWith({
    String? text,
    double? x,
    double? y,
    double? rotation,
    double? scale,
    int? color,
    double? fontSize,
  }) =>
      PhotoTextOverlay(
        id: id,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
        rotation: rotation ?? this.rotation,
        scale: scale ?? this.scale,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
      );
}

/// Реакции на доске офиса.
class OfficeReactions {
  static const emojis = ['😂', '💩', '👹', '❤️', '👍'];
}

class PhotoReaction {
  const PhotoReaction({required this.emoji, required this.playerId});

  final String emoji;
  final String playerId;

  Map<String, dynamic> toJson() => {'emoji': emoji, 'playerId': playerId};

  factory PhotoReaction.fromJson(Map<String, dynamic> json) => PhotoReaction(
        emoji: json['emoji'] as String,
        playerId: json['playerId'] as String,
      );
}

class PhotoComment {
  const PhotoComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PhotoComment.fromJson(Map<String, dynamic> json) => PhotoComment(
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        authorName: json['authorName'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class OfficePhoto {
  OfficePhoto({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.imageBase64,
    required this.createdAt,
    List<DrawStroke>? strokes,
    List<PhotoTextOverlay>? textOverlays,
    List<PhotoReaction>? reactions,
    List<PhotoComment>? comments,
    this.caption,
  })  : strokes = strokes ?? [],
        textOverlays = textOverlays ?? [],
        reactions = reactions ?? [],
        comments = comments ?? [];

  final String id;
  final String authorId;
  final String authorName;
  final String imageBase64;
  final DateTime createdAt;
  final List<DrawStroke> strokes;
  final List<PhotoTextOverlay> textOverlays;
  final List<PhotoReaction> reactions;
  final List<PhotoComment> comments;
  final String? caption;

  bool hasReaction(String playerId, String emoji) =>
      reactions.any((r) => r.playerId == playerId && r.emoji == emoji);

  int countForEmoji(String emoji) =>
      reactions.where((r) => r.emoji == emoji).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'imageBase64': imageBase64,
        'createdAt': createdAt.toIso8601String(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'comments': comments.map((c) => c.toJson()).toList(),
        if (caption != null) 'caption': caption,
      };

  factory OfficePhoto.fromJson(Map<String, dynamic> json) => OfficePhoto(
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        authorName: json['authorName'] as String,
        imageBase64: json['imageBase64'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        strokes: (json['strokes'] as List<dynamic>?)
                ?.map((e) => DrawStroke.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        textOverlays: (json['textOverlays'] as List<dynamic>?)
                ?.map((e) => PhotoTextOverlay.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        reactions: (json['reactions'] as List<dynamic>?)
                ?.map((e) => PhotoReaction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        comments: (json['comments'] as List<dynamic>?)
                ?.map((e) => PhotoComment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        caption: json['caption'] as String?,
      );

  bool get hasImage => imageBase64.isNotEmpty;

  OfficePhoto copyWith({
    String? imageBase64,
    List<DrawStroke>? strokes,
    List<PhotoTextOverlay>? textOverlays,
    List<PhotoReaction>? reactions,
    List<PhotoComment>? comments,
    String? caption,
  }) =>
      OfficePhoto(
        id: id,
        authorId: authorId,
        authorName: authorName,
        imageBase64: imageBase64 ?? this.imageBase64,
        createdAt: createdAt,
        strokes: strokes ?? this.strokes,
        textOverlays: textOverlays ?? this.textOverlays,
        reactions: reactions ?? this.reactions,
        comments: comments ?? this.comments,
        caption: caption ?? this.caption,
      );

  Map<String, dynamic> toMetadataJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'textOverlays': textOverlays.map((t) => t.toJson()).toList(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'comments': comments.map((c) => c.toJson()).toList(),
        if (caption != null) 'caption': caption,
      };
}

class PrankEffect {
  PrankEffect({
    required this.prankId,
    required this.fromName,
    required this.title,
    required this.bossEffect,
    required this.emoji,
    required this.until,
  });

  final String prankId;
  final String fromName;
  final String title;
  final String bossEffect;
  final String emoji;
  final DateTime until;

  bool get isActive => DateTime.now().isBefore(until);

  Map<String, dynamic> toJson() => {
        'prankId': prankId,
        'fromName': fromName,
        'title': title,
        'bossEffect': bossEffect,
        'emoji': emoji,
        'until': until.toIso8601String(),
      };

  factory PrankEffect.fromJson(Map<String, dynamic> json) => PrankEffect(
        prankId: json['prankId'] as String,
        fromName: json['fromName'] as String,
        title: json['title'] as String,
        bossEffect: json['bossEffect'] as String,
        emoji: json['emoji'] as String,
        until: DateTime.parse(json['until'] as String),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.text,
    required this.timestamp,
    this.toId,
    this.isBroadcast = false,
  });

  final String id;
  final String fromId;
  final String fromName;
  final String? toId;
  final String text;
  final DateTime timestamp;
  final bool isBroadcast;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'fromName': fromName,
        'toId': toId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'isBroadcast': isBroadcast,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        fromId: json['fromId'] as String,
        fromName: json['fromName'] as String,
        toId: json['toId'] as String?,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isBroadcast: json['isBroadcast'] as bool? ?? false,
      );
}

/// Должность в офисе (уровень 0…maxRankLevel).
class OfficeRank {
  const OfficeRank({
    required this.level,
    required this.title,
    required this.emoji,
  });

  final int level;
  final String title;
  final String emoji;
}

class PlayerModel {
  PlayerModel({
    required this.id,
    required this.name,
    required this.role,
    this.balance = 0,
    List<String>? ownedItems,
    this.currentTaskId,
    this.taskAssignedById,
    this.taskStatus = TaskStatus.none,
    List<String>? usedPranks,
    this.isConnected = true,
    required this.sessionToken,
    this.rankLevel = 0,
    this.honorScore = 0,
    this.shameScore = 0,
  })  : ownedItems = ownedItems ?? [],
        usedPranks = usedPranks ?? [];

  final String id;
  final String name;
  final PlayerRole role;
  int balance;
  final List<String> ownedItems;
  String? currentTaskId;
  String? taskAssignedById;
  TaskStatus taskStatus;
  final List<String> usedPranks;
  bool isConnected;
  final String sessionToken;
  int rankLevel;
  int honorScore;
  int shameScore;

  bool get isBoss => role == PlayerRole.boss;

  OfficeRank get officeRank => GameContent.rankForLevel(rankLevel);

  int get progress =>
      ownedItems.length * 100 ~/ GameContent.allItems.length;

  bool ownsItem(String itemId) => ownedItems.contains(itemId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'balance': balance,
        'ownedItems': ownedItems,
        'currentTaskId': currentTaskId,
        'taskAssignedById': taskAssignedById,
        'taskStatus': taskStatus.name,
        'usedPranks': usedPranks,
        'isConnected': isConnected,
        'sessionToken': sessionToken,
        'rankLevel': rankLevel,
        'honorScore': honorScore,
        'shameScore': shameScore,
      };

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        role: PlayerRole.values.byName(json['role'] as String),
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        ownedItems: (json['ownedItems'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        currentTaskId: json['currentTaskId'] as String?,
        taskAssignedById: json['taskAssignedById'] as String?,
        taskStatus: _parseTaskStatus(json['taskStatus'] as String?),
        usedPranks: (json['usedPranks'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        isConnected: json['isConnected'] as bool? ?? true,
        sessionToken: json['sessionToken'] as String? ?? '',
        rankLevel: (json['rankLevel'] as num?)?.toInt() ?? 0,
        honorScore: (json['honorScore'] as num?)?.toInt() ?? 0,
        shameScore: (json['shameScore'] as num?)?.toInt() ?? 0,
      );

  PlayerModel copyWith({
    String? name,
    int? balance,
    List<String>? ownedItems,
    String? currentTaskId,
    String? taskAssignedById,
    TaskStatus? taskStatus,
    List<String>? usedPranks,
    bool? isConnected,
    String? sessionToken,
    int? rankLevel,
    int? honorScore,
    int? shameScore,
    bool clearTask = false,
  }) {
    return PlayerModel(
      id: id,
      name: name ?? this.name,
      role: role,
      balance: balance ?? this.balance,
      ownedItems: ownedItems ?? List.from(this.ownedItems),
      currentTaskId: clearTask ? null : (currentTaskId ?? this.currentTaskId),
      taskAssignedById:
          clearTask ? null : (taskAssignedById ?? this.taskAssignedById),
      taskStatus: clearTask ? TaskStatus.none : (taskStatus ?? this.taskStatus),
      usedPranks: usedPranks ?? List.from(this.usedPranks),
      isConnected: isConnected ?? this.isConnected,
      sessionToken: sessionToken ?? this.sessionToken,
      rankLevel: rankLevel ?? this.rankLevel,
      honorScore: honorScore ?? this.honorScore,
      shameScore: shameScore ?? this.shameScore,
    );
  }
}

class GameEvent {
  GameEvent({
    required this.id,
    required this.message,
    required this.timestamp,
    this.emoji = '📢',
    this.isFunny = false,
  });

  final String id;
  final String message;
  final DateTime timestamp;
  final String emoji;
  final bool isFunny;

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'emoji': emoji,
        'isFunny': isFunny,
      };

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
        id: json['id'] as String,
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        emoji: json['emoji'] as String? ?? '📢',
        isFunny: json['isFunny'] as bool? ?? false,
      );
}

class GameState {
  GameState({
    required this.roomId,
    required this.roomName,
    required this.hostName,
    required this.players,
    this.phase = GamePhase.lobby,
    List<GameEvent>? events,
    List<ChatMessage>? messages,
    List<OfficePhoto>? officePhotos,
    List<BossTask>? customTasks,
    this.activePrank,
    this.winnerId,
    this.winnerName,
    this.localPlayerId,
    this.defaultSalaryAmount = GameConstants.salaryAmount,
    this.defaultFineAmount = GameConstants.defaultFineAmount,
  })  : events = events ?? [],
        messages = messages ?? [],
        officePhotos = officePhotos ?? [],
        customTasks = customTasks ?? [];

  final String roomId;
  final String roomName;
  final String hostName;
  final List<PlayerModel> players;
  final GamePhase phase;
  final List<GameEvent> events;
  final List<ChatMessage> messages;
  final List<OfficePhoto> officePhotos;
  final List<BossTask> customTasks;
  final PrankEffect? activePrank;
  final String? winnerId;
  final String? winnerName;
  final String? localPlayerId;
  final int defaultSalaryAmount;
  final int defaultFineAmount;

  bool get isPlaying => phase == GamePhase.playing;

  PlayerModel? get localPlayer {
    if (localPlayerId == null) return null;
    try {
      return players.firstWhere((p) => p.id == localPlayerId);
    } catch (_) {
      return null;
    }
  }

  PlayerModel? get boss {
    for (final p in players) {
      if (p.isBoss) return p;
    }
    return null;
  }

  List<PlayerModel> get subordinates =>
      players.where((p) => !p.isBoss).toList();

  BossTask? taskById(String? taskId) {
    if (taskId == null) return null;
    for (final task in customTasks) {
      if (task.id == taskId) return task;
    }
    return GameContent.taskById(taskId);
  }

  List<ChatMessage> messagesFor(String? playerId) {
    if (playerId == null) return [];
    return messages.where((m) {
      if (m.isBroadcast) return true;
      return m.fromId == playerId || m.toId == playerId;
    }).toList();
  }

  List<ChatMessage> threadWith(String partnerId) {
    final myId = localPlayerId;
    if (myId == null) return [];
    return messages.where((m) {
      if (partnerId == '__broadcast__') return m.isBroadcast;
      if (m.isBroadcast) return false;
      return (m.fromId == myId && m.toId == partnerId) ||
          (m.fromId == partnerId && m.toId == myId);
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Map<String, dynamic> toJson({bool includePhotoData = false}) => {
        'roomId': roomId,
        'roomName': roomName,
        'hostName': hostName,
        'players': players.map((p) => p.toJson()).toList(),
        'phase': phase.name,
        'events': events.map((e) => e.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'officePhotos': officePhotos
            .map((p) => includePhotoData ? p.toJson() : p.toMetadataJson())
            .toList(),
        'customTasks': customTasks.map((t) => t.toJson()).toList(),
        if (activePrank != null) 'activePrank': activePrank!.toJson(),
        'winnerId': winnerId,
        'winnerName': winnerName,
        'defaultSalaryAmount': defaultSalaryAmount,
        'defaultFineAmount': defaultFineAmount,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        roomId: json['roomId'] as String? ?? '',
        roomName: json['roomName'] as String,
        hostName: json['hostName'] as String,
        players: (json['players'] as List<dynamic>)
            .map((e) => PlayerModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        phase: GamePhase.values.byName(json['phase'] as String? ?? 'lobby'),
        events: (json['events'] as List<dynamic>?)
                ?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        messages: (json['messages'] as List<dynamic>?)
                ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        officePhotos: (json['officePhotos'] as List<dynamic>?)
                ?.map((e) => OfficePhoto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        customTasks: (json['customTasks'] as List<dynamic>?)
                ?.map((e) => BossTask.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        activePrank: json['activePrank'] != null
            ? PrankEffect.fromJson(json['activePrank'] as Map<String, dynamic>)
            : null,
        winnerId: json['winnerId'] as String?,
        winnerName: json['winnerName'] as String?,
        defaultSalaryAmount:
            (json['defaultSalaryAmount'] as num?)?.toInt() ??
                GameConstants.salaryAmount,
        defaultFineAmount: (json['defaultFineAmount'] as num?)?.toInt() ??
            GameConstants.defaultFineAmount,
      );

  GameState copyWith({
    String? roomId,
    String? roomName,
    String? hostName,
    List<PlayerModel>? players,
    GamePhase? phase,
    List<GameEvent>? events,
    List<ChatMessage>? messages,
    List<OfficePhoto>? officePhotos,
    List<BossTask>? customTasks,
    PrankEffect? activePrank,
    bool clearPrank = false,
    String? winnerId,
    String? winnerName,
    String? localPlayerId,
    int? defaultSalaryAmount,
    int? defaultFineAmount,
  }) {
    return GameState(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      hostName: hostName ?? this.hostName,
      players: players ?? this.players,
      phase: phase ?? this.phase,
      events: events ?? this.events,
      messages: messages ?? this.messages,
      officePhotos: officePhotos ?? this.officePhotos,
      customTasks: customTasks ?? this.customTasks,
      activePrank: clearPrank ? null : (activePrank ?? this.activePrank),
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      localPlayerId: localPlayerId ?? this.localPlayerId,
      defaultSalaryAmount: defaultSalaryAmount ?? this.defaultSalaryAmount,
      defaultFineAmount: defaultFineAmount ?? this.defaultFineAmount,
    );
  }
}

class GameContent {
  static const officeRanks = [
    OfficeRank(level: 0, title: 'Стажёр', emoji: '🌱'),
    OfficeRank(level: 1, title: 'Специалист', emoji: '⭐'),
    OfficeRank(level: 2, title: 'Старший', emoji: '🎖️'),
    OfficeRank(level: 3, title: 'Руководитель', emoji: '💼'),
  ];

  static OfficeRank rankForLevel(int level) {
    final idx = level.clamp(0, GameConstants.maxRankLevel);
    return officeRanks[idx];
  }

  static bool canManage(PlayerModel manager, PlayerModel target) {
    if (target.isBoss) return false;
    if (manager.isBoss) return true;
    return manager.rankLevel > target.rankLevel;
  }

  static const quickAssignTasks = [
    'water',
    'compliment_boss',
    'silent',
    'dance',
    'squat',
  ];

  static const allItems = [
    ShopItem(id: 'pencil', name: 'Карандаш', emoji: '✏️', price: 50, description: 'Чтобы подписать отказ в повышении', tier: 1),
    ShopItem(id: 'eraser', name: 'Ластик', emoji: '🧽', price: 120, description: 'Стирает ошибки. Жаль, зарплату не стирает', tier: 1),
    ShopItem(id: 'mug', name: 'Кружка', emoji: '☕', price: 350, description: 'Для кофе, который босс называет «мотивацией»', tier: 1),
    ShopItem(id: 'lunchbox', name: 'Ланчбокс', emoji: '🍱', price: 800, description: 'Обед из дома — столовка = корпоративная культура', tier: 2),
    ShopItem(id: 'chair', name: 'Стул без скрипа', emoji: '🪑', price: 2500, description: 'Эргономика одобрена бухгалтерией', tier: 2),
    ShopItem(id: 'headphones', name: 'Наушники', emoji: '🎧', price: 4500, description: 'Чтобы не слышать «это срочно, но не горит»', tier: 2),
    ShopItem(id: 'monitor', name: 'Монитор', emoji: '🖥️', price: 12000, description: 'Два глаза — два монитора', tier: 3),
    ShopItem(id: 'sneakers', name: 'Кроссовки', emoji: '👟', price: 18000, description: 'Бегать между совещаниями', tier: 3),
    ShopItem(id: 'therapy', name: 'Психолог', emoji: '🛋️', price: 35000, description: '«Не принимай на личный счёт» — совет босса', tier: 3),
    ShopItem(id: 'apartment', name: 'Квартира', emoji: '🏢', price: 85000, description: 'Мечта становится KPI', tier: 4),
    ShopItem(id: 'car', name: 'Машина', emoji: '🚗', price: 250000, description: 'Чтобы ездить на работу ради машины', tier: 4),
    ShopItem(id: 'vacation', name: 'Отпуск', emoji: '🏖️', price: 420000, description: '14 дней без звонков (босс врёт)', tier: 4),
    ShopItem(id: 'house', name: 'Дом', emoji: '🏡', price: 900000, description: 'Сад, Teams и покой', tier: 5),
    ShopItem(id: 'yacht', name: 'Яхта', emoji: '🛥️', price: 2500000, description: 'Финал. Ты выжил!', tier: 5),
  ];

  static const eliteItems = [
    ShopItem(id: 'gold_pen', name: 'Платиновая ручка', emoji: '🖊️', price: 500000, description: 'Подписывать приказы стилем', tier: 5),
    ShopItem(id: 'massage_chair', name: 'Массажное кресло', emoji: '💺', price: 1200000, description: 'Стресс? Не знаем такого', tier: 5),
    ShopItem(id: 'helicopter', name: 'Вертолёт', emoji: '🚁', price: 8000000, description: 'Пробки — для сотрудников', tier: 5),
    ShopItem(id: 'island', name: 'Остров', emoji: '🏝️', price: 25000000, description: 'Личная зона offsite', tier: 5),
    ShopItem(id: 'gold_toilet', name: 'Золотой унитаз', emoji: '🚽', price: 5000000, description: 'KPI по комфорту выполнен', tier: 5),
    ShopItem(id: 'butler', name: 'Личный дворецкий', emoji: '🤵', price: 3000000, description: 'Приносит кофе и сарказм', tier: 5),
    ShopItem(id: 'lamborghini', name: 'Ламбorghini', emoji: '🏎️', price: 15000000, description: 'Потому что могу', tier: 5),
    ShopItem(id: 'space_trip', name: 'Полёт в космос', emoji: '🚀', price: 50000000, description: 'Team building на орбите', tier: 5),
  ];

  static const allTasks = [
    BossTask(id: 'one_leg', title: 'Ходи на одной ноге', description: '5 минут по офису на одной ноге. Вторая — «в отпуске».', reward: 2000, penalty: 1000),
    BossTask(id: 'hop', title: '10 прыжков на одной ноге', description: 'Прыгни 10 раз. Считает босс. Он любит считать.', reward: 800, penalty: 500),
    BossTask(id: 'squat', title: '20 приседаний', description: 'Присядь 20 раз. «Это team building, не спортзал».', reward: 1200, penalty: 600),
    BossTask(id: 'compliment_boss', title: 'Комплимент боссу', description: 'Скажи боссу 3 комплимента вслух при коллегах.', reward: 500, penalty: 800),
    BossTask(id: 'water', title: 'Принеси воду', description: 'Стакан воды боссу. Не газированную. Не тёплую. Не существующую.', reward: 600, penalty: 400),
    BossTask(id: 'dance', title: 'Танец на 30 секунд', description: 'Станцуй 30 секунд. Стиль — «корпоратив 2014».', reward: 1500, penalty: 900),
    BossTask(id: 'selfie_boss', title: 'Селфи с боссом', description: 'Сделай селфи с боссом и покажи всем в офисе.', reward: 1000, penalty: 300),
    BossTask(id: 'silent', title: 'Молчи 3 минуты', description: '3 минуты полной тишины. Для босса — медитация.', reward: 700, penalty: 500),
    BossTask(id: 'pushups', title: '5 отжиманий', description: '5 отжиманий. «Физическая активность = продуктивность».', reward: 900, penalty: 600),
    BossTask(id: 'laugh', title: 'Смейся над шуткой босса', description: 'Босс расскажет шутку. Смейся 10 секунд. Искренне. (нет)', reward: 400, penalty: 1000),
    BossTask(id: 'paper_plane', title: 'Самолётик в боссу', description: 'Сложи самолётик и запусти в сторону босса. Точность не важна.', reward: 600, penalty: 700),
    BossTask(id: 'statue', title: 'Стой смирно 2 минуты', description: '2 минуты как статуя. Моргать можно. Дышать — по желанию.', reward: 800, penalty: 500),
  ];

  static const allPranks = [
    Prank(id: 'reminders', title: '1000 напоминаний', description: '«Где зарплата?» каждые 4 минуты', bossEffect: 'Босс тонет в уведомлениях!', emoji: '⏰'),
    Prank(id: 'wallpaper', title: 'Обои мести', description: '«Я люблю сотрудников (нет)»', bossEffect: 'Экран босса взорвался от стыда!', emoji: '🖼️'),
    Prank(id: 'pizza', title: '20 пицц на босса', description: 'Заказ на имя босса', bossEffect: 'Офис пахнет пепперони и местью!', emoji: '🍕'),
    Prank(id: 'alarm', title: 'Будильник «Срок!»', description: 'Каждые 3 минуты', bossEffect: 'Босс слышит «СРОК!» даже во сне!', emoji: '🔔'),
    Prank(id: 'raise', title: 'Ложное повышение', description: '«Повышение ВСЕМ!» в чат', bossEffect: 'Босс в панике, HR плачет!', emoji: '📈'),
    Prank(id: 'confetti', title: 'Конфетти-атака', description: 'Виртуальное конфетти на 10 секунд', bossEffect: 'Босс засыпан конфетти!', emoji: '🎉'),
    Prank(id: 'duck', title: 'Утка в кабинете', description: 'Кря-кря на всех экранах', bossEffect: 'Босс окружён резиновыми утками!', emoji: '🦆'),
  ];

  static ShopItem? itemById(String id) {
    for (final i in allItems) {
      if (i.id == id) return i;
    }
    for (final i in eliteItems) {
      if (i.id == id) return i;
    }
    return null;
  }

  static ShopItem? eliteItemById(String id) {
    for (final i in eliteItems) {
      if (i.id == id) return i;
    }
    return null;
  }

  static BossTask? taskById(String id) {
    for (final t in allTasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  static Prank? prankById(String id) {
    for (final p in allPranks) {
      if (p.id == id) return p;
    }
    return null;
  }

  static String itemsSummary(List<String> ownedIds) {
    if (ownedIds.isEmpty) return 'Ничего не купил — классика';
    return ownedIds
        .map((id) => itemById(id)?.emoji ?? eliteItemById(id)?.emoji ?? '?')
        .take(10)
        .join(' ');
  }
}
