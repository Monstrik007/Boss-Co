import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Text(item.emoji, style: const TextStyle(fontSize: 32)),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            decoration:
                                hasItem ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _tierColor(item.tier).withValues(alpha: 0.2),
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isElite ? '${item.price} ₽ (мелочь)' : '${item.price} ₽',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: hasItem
                              ? AppTheme.gold
                              : (canAfford ? AppTheme.gold : AppTheme.accentPink),
                        ),
                      ),
                    ],
                  ),
                  trailing: hasItem
                      ? const Icon(Icons.check_circle, color: AppTheme.gold)
                      : ElevatedButton(
                          onPressed: canAfford ? () => onBuy(item.id) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isElite ? AppTheme.gold : AppTheme.slaveTeal,
                            foregroundColor: AppTheme.darkBg,
                            disabledBackgroundColor: Colors.white12,
                          ),
                          child: const Text('Купить'),
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
