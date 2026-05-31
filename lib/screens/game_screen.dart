import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../models/game_models.dart';
import '../services/game_server_registry.dart';
import '../services/network_service.dart';
import '../services/saved_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_panel.dart';
import '../widgets/event_feed.dart';
import '../widgets/office_panel.dart';
import '../widgets/photo_draw_screen.dart';
import '../widgets/prank_overlay.dart';
import '../widgets/shop_panel.dart';
import '../widgets/unread_indicator.dart';

class GameScreen extends StatefulWidget {
  const GameScreen._({
    required this.isBoss,
    this.server,
    this.client,
  });

  final bool isBoss;
  final GameServer? server;
  final GameClient? client;

  factory GameScreen.boss({required GameServer server}) =>
      GameScreen._(isBoss: true, server: server);

  factory GameScreen.subordinate({required GameClient client}) =>
      GameScreen._(isBoss: false, client: client);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, DateTime> _chatReadAt = {};
  DateTime? _eventsReadAt;
  DateTime? _officeReadAt;
  DateTime? _tasksTabReadAt;
  Set<String> _knownSubordinateIds = {};
  int? _lastSeenBalance;
  String? _lastSeenTaskId;
  bool _unreadBaselinesSet = false;
  GameState? _latestState;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectionSub;

  int get _payTabIndex => 0;
  int get _tasksTabIndex => 1;
  int get _shopTabIndex => 0;
  int get _chatTabIndex => widget.isBoss ? 3 : 2;
  int get _officeTabIndex => widget.isBoss ? 4 : 3;
  int get _feedTabIndex => widget.isBoss ? 5 : 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isBoss ? 6 : 5,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    if (!widget.isBoss) {
      _isOnline = widget.client!.isConnected;
      _connectionSub = widget.client!.connectionStream.listen((online) {
        if (mounted) setState(() => _isOnline = online);
      });
    }
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Stream<GameState> get _stateStream =>
      widget.isBoss ? widget.server!.stateStream : widget.client!.stateStream;

  GameState? get _initialState =>
      widget.isBoss ? widget.server!.state : widget.client!.state;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameState>(
      stream: _stateStream,
      initialData: _initialState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.phase == GamePhase.finished) {
          return _WinnerScreen(
            state: state,
            isBoss: widget.isBoss,
            onExit: _exitAfterGame,
          );
        }

        final canPlay = state.isPlaying || widget.isBoss;
        _latestState = state;
        _initUnreadBaselines(state);

