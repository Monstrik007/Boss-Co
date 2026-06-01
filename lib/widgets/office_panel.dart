import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'office_photo_detail_screen.dart';
import 'office_photo_widgets.dart';
import 'unread_indicator.dart';

class OfficePanel extends StatelessWidget {
  const OfficePanel({
    super.key,
    required this.state,
    required this.stateStream,
    required this.onAddPhoto,
    required this.onToggleReaction,
    required this.onAddComment,
    this.officeReadAt,
  });

  final GameState state;
  final Stream<GameState> stateStream;
  final VoidCallback onAddPhoto;
  final void Function(String photoId, String emoji) onToggleReaction;
  final void Function(String photoId, String text) onAddComment;
  final DateTime? officeReadAt;

  @override
  Widget build(BuildContext context) {
    final myId = state.localPlayerId;
    final readAt = officeReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final hasUnreadPhotos = myId != null &&
        state.officePhotos.any(
          (p) => p.authorId != myId && p.createdAt.isAfter(readAt),
        );

    final boss = state.players.where((p) => p.isBoss).toList();
    final team = state.players.where((p) => !p.isBoss).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final onlineCount =
        state.players.where((p) => p.isBoss || p.isConnected).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _OfficeSection(
          icon: Icons.groups_rounded,
          iconColor: AppTheme.slaveTeal,
          title: 'Команда офиса',
          subtitle: '${state.players.length} в команде • $onlineCount онлайн',
          child: Column(
            children: [
              if (boss.isNotEmpty)
                ...boss.map((p) => _TeamMemberTile(player: p, isBoss: true)),
              if (boss.isNotEmpty && team.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              if (team.isEmpty && boss.isEmpty)
                _EmptyTeamHint()
              else
                ...team.map((p) => _TeamMemberTile(player: p)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _OfficeSection(
          icon: Icons.dashboard_customize_rounded,
          iconColor: AppTheme.bossPurple,
          title: 'Доска офиса',
          subtitle: state.officePhotos.isEmpty
              ? 'Пока нет постов'
              : '${state.officePhotos.length} ${_postWord(state.officePhotos.length)}',
          hasUnread: hasUnreadPhotos,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAddPhoto,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Опубликовать пост'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bossPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (state.officePhotos.isEmpty) ...[
                const SizedBox(height: 20),
                _EmptyBoardHint(),
              ] else ...[
                const SizedBox(height: 16),
                ...state.officePhotos.map(
                  (photo) => _OfficePhotoCard(
                    photo: photo,
                    localPlayerId: myId,
                    isUnread: myId != null &&
                        photo.authorId != myId &&
                        photo.createdAt.isAfter(readAt),
                    onToggleReaction: (emoji) =>
                        onToggleReaction(photo.id, emoji),
                    onOpenComments: () =>
                        _openPhotoDetail(context, photo.id, myId),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _postWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'постов';
    if (mod10 == 1) return 'пост';
    if (mod10 >= 2 && mod10 <= 4) return 'поста';
    return 'постов';
  }

  void _openPhotoDetail(BuildContext context, String photoId, String? myId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StreamBuilder<GameState>(
          stream: stateStream,
          initialData: state,
          builder: (context, snapshot) {
            final current = snapshot.data ?? state;
            OfficePhoto? photo;
            for (final p in current.officePhotos) {
              if (p.id == photoId) {
                photo = p;
                break;
              }
            }
            if (photo == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Пост')),
                body: const Center(child: Text('Пост не найден')),
              );
            }
            final resolved = photo;
            return OfficePhotoDetailScreen(
              photo: resolved,
              localPlayerId: myId,
              onToggleReaction: (emoji) => onToggleReaction(resolved.id, emoji),
              onAddComment: (text) => onAddComment(resolved.id, text),
            );
          },
        ),
      ),
    );
  }
}

class _OfficeSection extends StatelessWidget {
  const _OfficeSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.hasUnread = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(borderColor: iconColor),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withValues(alpha: 0.22),
                  iconColor.withValues(alpha: 0.04),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          if (hasUnread) const UnreadBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.player, this.isBoss = false});

  final PlayerModel player;
  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    final items = player.ownedItems
        .map((id) => GameContent.itemById(id))
        .whereType<ShopItem>()
        .toList();
    final online = isBoss || player.isConnected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isBoss ? AppTheme.gold : AppTheme.slaveTeal)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  isBoss ? '👑' : '🐑',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: online ? const Color(0xFF4ADE80) : Colors.white38,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardBg, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isBoss)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'БОСС',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.gold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isBoss
                      ? '∞ ₽'
                      : '${player.balance} ₽ • ${player.progress}%${online ? '' : ' • офлайн'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    items.map((i) => i.emoji).join(' '),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTeamHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Ждём сотрудников в комнате…',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _EmptyBoardHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text('📌', style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.3))),
          const SizedBox(height: 10),
          Text(
            'Доска пустая',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Нажми «Опубликовать пост» —\nфото, рисунок или мем для команды',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficePhotoCard extends StatelessWidget {
  const _OfficePhotoCard({
    required this.photo,
    required this.localPlayerId,
    required this.onToggleReaction,
    required this.onOpenComments,
    this.isUnread = false,
  });

  final OfficePhoto photo;
  final String? localPlayerId;
  final void Function(String emoji) onToggleReaction;
  final VoidCallback onOpenComments;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final commentCount = photo.comments.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? Colors.red.shade400.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OfficePhotoLongPressZone(
            photo: photo,
            localPlayerId: localPlayerId,
            onToggle: onToggleReaction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OfficePhotoPostMedia(
                  photo: photo,
                  localPlayerId: localPlayerId,
                  onToggleReaction: onToggleReaction,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.bossPurple.withValues(alpha: 0.35),
                        child: Text(
                          photo.authorName.isNotEmpty
                              ? photo.authorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            if (photo.caption != null &&
                                photo.caption!.isNotEmpty)
                              Text(
                                photo.caption!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (isUnread) const UnreadBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenComments,
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: commentCount > 0
                      ? AppTheme.slaveTeal
                      : Colors.white.withValues(alpha: 0.5),
                ),
                label: Text(
                  commentCount == 0 ? 'Комментарии' : '$commentCount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: commentCount > 0
                        ? AppTheme.slaveTeal
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  backgroundColor: commentCount > 0
                      ? AppTheme.slaveTeal.withValues(alpha: 0.1)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
