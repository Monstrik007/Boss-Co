import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'unread_indicator.dart';

class OfficePanel extends StatelessWidget {
  const OfficePanel({
    super.key,
    required this.state,
    required this.onAddPhoto,
    this.officeReadAt,
  });

  final GameState state;
  final VoidCallback onAddPhoto;
  final DateTime? officeReadAt;

  @override
  Widget build(BuildContext context) {
    final myId = state.localPlayerId;
    final readAt = officeReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final hasUnreadPhotos = myId != null &&
        state.officePhotos.any(
          (p) => p.authorId != myId && p.createdAt.isAfter(readAt),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAddPhoto,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Фото + рисунок в офис'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bossPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Команда офиса',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        ...state.players.map((p) => _EmployeeCard(player: p)),
        if (state.officePhotos.isNotEmpty) ...[
          const SizedBox(height: 24),
          UnreadSectionHeader(
            title: 'Доска офиса',
            hasUnread: hasUnreadPhotos,
          ),
          const SizedBox(height: 12),
          ...state.officePhotos.map(
            (photo) => _OfficePhotoCard(
              photo: photo,
              isUnread: myId != null &&
                  photo.authorId != myId &&
                  photo.createdAt.isAfter(readAt),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.player});

  final PlayerModel player;

  @override
  Widget build(BuildContext context) {
    final items = player.ownedItems
        .map((id) => GameContent.itemById(id))
        .whereType<ShopItem>()
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCard(
        borderColor: player.isBoss ? AppTheme.gold : AppTheme.slaveTeal,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(player.isBoss ? '👑' : '🐑', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  player.isBoss
                      ? 'Босс • ∞ ₽'
                      : '${player.balance} ₽ • ${player.progress}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  items.isEmpty
                      ? 'Имущество: пока пусто'
                      : items.map((i) => '${i.emoji} ${i.name}').join(' • '),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
              ],
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
    this.isUnread = false,
  });

  final OfficePhoto photo;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (photo.hasImage) {
      try {
        bytes = base64Decode(photo.imageBase64);
      } catch (_) {
        bytes = null;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.glassCard(
        borderColor: isUnread ? Colors.red.shade400 : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bytes != null && bytes.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) => _PhotoPlaceholder(
                        message: 'Не удалось показать фото',
                      ),
                    ),
                    CustomPaint(
                      painter: _StrokePainter(photo.strokes),
                    ),
                  ],
                ),
              ),
            )
          else
            _PhotoPlaceholder(
              message: photo.hasImage ? 'Фото загружается...' : 'Нет изображения',
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '📸 ${photo.authorName}${photo.caption != null ? ' — ${photo.caption}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                if (isUnread) const UnreadBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: Colors.white.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, color: Colors.white.withValues(alpha: 0.35), size: 36),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);

  final List<DrawStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final first = stroke.points.first;
      path.moveTo(first.x * size.width, first.y * size.height);
      for (var i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        path.lineTo(p.x * size.width, p.y * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