        final activePrank = state.activePrank;
        final showPrank = widget.isBoss && activePrank != null && activePrank.isActive;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _exit();
          },
          child: Stack(
          children: [
            Scaffold(
          body: Container(
            decoration: AppTheme.gradientBackground(
              colors: widget.isBoss
                  ? [AppTheme.darkBg, const Color(0xFF2d1b69)]
                  : [AppTheme.darkBg, const Color(0xFF0d3d38)],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _Header(
                    state: state,
                    isBoss: widget.isBoss,
                    onExit: _exit,
                  ),
                  if (!canPlay && !widget.isBoss) _WaitingBanner(state: state),
                  if (!widget.isBoss && !_isOnline) _ReconnectBanner(client: widget.client!),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor:
                        widget.isBoss ? AppTheme.gold : AppTheme.slaveTeal,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    tabs: widget.isBoss
                        ? [
                            UnreadTab(label: '💸', hasUnread: _hasUnreadPayTab(state)),
                            UnreadTab(label: '📋', hasUnread: _hasUnreadBossTasks(state)),
                            const Tab(text: '👑'),
                            UnreadTab(label: '💬', hasUnread: _hasUnreadChat(state)),
                            UnreadTab(label: '🏢', hasUnread: _hasUnreadOffice(state)),
                            UnreadTab(label: '📰', hasUnread: _hasUnreadEvents(state)),
                          ]
                        : [
                            UnreadTab(label: '🛒', hasUnread: _hasUnreadShop(state)),
                            const Tab(text: '🎭'),
                            UnreadTab(label: '💬', hasUnread: _hasUnreadChat(state)),
                            UnreadTab(label: '🏢', hasUnread: _hasUnreadOffice(state)),
                            UnreadTab(label: '📰', hasUnread: _hasUnreadEvents(state)),
                          ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: widget.isBoss
                          ? [
                              _locked(canPlay, _BossPayTab(
                                state: state,
                                server: widget.server!,
                                knownSubordinateIds: _knownSubordinateIds,
                              )),
                              _locked(canPlay, _BossTasksTab(
                                state: state,
                                server: widget.server!,
                                hasUnread: _hasUnreadBossTasks(state),
                              )),
                              _locked(
                                canPlay,
                                ShopPanel(
                                  state: state,
                                  items: GameContent.eliteItems,
                                  isElite: true,
                                  title: '👑 Элитный магазин (∞ ₽)',
                                  onBuy: (id) => widget.server!.buyBossItem(id),
                                ),
                              ),
                              ChatPanel(
                                state: state,
                                isBoss: true,
                                readAt: _chatReadAt,
                                onMarkRead: _markChatRead,
                                onSend: ({toId, required text, broadcast = false}) =>
                                    widget.server!.sendChat(toId: toId, text: text, broadcast: broadcast),
                              ),
                              OfficePanel(
                                state: state,
                                officeReadAt: _officeReadAt,
                                onAddPhoto: () => _addOfficePhoto(context),
                              ),
                              EventFeed(
                                events: state.events,
                                eventsReadAt: _eventsReadAt,
                              ),
                            ]
                          : [
                              _locked(
                                canPlay,
                                ShopPanel(
                                  state: state,
                                  hasUnread: _hasUnreadShop(state),
                                  onBuy: (id) => widget.client!.buyItem(id),
                                ),
                              ),
                              _locked(
                                canPlay,
                                _PranksTab(
                                  state: state,
                                  onPrank: (id) => widget.client!.prank(id),
                                ),
                              ),
                              ChatPanel(
                                state: state,
                                isBoss: false,
                                readAt: _chatReadAt,
                                onMarkRead: _markChatRead,
                                onSend: ({toId, required text, broadcast = false}) =>
                                    widget.client!.sendChat(toId: toId, text: text, broadcast: broadcast),
                              ),
                              OfficePanel(
                                state: state,
                                officeReadAt: _officeReadAt,
                                onAddPhoto: () => _addOfficePhoto(context),
                              ),
                              EventFeed(
                                events: state.events,
                                eventsReadAt: _eventsReadAt,
                              ),
                            ],
                    ),
                  ),
                  if (!widget.isBoss && canPlay)
                    _SubordinateTaskBar(
                      state: state,
                      client: widget.client!,
                      hasUnread: _hasUnreadTask(state),
                      onMarkRead: () => setState(() {
                        _lastSeenTaskId = state.localPlayer?.currentTaskId;
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
            if (showPrank)
              Positioned.fill(
                child: IgnorePointer(
                  child: PrankOverlay(
                    effect: activePrank,
                    isBoss: widget.isBoss,
                  ),
                ),
              ),
          ],
        ),
        );
      },
    );
  }

  void _initUnreadBaselines(GameState state) {
    if (_unreadBaselinesSet) return;
    _unreadBaselinesSet = true;
    final now = DateTime.now();
    _eventsReadAt = now;
    _officeReadAt = now;
    _tasksTabReadAt = now;
    _knownSubordinateIds = state.subordinates.map((p) => p.id).toSet();
    _lastSeenBalance = state.localPlayer?.balance;
    _lastSeenTaskId = state.localPlayer?.currentTaskId;
    _markAllChatRead(state);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final state = _latestState;
    if (state == null) return;

    final index = _tabController.index;
    setState(() {
      if (widget.isBoss) {
        if (index == _payTabIndex) {
          _knownSubordinateIds = state.subordinates.map((p) => p.id).toSet();
        }
        if (index == _tasksTabIndex) {
          _tasksTabReadAt = DateTime.now();
        }
        if (index == _chatTabIndex) _markAllChatRead(state);
        if (index == _officeTabIndex) _officeReadAt = DateTime.now();
        if (index == _feedTabIndex) _eventsReadAt = DateTime.now();
      } else {
        if (index == _shopTabIndex) {
          _lastSeenBalance = state.localPlayer?.balance;
        }
        if (index == _chatTabIndex) _markAllChatRead(state);
        if (index == _officeTabIndex) _officeReadAt = DateTime.now();
        if (index == _feedTabIndex) _eventsReadAt = DateTime.now();
      }
    });
  }

  void _markAllChatRead(GameState state) {
    final now = DateTime.now();
    _chatReadAt['__broadcast__'] = now;
    for (final p in state.players) {
      if (p.id != state.localPlayerId) {
        _chatReadAt[p.id] = now;
      }
    }
  }

  void _markChatRead(String partnerKey) {
    setState(() => _chatReadAt[partnerKey] = DateTime.now());
  }

  bool _hasUnreadChat(GameState state) {
    final myId = state.localPlayerId;
    if (myId == null || state.messages.isEmpty) return false;

    for (final m in state.messages) {
      if (m.fromId == myId) continue;
      final key = m.isBroadcast ? '__broadcast__' : m.fromId;
      final lastRead = _chatReadAt[key] ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (m.timestamp.isAfter(lastRead)) return true;
    }
    return false;
  }

  bool _hasUnreadEvents(GameState state) {
    if (state.events.isEmpty) return false;
    final readAt = _eventsReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return state.events.any((e) => e.timestamp.isAfter(readAt));
  }

  bool _hasUnreadOffice(GameState state) {
    final myId = state.localPlayerId;
    if (myId == null || state.officePhotos.isEmpty) return false;
    final readAt = _officeReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return state.officePhotos.any(
      (p) => p.authorId != myId && p.createdAt.isAfter(readAt),
    );
  }

  bool _hasUnreadPayTab(GameState state) {
    final subs = state.subordinates.map((p) => p.id).toSet();
    return subs.difference(_knownSubordinateIds).isNotEmpty;
  }

  bool _hasUnreadBossTasks(GameState state) {
    final readAt = _tasksTabReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return state.events.any(
      (e) =>
          e.timestamp.isAfter(readAt) &&
          (e.emoji == '✅' || e.emoji == '❌' || e.message.contains('выполнил') || e.message.contains('провалил')),
    );
  }

  bool _hasUnreadShop(GameState state) {
    final local = state.localPlayer;
    if (local == null || _lastSeenBalance == null) return false;
    return local.balance > _lastSeenBalance!;
  }

  bool _hasUnreadTask(GameState state) {
    final local = state.localPlayer;
    if (local == null || local.taskStatus != TaskStatus.active) return false;
    final taskId = local.currentTaskId;
    if (taskId == null) return false;
    return taskId != _lastSeenTaskId;
  }

  Future<bool> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBg,
        title: Text(widget.isBoss ? 'Закрыть комнату?' : 'Выйти из комнаты?'),
        content: Text(
          widget.isBoss
              ? 'Комната закроется, все сотрудники отключатся.'
              : 'Прогресс сохранится — сможешь вернуться под тем же именем, пока босс не закрыл комнату.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              widget.isBoss ? 'Закрыть' : 'Выйти',
              style: TextStyle(
                color: widget.isBoss ? AppTheme.accentPink : AppTheme.slaveTeal,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _exit() async {
    if (!await _confirmExit() || !mounted) return;

    if (widget.isBoss) {
      await widget.server?.stop();
      await GameServerRegistry.stopActive();
    } else {
      await widget.client?.leaveVoluntarily();
      await widget.client?.dispose();
    }
    if (mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  Future<void> _exitAfterGame() async {
    if (!widget.isBoss) {
      await SavedSessionService.clear();
      await widget.client?.dispose();
    } else {
      await widget.server?.stop();
      await GameServerRegistry.stopActive();
    }
    if (mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  Widget _locked(bool enabled, Widget child) {
    if (enabled) return child;
    return Stack(
      children: [
        AbsorbPointer(child: Opacity(opacity: 0.35, child: child)),
        Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassCard(borderColor: AppTheme.accentOrange),
            child: const Text(
              '⏳ Босс ещё не нажал «Начать игру»\nМагазин и задания заблокированы',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addOfficePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await picker.pickImage(source: source, maxWidth: 1200);
    if (picked == null || !mounted) return;

    final raw = await picked.readAsBytes();
    if (!mounted) return;

    final result = await Navigator.push<PhotoDrawResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoDrawScreen(imageBytes: Uint8List.fromList(raw)),
      ),
    );
    if (result == null || !mounted) return;

    final compressed = await compressImageForOffice(raw);
    if (compressed == null || !mounted) return;

    if (widget.isBoss) {
      widget.server?.postOfficePhoto(
        imageBase64: compressed,
        strokes: result.strokes,
        caption: result.caption,
      );
    } else {
      widget.client?.postOfficePhoto(
        imageBase64: compressed,
        strokes: result.strokes,
        caption: result.caption,
      );
    }
  }
}

class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCard(borderColor: AppTheme.accentOrange),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ты в комнате «${state.roomName}». Жди, пока ${state.hostName} нажмёт «Начать игру». Офис и чат уже работают!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds);
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.client});

  final GameClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCard(borderColor: AppTheme.accentPink),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accentPink.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Нет связи с боссом. Переподключаемся…\nПрогресс сохранён — не выходи из комнаты.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: () => client.reconnect(),
            child: const Text('Сейчас'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.isBoss,
    required this.onExit,
  });

  final GameState state;
  final bool isBoss;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final local = state.localPlayer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.logout, color: Colors.white54),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  state.roomName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  isBoss ? '👑 ${state.hostName}' : '🐑 ${local?.name ?? "..."}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (!isBoss && local != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.slaveTeal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.slaveTeal.withValues(alpha: 0.5)),
              ),
              child: Text(
                '${local.balance} ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.slaveTeal,
                  fontSize: 16,
                ),
              ),
            ),
          if (isBoss)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '∞ ₽',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BossPayTab extends StatelessWidget {
  const _BossPayTab({
    required this.state,
    required this.server,
    this.knownSubordinateIds = const {},
  });

  final GameState state;
  final GameServer server;
  final Set<String> knownSubordinateIds;

  bool get _hasNewSubordinates =>
      state.subordinates.any((p) => !knownSubordinateIds.contains(p.id));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.glassCard(borderColor: AppTheme.gold),
          child: Column(
            children: [
              const Text('💸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'Заплатить деньги',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'Зарплата приходит ТОЛЬКО когда ты нажмёшь.\n'
                'Каждый раз +${GameConstants.salaryAmount}₽. Как в мечтах... нет, в офисе.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isPlaying ? () => server.paySalary() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.darkBg,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('💰 ЗАПЛАТИТЬ ВСЕМ'),
                ),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
        const SizedBox(height: 24),
        UnreadSectionHeader(
          title: 'Индивидуально',
          hasUnread: _hasNewSubordinates,
        ),
        const SizedBox(height: 12),
        ...state.subordinates.map((p) => _PlayerPayCard(
              player: p,
              isNew: !knownSubordinateIds.contains(p.id),
              onPay: state.isPlaying ? () => server.paySalary(playerId: p.id) : null,
              onFine: (amount) => server.finePlayer(playerId: p.id, amount: amount),
            )),
      ],
    );
  }
}

