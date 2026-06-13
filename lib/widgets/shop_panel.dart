import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'player_identity.dart';
import 'unread_indicator.dart';

class ShopPanel extends StatelessWidget {
  const ShopPanel({
    super.key,
    required this.state,
    required this.onBuy,
    this.items,
    this.title,
    this.isElite = false,
    this.hasUnread = false,
  });

  final GameState state;
  final void Function(String itemId) onBuy;
  final List<ShopItem>? items;
  final String? title;
  final bool isElite;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final local = state.localPlayer;
    if (local == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final shopItems = items ?? GameContent.allItems;
    final owned = local.ownedItems.where((id) => shopItems.any((i) => i.id == id)).length;
    final total = shopItems.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (hasUnread) ...[
                const UnreadBadge(),
                const SizedBox(height: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: owned / total,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  color: AppTheme.slaveTeal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title ?? (isElite ? 'Элитная коллекция босса' : 'Путь к яхте: $owned / $total предметов'),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              if (!isElite) ...[
                const SizedBox(height: 4),
                Text(
                  '${local.displayEmoji} ${local.name} · ${local.rankLabel}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slaveTeal.withValues(alpha: 0.85),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '👑 ${local.name} · ${local.rankLabel}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gold.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shopItems.length,
            itemBuilder: (context, i) {
              final item = shopItems[i];
              final hasItem = local.ownsItem(item.id);
              final canAfford = isElite || local.balance >= item.price;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.glassCard(
                  borderColor: hasItem
                      ? AppTheme.gold
                      : (canAfford ? (isElite ? AppTheme.gold : AppTheme.slaveTeal) : null),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      decoration: hasItem
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _tierColor(item.tier)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'T${item.tier}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _tierColor(item.tier),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.25,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isElite
                                        ? '${item.price} ₽ (мелочь)'
                                        : '${item.price} ₽',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: hasItem
                                          ? AppTheme.gold
                                          : (canAfford
                                              ? AppTheme.gold
                                              : AppTheme.accentPink),
                                    ),
                                  ),
                                ),
                                if (hasItem)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.gold,
                                    size: 22,
                                  )
                                else
                                  SizedBox(
                                    height: 34,
                                    child: ElevatedButton(
                                      onPressed:
                                          canAfford ? () => onBuy(item.id) : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isElite
                                            ? AppTheme.gold
                                            : AppTheme.slaveTeal,
                                        foregroundColor: AppTheme.darkBg,
                                        disabledBackgroundColor: Colors.white12,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Купить',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (i * 40).ms);
            },
          ),
        ),
      ],
    );
  }

  Color _tierColor(int tier) {
    return switch (tier) {
      1 => Colors.grey,
      2 => AppTheme.slaveTeal,
      3 => AppTheme.bossPurple,
      4 => AppTheme.accentOrange,
      5 => AppTheme.gold,
      _ => Colors.white,
    };
  }
}
