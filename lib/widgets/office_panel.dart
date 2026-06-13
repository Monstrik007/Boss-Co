import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'player_identity.dart';
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
    this.isPlaying = false,
    this.onPromote,
    this.onDemote,
    this.onPaySubordinate,
    this.onAssignPreset,
    this.onAssignCustom,
  });

  final GameState state;
  final Stream<GameState> stateStream;
  final VoidCallback onAddPhoto;
  final void Function(String photoId, String emoji) onToggleReaction;
  final void Function(String photoId, String text) onAddComment;
  final DateTime? officeReadAt;
  final bool isPlaying;
  final void Function(String playerId)? onPromote;
  final void Function(String playerId)? onDemote;
  final void Function(String playerId)? onPaySubordinate;
  final void Function(String playerId, String taskId)? onAssignPreset;
  final void Function(
    String playerId,
    String title,
    String description,
    int reward,
    int penalty,
  )? onAssignCustom;

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
      ..sort((a, b) {
        final byRank = b.rankLevel.compareTo(a.rankLevel);
        if (byRank != 0) return byRank;
        return a.name.compareTo(b.name);
      });
    final local = state.localPlayer;
    final onlineCount =
        state.players.where((p) => p.isBoss || p.isConnected).length;
    final managedTeam = local == null
        ? <PlayerModel>[]
        : state.subordinates
            .where((p) => GameContent.canManage(local, p))
            .toList();
    final showManagement = isPlaying &&
        local != null &&
        !local.isBoss &&
        local.rankLevel > 0 &&
        managedTeam.isNotEmpty &&
        onPaySubordinate != null &&
        onAssignPreset != null &&
        onAssignCustom != null;

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
              if (team.isNotEmpty) ...[
                _HonorShameStrip(team: team),
                const SizedBox(height: 8),
              ],
              if (boss.isNotEmpty)
                ...boss.map(
                  (p) => _TeamMemberTile(
                    player: p,
                    isBoss: true,
                  ),
                ),
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
                ...team.map(
                  (p) => _TeamMemberTile(
                    player: p,
                    isPlaying: isPlaying,
                    isBossViewer: local?.isBoss == true,
                    onPromote: onPromote,
                    onDemote: onDemote,
                  ),
                ),
            ],
          ),
        ),
        if (showManagement) ...[
          const SizedBox(height: 20),
          _OfficeSection(
            icon: Icons.manage_accounts_rounded,
            iconColor: AppTheme.gold,
            title: 'Мои подчинённые',
            subtitle:
                'Баланс: ${local.balance} ₽ • зарплата ${state.defaultSalaryAmount} ₽',
            child: _SubordinateManagementPanel(
              manager: local,
              subordinates: managedTeam,
              salaryAmount: state.defaultSalaryAmount,
              onPay: onPaySubordinate!,
              onAssignPreset: onAssignPreset!,
              onAssignCustom: onAssignCustom!,
            ),
          ),
        ],
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

class _HonorShameStrip extends StatelessWidget {
  const _HonorShameStrip({required this.team});

  final List<PlayerModel> team;

  static PlayerModel? _bestHonor(List<PlayerModel> team, {String? excludeId}) {
    PlayerModel? best;
    for (final p in team) {
      if (p.id == excludeId || p.honorScore <= 0) continue;
      if (best == null || p.honorScore > best.honorScore) best = p;
    }
    return best;
  }

  static PlayerModel? _bestShame(List<PlayerModel> team, {String? excludeId}) {
    PlayerModel? best;
    for (final p in team) {
      if (p.id == excludeId || p.shameScore <= 0) continue;
      if (best == null || p.shameScore > best.shameScore) best = p;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    var honor = _bestHonor(team);
    var shame = _bestShame(team);

    if (honor != null && shame != null && honor.id == shame.id) {
      if (honor.honorScore >= shame.shameScore) {
        shame = _bestShame(team, excludeId: honor.id);
      } else {
        honor = _bestHonor(team, excludeId: shame.id);
      }
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _HonorShameChip(
              emoji: '🏆',
              label: 'Почёт',
              name: honor?.name,
              rank: honor?.rankLabel,
              score: honor?.honorScore,
              accent: AppTheme.gold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HonorShameChip(
              emoji: '💩',
              label: 'Позор',
              name: shame?.name,
              rank: shame?.rankLabel,
              score: shame?.shameScore,
              accent: AppTheme.accentPink,
            ),
          ),
        ],
      ),
    );
  }
}

class _HonorShameChip extends StatelessWidget {
  const _HonorShameChip({
    required this.emoji,
    required this.label,
    required this.name,
    this.rank,
    required this.score,
    required this.accent,
  });