class _PlayerPayCard extends StatelessWidget {
  const _PlayerPayCard({
    required this.player,
    required this.onPay,
    required this.onFine,
    this.isNew = false,
  });

  final PlayerModel player;
  final VoidCallback? onPay;
  final void Function(int amount) onFine;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🐑', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          const UnreadBadge(),
                        ],
                      ],
                    ),
                    Text(
                      player.isConnected
                          ? 'Баланс: ${player.balance}₽ • Прогресс: ${player.progress}%'
                          : 'Баланс: ${player.balance}₽ • 📴 офлайн (может вернуться)',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.slaveTeal,
                    foregroundColor: AppTheme.darkBg,
                  ),
                  child: const Text('Заплатить'),
                ),
              ),
              const SizedBox(width: 8),
              _FineButton(onFine: onFine),
            ],
          ),
        ],
      ),
    );
  }
}

class _FineButton extends StatelessWidget {
  const _FineButton({required this.onFine});

  final void Function(int amount) onFine;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onFine,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.accentPink.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.gavel, color: AppTheme.accentPink, size: 20),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 500, child: Text('Штраф 500₽')),
        const PopupMenuItem(value: 1000, child: Text('Штраф 1000₽')),
        const PopupMenuItem(value: 2500, child: Text('Штраф 2500₽')),
        const PopupMenuItem(value: 5000, child: Text('Штраф 5000₽ «за attitude»')),
      ],
    );
  }
}

