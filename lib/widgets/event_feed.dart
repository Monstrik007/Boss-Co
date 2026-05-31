import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'unread_indicator.dart';

class EventFeed extends StatelessWidget {
  const EventFeed({
    super.key,
    required this.events,
    this.eventsReadAt,
  });

  final List<GameEvent> events;
  final DateTime? eventsReadAt;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          'Пока тихо...\nСлишком тихо для офиса',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }

    final readAt = eventsReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final event = events[i];
        final unread = event.timestamp.isAfter(readAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassCard(
            borderColor: unread
                ? Colors.red.shade400
                : (event.isFunny ? AppTheme.accentPink : null),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (unread) ...[
                      const UnreadBadge(),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      event.message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: event.isFunny
                            ? AppTheme.accentPink.withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (i * 30).ms).slideX(begin: 0.05);
      },
    );
  }
}