  final String emoji;
  final String label;
  final String? name;
  final String? rank;
  final int? score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasLeader = name != null && score != null && score! > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent.withValues(alpha: 0.95),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLeader ? name! : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (hasLeader && rank != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    rank!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasLeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({
    required this.player,
    this.isBoss = false,
    this.isPlaying = false,
    this.isBossViewer = false,
    this.onPromote,
    this.onDemote,
  });

  final PlayerModel player;
  final bool isBoss;
  final bool isPlaying;
  final bool isBossViewer;
  final void Function(String playerId)? onPromote;
  final void Function(String playerId)? onDemote;

  @override
  Widget build(BuildContext context) {
    final items = player.ownedItems
        .map((id) => GameContent.itemById(id))
        .whereType<ShopItem>()
        .toList();
    final online = isBoss || player.isConnected;
    final rank = player.officeRank;
    final canPromote = isPlaying &&
        isBossViewer &&
        !isBoss &&
        player.rankLevel < GameConstants.maxRankLevel;
    final canDemote =
        isPlaying && isBossViewer && !isBoss && player.rankLevel > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isBoss ? AppTheme.gold : AppTheme.slaveTeal)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  isBoss ? '👑' : rank.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: online ? const Color(0xFF4ADE80) : Colors.white38,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardBg, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  softWrap: true,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    player.rankLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isBoss
                          ? AppTheme.gold.withValues(alpha: 0.95)
                          : AppTheme.slaveTeal.withValues(alpha: 0.9),
                    ),
                  ),
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
          if (canPromote || canDemote)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPromote)
                  _RankAdjustButton(
                    icon: Icons.arrow_upward_rounded,
                    color: AppTheme.gold,
                    onTap: () => onPromote?.call(player.id),
                  ),
                if (canPromote && canDemote) const SizedBox(height: 4),
                if (canDemote)
                  _RankAdjustButton(
                    icon: Icons.arrow_downward_rounded,
                    color: AppTheme.accentPink,
                    onTap: () => onDemote?.call(player.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RankAdjustButton extends StatelessWidget {
  const _RankAdjustButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _SubordinateManagementPanel extends StatelessWidget {
  const _SubordinateManagementPanel({
    required this.manager,
    required this.subordinates,
    required this.salaryAmount,
    required this.onPay,
    required this.onAssignPreset,
    required this.onAssignCustom,
  });

  final PlayerModel manager;
  final List<PlayerModel> subordinates;
  final int salaryAmount;
  final void Function(String playerId) onPay;
  final void Function(String playerId, String taskId) onAssignPreset;
  final void Function(
    String playerId,
    String title,
    String description,
    int reward,
    int penalty,
  ) onAssignCustom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: subordinates.map((p) {
        final canPay = manager.balance >= salaryAmount && salaryAmount > 0;
        final hasActiveTask = p.taskStatus != TaskStatus.none;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                p.rankLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              if (hasActiveTask) ...[
                const SizedBox(height: 6),
                Text(
                  'Уже есть активное задание',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentOrange.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: canPay ? () => onPay(p.id) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.slaveTeal,
                          foregroundColor: AppTheme.darkBg,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          'Зарплата $salaryAmount₽',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: hasActiveTask
                            ? null
                            : () => _openAssignSheet(context, p.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.bossPurple,
                          side: BorderSide(
                            color: AppTheme.bossPurple.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Задание',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _openAssignSheet(BuildContext context, String targetId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssignTaskSheet(
        managerBalance: manager.balance,
        onPreset: (taskId) {
          Navigator.pop(ctx);
          onAssignPreset(targetId, taskId);
        },
        onCustom: (title, description, reward, penalty) {
          Navigator.pop(ctx);
          onAssignCustom(targetId, title, description, reward, penalty);
        },
      ),
    );
  }
}

class _AssignTaskSheet extends StatefulWidget {
  const _AssignTaskSheet({
    required this.managerBalance,
    required this.onPreset,
    required this.onCustom,
  });

  final int managerBalance;
  final void Function(String taskId) onPreset;
  final void Function(String title, String description, int reward, int penalty)
      onCustom;

  @override
  State<_AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends State<_AssignTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rewardController = TextEditingController(text: '500');
  final _penaltyController = TextEditingController(text: '200');
  bool _customMode = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rewardController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Назначить задание',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Text(
                  'У вас ${widget.managerBalance}₽',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Готовые'),
                    selected: !_customMode,
                    onSelected: (_) => setState(() => _customMode = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Своё'),
                    selected: _customMode,
                    onSelected: (_) => setState(() => _customMode = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_customMode)
              ...GameContent.allTasks.map((task) {
                final affordable = widget.managerBalance >= task.reward;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: affordable,
                  title: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    affordable
                        ? 'Награда ${task.reward}₽ • штраф ${task.penalty}₽'
                        : 'Нужно ${task.reward}₽ — не хватает денег',
                    style: TextStyle(
                      fontSize: 12,
                      color: affordable
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppTheme.accentPink.withValues(alpha: 0.85),
                    ),
                  ),
                  onTap: affordable
                      ? () => widget.onPreset(task.id)
                      : null,
                );
              })
            else ...[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rewardController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Награда',
                        suffixText: '₽',
                        helperText:
                            'Макс. ${widget.managerBalance}₽',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _penaltyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Штраф',
                        suffixText: '₽',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitCustom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bossPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Назначить своё задание'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _submitCustom() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final reward = int.tryParse(_rewardController.text.trim()) ?? 0;
    final penalty = int.tryParse(_penaltyController.text.trim()) ?? 0;
    if (reward <= 0 || reward > widget.managerBalance) return;
    widget.onCustom(title, _descController.text, reward, penalty);
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
