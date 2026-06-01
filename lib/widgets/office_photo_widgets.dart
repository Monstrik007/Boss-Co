import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';

/// Долгое нажатие на фото — всплывающий выбор реакции.
class OfficePhotoLongPressZone extends StatelessWidget {
  const OfficePhotoLongPressZone({
    super.key,
    required this.photo,
    required this.localPlayerId,
    required this.onToggle,
    required this.child,
  });

  final OfficePhoto photo;
  final String? localPlayerId;
  final void Function(String emoji) onToggle;
  final Widget child;

  Future<void> _showReactionPicker(BuildContext context) async {
    if (localPlayerId == null) return;
    HapticFeedback.mediumImpact();

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !context.mounted) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;

    const pickerHeight = 58.0;
    const pickerWidth = 300.0;
    var left = offset.dx + size.width / 2 - pickerWidth / 2;
    var top = offset.dy - pickerHeight - 10;
    if (top < topPad + 8) {
      top = offset.dy + size.height + 10;
    }
    left = left.clamp(8.0, screen.width - pickerWidth - 8);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Реакции',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, _) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: pickerWidth,
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                  ),
                  child: _ReactionPickerBubble(
                    photo: photo,
                    localPlayerId: localPlayerId!,
                    onPick: (emoji) {
                      Navigator.of(dialogContext).pop();
                      onToggle(emoji);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: localPlayerId != null ? () => _showReactionPicker(context) : null,
      child: child,
    );
  }
}

/// Только уже поставленные реакции — внизу справа на фото.
class OfficePhotoReactionChips extends StatelessWidget {
  const OfficePhotoReactionChips({
    super.key,
    required this.photo,
    required this.localPlayerId,
    required this.onToggle,
  });

  final OfficePhoto photo;
  final String? localPlayerId;
  final void Function(String emoji) onToggle;

  @override
  Widget build(BuildContext context) {
    final active = OfficeReactions.emojis
        .where((emoji) => photo.countForEmoji(emoji) > 0)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: active.map((emoji) {
        final count = photo.countForEmoji(emoji);
        final mine = localPlayerId != null &&
            photo.hasReaction(localPlayerId!, emoji);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: localPlayerId != null ? () => onToggle(emoji) : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: mine
                      ? AppTheme.bossPurple
                      : Colors.white.withValues(alpha: 0.15),
                  width: mine ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 17)),
                  if (count > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Фото с реакциями в углу (только если они уже есть).
class OfficePhotoPostMedia extends StatelessWidget {
  const OfficePhotoPostMedia({
    super.key,
    required this.photo,
    required this.localPlayerId,
    required this.onToggleReaction,
  });

  final OfficePhoto photo;
  final String? localPlayerId;
  final void Function(String emoji) onToggleReaction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OfficePhotoImage(photo: photo),
        Positioned(
          right: 10,
          bottom: 10,
          child: OfficePhotoReactionChips(
            photo: photo,
            localPlayerId: localPlayerId,
            onToggle: onToggleReaction,
          ),
        ),
      ],
    );
  }
}

class _ReactionPickerBubble extends StatelessWidget {
  const _ReactionPickerBubble({
    required this.photo,
    required this.localPlayerId,
    required this.onPick,
  });

  final OfficePhoto photo;
  final String localPlayerId;
  final void Function(String emoji) onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.bossPurple.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.bossPurple.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: OfficeReactions.emojis.map((emoji) {
            final mine = photo.hasReaction(localPlayerId, emoji);
            final count = photo.countForEmoji(emoji);
            return InkWell(
              onTap: () => onPick(emoji),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: mine
                      ? AppTheme.bossPurple.withValues(alpha: 0.4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    if (count > 0)
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gold,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class OfficePhotoImage extends StatelessWidget {
  const OfficePhotoImage({super.key, required this.photo});

  final OfficePhoto photo;

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

    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
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
                errorBuilder: (_, __, ___) => const _PhotoPlaceholder(
                  message: 'Не удалось показать фото',
                ),
              ),
              CustomPaint(
                painter: _PhotoOverlayPainter(
                  strokes: photo.strokes,
                  textOverlays: photo.textOverlays,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _PhotoPlaceholder(
      message: photo.hasImage ? 'Фото загружается...' : 'Нет изображения',
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, color: Colors.white.withValues(alpha: 0.35), size: 36),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _PhotoOverlayPainter extends CustomPainter {
  _PhotoOverlayPainter({
    required this.strokes,
    required this.textOverlays,
  });

  final List<DrawStroke> strokes;
  final List<PhotoTextOverlay> textOverlays;

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

    for (final overlay in textOverlays) {
      if (overlay.text.isEmpty) continue;
      final cx = overlay.x * size.width;
      final cy = overlay.y * size.height;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(overlay.rotation);

      final style = TextStyle(
        color: Color(overlay.color),
        fontSize: overlay.fontSize * overlay.scale,
        fontWeight: FontWeight.w800,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
        ],
      );
      final painter = TextPainter(
        text: TextSpan(text: overlay.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(-painter.width / 2, -painter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PhotoOverlayPainter oldDelegate) => true;
}

class OfficeCommentTile extends StatelessWidget {
  const OfficeCommentTile({super.key, required this.comment});

  final PhotoComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.bossPurple.withValues(alpha: 0.35),
            child: Text(
              comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppTheme.slaveTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
