import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../services/game_server_registry.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_identity.dart';
import 'game_screen.dart';

class BossLobbyScreen extends StatefulWidget {
  const BossLobbyScreen({super.key});

  @override
  State<BossLobbyScreen> createState() => _BossLobbyScreenState();
}

class _BossLobbyScreenState extends State<BossLobbyScreen> {
  final _roomController = TextEditingController(text: 'Офис №42');
  final _nameController = TextEditingController(text: 'Главный Босс');
  GameServer? _server;
  bool _starting = false;
  bool _handedOffToGame = false;
  String? _error;

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    if (!_handedOffToGame) {
      _server?.stop();
    }
    super.dispose();
  }

  Future<void> _createRoom() async {
    final roomName = _roomController.text.trim();
    final bossName = _nameController.text.trim();
    if (roomName.isEmpty || bossName.isEmpty) {
      setState(() => _error = 'Введите имя комнаты и своё имя');
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      await GameServerRegistry.stopActive();
      final server = GameServer(roomName: roomName, bossName: bossName);
      await server.start();
      GameServerRegistry.register(server);
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _server = server;
        _starting = false;
      });
    } catch (e) {
      setState(() {
        _starting = false;
        _error = 'Не удалось создать комнату: $e';
      });
    }
  }

  void _startGame() {
    final server = _server;
    if (server == null) return;
    server.startGame();
    _handedOffToGame = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen.boss(server: server),
      ),
    );
  }

  Future<bool> _confirmLeaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkBg,
        title: const Text('Закрыть комнату?'),
        content: Text(
          'Комната закроется, все сотрудники отключатся.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Закрыть', style: TextStyle(color: AppTheme.accentPink)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_server != null) {
      return _LobbyView(
        server: _server!,
        onStart: _startGame,
        onBack: () async {
          if (!await _confirmLeaveRoom() || !context.mounted) return;
          await _server?.stop();
          await GameServerRegistry.stopActive();
          if (!context.mounted) return;
          Navigator.pop(context);
        },
      );
    }

    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground(
          colors: [AppTheme.darkBg, const Color(0xFF2d1b69), AppTheme.darkBg],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Text(
                      'Создать комнату',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text('👑', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Ты — Босс. Wi-Fi раздаёт власть.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(
                    labelText: 'Название комнаты',
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Твоё имя (для истории)',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppTheme.accentPink)),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: _starting ? null : _createRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bossPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: _starting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Создать и ждать команду'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.server,
    required this.onStart,
    required this.onBack,
  });

  final GameServer server;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground(
          colors: [AppTheme.darkBg, const Color(0xFF2d1b69), AppTheme.darkBg],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            server.roomName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ).animate(onPlay: (c) => c.repeat()).fade(),
                              const SizedBox(width: 6),
                              Text(
                                'Комната видна в Wi-Fi',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (server.localIp != null) ...[
                            const SizedBox(height: 6),
                            SelectableText(
                              'IP: ${server.localIp}:${GameConstants.port}',
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Если не находит — введи этот IP вручную',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: server.stateStream,
                  initialData: server.state,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? server.state;
                    final subs = state.subordinates.where((p) => p.isConnected).toList();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppTheme.glassCard(
                              borderColor: AppTheme.gold,
                            ),
                            child: Row(
                              children: [
                                const Text('👑', style: TextStyle(fontSize: 36)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.hostName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Text(
                                        'Баланс: ∞ (как твоё эго)',
                                        style: TextStyle(
                                          color: AppTheme.gold.withValues(alpha: 0.9),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Подчинённые (${subs.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: subs.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🐑', style: TextStyle(fontSize: 48))
                                            .animate(onPlay: (c) => c.repeat())
                                            .shimmer(duration: 2.seconds),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Ждём жертв...\nто есть коллег',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: subs.length,
                                    itemBuilder: (context, i) {
                                      final p = subs[i];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(16),
                                        decoration: AppTheme.glassCard(),
                                        child: Row(
                                          children: [
                                            Text(
                                              p.displayEmoji,
                                              style: const TextStyle(fontSize: 28),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    p.rankLabel,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.slaveTeal
                                                          .withValues(alpha: 0.8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().fadeIn(delay: (i * 100).ms);
                                    },
                                  ),
                          ),
                          ElevatedButton(
                            onPressed: subs.isEmpty ? null : onStart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: AppTheme.darkBg,
                              minimumSize: const Size.fromHeight(56),
                            ),
                            child: Text(
                              subs.isEmpty
                                  ? 'Нужен минимум 1 подчинённый'
                                  : 'Начать игру!',
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
