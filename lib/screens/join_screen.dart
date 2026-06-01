import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../services/network_service.dart';
import '../services/saved_session_service.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _nameController = TextEditingController(text: 'Сотрудник');
  final _ipController = TextEditingController();
  GameClient? _client;
  bool _searching = false;
  String? _error;
  List<DiscoveredRoom> _rooms = [];
  SavedPlayerSession? _savedSession;

  @override
  void initState() {
    super.initState();
    _loadSavedSession();
    _startSearch();
  }

  Future<void> _loadSavedSession() async {
    final saved = await SavedSessionService.load();
    if (!mounted) return;
    _savedSession = saved;
    if (saved != null && _nameController.text == 'Сотрудник') {
      _nameController.text = saved.playerName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _startSearch() async {
    setState(() {
      _searching = true;
      _error = null;
      _rooms = [];
    });

    _client?.dispose();
    _client = GameClient(playerName: _nameController.text.trim());

    _client!.discovery.roomsStream.listen((rooms) {
      if (mounted) setState(() => _rooms = rooms);
    });

    _client!.errorStream.listen((err) {
      if (mounted) setState(() => _error = err);
    });

    try {
      await _client!.startDiscovery();
      if (mounted) setState(() => _searching = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _error = 'Ошибка поиска: $e';
        });
      }
    }
  }

  Future<void> _joinByIp() async {
    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
    if (ip.isEmpty) {
      setState(() => _error = 'Введите IP босса');
      return;
    }

    await _joinRoom(
      DiscoveredRoom(
        roomId: 'manual',
        name: 'Комната босса',
        host: ip,
        port: GameConstants.port,
      ),
    );
  }

  Future<void> _joinRoom(DiscoveredRoom room) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }

    setState(() => _error = null);

    final saved = _savedSession;
    final canRejoin = saved != null &&
        saved.playerName == name &&
        saved.roomHost == room.host &&
        saved.roomPort == room.port;

    final client = GameClient(playerName: name);
    final ok = await client.connect(
      room,
      rejoinToken: canRejoin ? saved.sessionToken : null,
      tryRejoin: true,
    );
    if (!ok) {
      await client.dispose();
      if (mounted) setState(() => _error = 'Не удалось подключиться');
      return;
    }

    if (!await _waitForGame(client)) return;

    await _client?.dispose();

    if (!mounted) {
      await client.dispose();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen.subordinate(client: client),
      ),
    );
  }

  Future<bool> _waitForGame(GameClient client) async {
    try {
      await client.stateStream
          .firstWhere((s) => s.localPlayer != null)
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      await client.dispose();
      if (mounted) setState(() => _error = 'Сервер не ответил');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground(
          colors: [AppTheme.darkBg, const Color(0xFF0d3d38), AppTheme.darkBg],
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
                      'Найти босса',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _startSearch,
                      icon: const Icon(Icons.refresh, color: AppTheme.slaveTeal),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Твоё имя',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_searching)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.slaveTeal.withValues(alpha: 0.8),
                        ),
                      ).animate(onPlay: (c) => c.repeat()).rotate(),
                    if (_searching) const SizedBox(width: 12),
                    Text(
                      _searching
                          ? 'Ищем комнаты по Wi-Fi...'
                          : 'Поиск остановлен',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppTheme.accentPink)),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCard(borderColor: AppTheme.accentOrange),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Не находит автоматически?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Попроси босса назвать IP с его экрана',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ipController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'IP босса (например 192.168.1.5)',
                          prefixIcon: Icon(Icons.lan),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _joinByIp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          foregroundColor: AppTheme.darkBg,
                        ),
                        child: const Text('Подключиться по IP'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _rooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('📡', style: TextStyle(fontSize: 56))
                                  .animate(onPlay: (c) => c.repeat())
                                  .moveY(begin: 0, end: -10, duration: 1.seconds),
                              const SizedBox(height: 16),
                              Text(
                                'Комнаты не найдены.\nБосс ещё не создал игру\nили вы не в одной Wi-Fi сети.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _rooms.length,
                          itemBuilder: (context, i) {
                            final room = _rooms[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: AppTheme.glassCard(
                                borderColor: AppTheme.slaveTeal,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.slaveTeal.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text('👔', style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                                title: Text(
                                  room.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  '${room.host}:${room.port}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _joinRoom(room),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.slaveTeal,
                                    foregroundColor: AppTheme.darkBg,
                                  ),
                                  child: const Text('Войти'),
                                ),
                              ),
                            ).animate().fadeIn(delay: (i * 80).ms).slideX(begin: 0.1);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
