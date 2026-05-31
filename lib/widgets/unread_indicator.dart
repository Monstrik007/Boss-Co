import 'package:flutter/material.dart';

class UnreadTab extends StatelessWidget {
  const UnreadTab({
    super.key,
    required this.label,
    this.hasUnread = false,
  });

  final String label;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (hasUnread) ...[
            const SizedBox(width: 4),
            Text(
              '❗',
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '❗',
      style: TextStyle(
        color: Colors.red.shade400,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class UnreadSectionHeader extends StatelessWidget {
  const UnreadSectionHeader({
    super.key,
    required this.title,
    this.hasUnread = false,
  });

  final String title;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: hasUnread ? Colors.red.shade300 : Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
        if (hasUnread) const UnreadBadge(),
      ],
    );
  }
}
