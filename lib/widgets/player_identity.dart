import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';

extension PlayerDisplay on PlayerModel {
  String get displayEmoji => isBoss ? '👑' : officeRank.emoji;

  String get rankLabel => isBoss ? 'Босс' : officeRank.title;
}

/// Имя + должность в едином стиле.
class PlayerNameWithRank extends StatelessWidget {
  const PlayerNameWithRank({
    super.key,
    required this.player,
    this.nameStyle,
    this.rankStyle,
    this.trailing,
    this.maxNameLines = 2,
  });

  final PlayerModel player;
  final TextStyle? nameStyle;
  final TextStyle? rankStyle;
  final Widget? trailing;
  final int maxNameLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                player.name,
                style: nameStyle ??
                    const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                maxLines: maxNameLines,
                softWrap: true,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 2),
        Text(
          player.rankLabel,
          style: rankStyle ??
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: player.isBoss
                    ? AppTheme.gold.withValues(alpha: 0.9)
                    : AppTheme.slaveTeal.withValues(alpha: 0.85),
              ),
        ),
      ],
    );
  }
}
