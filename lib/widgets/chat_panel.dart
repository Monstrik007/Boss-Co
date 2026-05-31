import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';
import '../widgets/unread_indicator.dart';

typedef SendChat = void Function({String? toId, required String text, bool broadcast});

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.state,
    required this.isBoss,
    required this.onSend,
    required this.readAt,
    required this.onMarkRead,
  });

  final GameState state;
  final bool isBoss;
  final SendChat onSend;
  final Map<String, DateTime> readAt;
  final void Function(String partnerKey) onMarkRead;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  String? _partnerId;
  bool _broadcastMode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _partnerKey(String? id, {bool broadcast = false}) {
    if (broadcast) return '__broadcast__';
    return id ?? '';
  }

  bool _isUnread(String partnerKey) {
    final myId = widget.state.localPlayerId;
    if (myId == null) return false;

    final lastRead = widget.readAt[partnerKey] ?? DateTime.fromMillisecondsSinceEpoch(0);
    for (final m in widget.state.messages) {
      if (m.fromId == myId) continue;
      if (m.timestamp.isAfter(lastRead)) {
        if (partnerKey == '__broadcast__' && m.isBroadcast) return true;
        if (!m.isBroadcast &&
            partnerKey != '__broadcast__' &&
            (m.fromId == partnerKey || m.toId == partnerKey)) {
          return true;
        }
      }
    }
    return false;
  }

  List<_Conversation> get _conversations {
    final myId = widget.state.localPlayerId;
    if (myId == null) return [];

    final result = <_Conversation>[];

    if (widget.isBoss) {
      result.add(_Conversation(
        id: '__broadcast__',
        name: '📢 Всем сотрудникам',
        isBroadcast: true,
      ));
    } else if (widget.state.boss != null) {
      result.add(_Conversation(
        id: '__broadcast__',
        name: '📢 ${widget.state.hostName} — всем',
        isBroadcast: true,
      ));
    }

    for (final p in widget.state.players) {
      if (p.id == myId) continue;
      result.add(_Conversation(
        id: p.id,
        name: '${p.isBoss ? '👑' : '🐑'} ${p.name}',
      ));
    }
    return result;
  }

  String? _previewFor(_Conversation conv) {
    final msgs = conv.isBroadcast
        ? widget.state.messages.where((m) => m.isBroadcast).toList()
        : widget.state.threadWith(conv.id);
    if (msgs.isEmpty) return 'Нет сообщений';
    return msgs.first.text;
  }

  void _openConversation(_Conversation conv) {
    setState(() {
      _partnerId = conv.isBroadcast ? null : conv.id;
      _broadcastMode = conv.isBroadcast;
    });
    widget.onMarkRead(_partnerKey(conv.isBroadcast ? null : conv.id, broadcast: conv.isBroadcast));
  }

  void _backToList() {
    setState(() {
      _partnerId = null;
      _broadcastMode = false;
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_broadcastMode && widget.isBoss) {
      widget.onSend(text: text, broadcast: true);
      widget.onMarkRead('__broadcast__');
    } else if (_partnerId != null) {
      widget.onSend(text: text, toId: _partnerId);
      widget.onMarkRead(_partnerId!);
    } else {
      return;
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_partnerId != null || _broadcastMode) {
      return _ThreadView(
        state: widget.state,
        partnerId: _broadcastMode ? '__broadcast__' : _partnerId!,
        partnerName: _broadcastMode
            ? (widget.isBoss ? '📢 Всем' : '📢 ${widget.state.hostName}')
            : widget.state.players.firstWhere((p) => p.id == _partnerId).name,
        controller: _controller,
        onSend: _send,
        onBack: _backToList,
        canSend: widget.isBoss || !_broadcastMode,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Переписки',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        ..._conversations.map((conv) {
          final unread = _isUnread(_partnerKey(conv.isBroadcast ? null : conv.id, broadcast: conv.isBroadcast));
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: AppTheme.glassCard(
              borderColor: unread ? AppTheme.accentPink : null,
            ),
            child: ListTile(
              onTap: () => _openConversation(conv),
              leading: CircleAvatar(
                backgroundColor: unread
                    ? AppTheme.accentPink.withValues(alpha: 0.3)
                    : AppTheme.bossPurple.withValues(alpha: 0.3),
                child: Text(
                  unread ? '❗' : '💬',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      conv.name,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                        color: unread ? AppTheme.accentPink : Colors.white,
                      ),
                    ),
                  ),
                  if (unread) const UnreadBadge(),
                ],
              ),
              subtitle: Text(
                _previewFor(conv) ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: unread ? 0.7 : 0.45),
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
          );
        }),
      ],
    );
  }
}

class _Conversation {
  _Conversation({
    required this.id,
    required this.name,
    this.isBroadcast = false,
  });

  final String id;
  final String name;
  final bool isBroadcast;
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({
    required this.state,
    required this.partnerId,
    required this.partnerName,
    required this.controller,
    required this.onSend,
    required this.onBack,
    this.canSend = true,
  });

  final GameState state;
  final String partnerId;
  final String partnerName;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onBack;
  final bool canSend;

  @override
  Widget build(BuildContext context) {
    final messages = state.threadWith(partnerId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: Text(
                  partnerName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'Начни переписку...',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.fromId == state.localPlayerId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppTheme.slaveTeal.withValues(alpha: 0.25)
                              : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: m.isBroadcast
                                ? AppTheme.gold.withValues(alpha: 0.5)
                                : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine ? 'Ты' : m.fromName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(m.text, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (canSend)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Сообщение...'),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.bossPurple),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Только босс может писать в этот канал',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
      ],
    );
  }
}