class _BossTasksTab extends StatefulWidget {
  const _BossTasksTab({
    required this.state,
    required this.server,
    this.hasUnread = false,
  });

  final GameState state;
  final GameServer server;
  final bool hasUnread;

  @override
  State<_BossTasksTab> createState() => _BossTasksTabState();
}

class _BossTasksTabState extends State<_BossTasksTab> {
  static const _allId = '__all__';

  String? _selectedId;
  bool _customMode = false;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rewardController = TextEditingController(text: '1000');
  final _penaltyController = TextEditingController(text: '500');

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rewardController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  bool get _isAll => _selectedId == _allId;

  String get _targetLabel {
    if (_isAll) {
      final n = widget.state.subordinates.length;
      return 'всем ($n ${_plural(n, 'сотрудник', 'сотрудника', 'сотрудников')})';
    }
    final p = widget.state.subordinates.firstWhere((s) => s.id == _selectedId);
    return p.name;
  }

  String _plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
  }

  Iterable<PlayerModel> get _targets {
    if (_isAll) return widget.state.subordinates;
    return widget.state.subordinates.where((p) => p.id == _selectedId);
  }

  void _selectTarget(String id) {
    setState(() {
      _selectedId = id;
      _customMode = false;
    });
  }

  void _backToEmployees() {
    setState(() => _selectedId = null);
  }

  void _assignPreset(String taskId) {
    for (final p in _targets) {
      widget.server.assignTask(playerId: p.id, taskId: taskId);
    }
    _backToEmployees();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Задание назначено: $_targetLabel')),
      );
    }
  }

  void _assignCustom() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final reward = int.tryParse(_rewardController.text.trim()) ?? 0;
    final penalty = int.tryParse(_penaltyController.text.trim()) ?? 0;

    for (final p in _targets) {
      widget.server.assignCustomTask(
        playerId: p.id,
        title: title,
        description: _descController.text,
        reward: reward,
        penalty: penalty,
      );
    }

    _titleController.clear();
    _descController.clear();
    _backToEmployees();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Своё задание назначено: $_targetLabel')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedId == null) {
      return _buildEmployeeStep();
    }
    return _buildTaskStep();
  }

  Widget _buildEmployeeStep() {
    final subs = widget.state.subordinates;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        UnreadSectionHeader(
          title: 'Шаг 1: Кому задание?',
          hasUnread: widget.hasUnread,
        ),
        const SizedBox(height: 8),
        Text(
          'Сначала выбери сотрудника или всех сразу',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        if (subs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassCard(),
            child: Text(
              'Пока нет сотрудников в комнате',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          )
        else ...[
          _EmployeePickCard(
            emoji: '👥',
            name: 'Всем сотрудникам',
            subtitle: '${subs.length} ${_plural(subs.length, 'человек', 'человека', 'человек')}',
            onTap: () => _selectTarget(_allId),
          ),
          const SizedBox(height: 10),
          ...subs.map((p) {
            final active = widget.state.taskById(p.currentTaskId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EmployeePickCard(
                emoji: '🐑',
                name: p.name,
                subtitle: active != null
                    ? 'Активно: ${active.title}'
                    : 'Свободен • ${p.balance}₽',
                highlight: active != null,
                onTap: () => _selectTarget(p.id),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildTaskStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(onPressed: _backToEmployees, icon: const Icon(Icons.arrow_back)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Шаг 2: Задание',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    'Кому: $_targetLabel',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('📋 Из списка'),
                selected: !_customMode,
                onSelected: (_) => setState(() => _customMode = false),
                selectedColor: AppTheme.bossPurple.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('📝 Своё'),
                selected: _customMode,
                onSelected: (_) => setState(() => _customMode = true),
                selectedColor: AppTheme.gold.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_customMode)
          ...GameContent.allTasks.map((task) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: AppTheme.glassCard(borderColor: AppTheme.bossPurple),
              child: ListTile(
                onTap: () => _assignPreset(task.id),
                title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${task.description}\n+${task.reward}₽ / −${task.penalty}₽',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.35,
                  ),
                ),
                trailing: const Icon(Icons.send, color: AppTheme.bossPurple),
              ),
            );
          })
        else ...[
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Название задания'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(hintText: 'Описание'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rewardController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Награда ₽'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _penaltyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Штраф ₽'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assignCustom,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.darkBg,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text('Назначить $_targetLabel'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmployeePickCard extends StatelessWidget {
  const _EmployeePickCard({
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final String emoji;
  final String name;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(
            borderColor: highlight ? AppTheme.accentOrange : AppTheme.bossPurple,
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: highlight
                            ? AppTheme.accentOrange
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _PranksTab extends StatelessWidget {
  const _PranksTab({required this.state, required this.onPrank});

  final GameState state;
  final void Function(String prankId) onPrank;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(borderColor: AppTheme.accentPink),
          child: Text(
            'Приколы над боссом — без лимита!\n'
            'Полный экран видит только босс. Остальные — запись в ленте.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        ...GameContent.allPranks.map((prank) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppTheme.glassCard(borderColor: AppTheme.accentPink),
            child: ListTile(
              leading: Text(prank.emoji, style: const TextStyle(fontSize: 32)),
              title: Text(
                prank.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${prank.description}\n→ ${prank.bossEffect}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.35,
                ),
              ),
              trailing: ElevatedButton(
                onPressed: () => onPrank(prank.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Жахнуть!'),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SubordinateTaskBar extends StatelessWidget {
  const _SubordinateTaskBar({
    required this.state,
    required this.client,
    this.hasUnread = false,
    required this.onMarkRead,
  });

  final GameState state;
  final GameClient client;
  final bool hasUnread;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final local = state.localPlayer;
    if (local == null || local.taskStatus != TaskStatus.active) {
      return const SizedBox.shrink();
    }

    final task = state.taskById(local.currentTaskId);
    if (task == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onMarkRead,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(
            color: hasUnread
                ? Colors.red.shade400
                : AppTheme.accentOrange.withValues(alpha: 0.3),
            width: hasUnread ? 2 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '📋 ${task.title}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (hasUnread) const UnreadBadge(),
            ],
          ),
          Text(
            task.description,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onMarkRead();
                    client.completeTask(success: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.slaveTeal,
                    foregroundColor: AppTheme.darkBg,
                  ),
                  child: Text('Готово (+${task.reward}₽)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    onMarkRead();
                    client.completeTask(success: false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentPink,
                    side: const BorderSide(color: AppTheme.accentPink),
                  ),
                  child: Text('Провал (−${task.penalty}₽)'),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    ).animate().slideY(begin: 1, duration: 300.ms);
  }
}

class _WinnerScreen extends StatelessWidget {
  const _WinnerScreen({
    required this.state,
    required this.isBoss,
    required this.onExit,
  });

  final GameState state;
  final bool isBoss;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final winner = state.winnerName ?? 'Кто-то';
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground(
          colors: [AppTheme.darkBg, const Color(0xFF3d2a00), AppTheme.darkBg],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🛥️', style: TextStyle(fontSize: 80))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds),
                const SizedBox(height: 24),
                Text(
                  isBoss ? 'Сотрудник победил!' : 'ТЫ ПОБЕДИЛ!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.gold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isBoss
                      ? '$winner купил всё и уехал на яхте.\nТы остался с бесконечными деньгами\nи без команды. Поздравляю?'
                      : 'Ты прошёл путь от карандаша до яхты\nпод началом ${state.hostName}.\nГерой open space!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: onExit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.darkBg,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('В главное меню'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
