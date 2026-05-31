import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/game_models.dart';
import '../theme/app_theme.dart';

class PrankOverlay extends StatefulWidget {
  const PrankOverlay({
    super.key,
    required this.effect,
    required this.isBoss,
  });

  final PrankEffect effect;
  final bool isBoss;

  @override
  State<PrankOverlay> createState() => _PrankOverlayState();
}

class _PrankOverlayState extends State<PrankOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final List<_FloatEmoji> _floaters;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: 900.ms)..repeat(reverse: true);
    final rnd = Random(widget.effect.prankId.hashCode);
    _floaters = List.generate(10, (i) {
      return _FloatEmoji(
        emoji: widget.effect.emoji,
        left: rnd.nextDouble(),
        top: rnd.nextDouble(),
        size: 24 + rnd.nextInt(28).toDouble(),
        delayMs: i * 120,
      );
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [
                        AppTheme.accentPink.withValues(alpha: 0.18 + t * 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.25 + t * 0.25),
                      width: 4 + t * 2,
                    ),
                  ),
                ),
              ),
              ..._floaters.map(
                (f) => Positioned(
                  left: f.left * size.width,
                  top: f.top * size.height,
                  child: Text(
                    f.emoji,
                    style: TextStyle(fontSize: f.size),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 300.ms, delay: f.delayMs.ms)
                      .moveY(begin: 0, end: -14, duration: 900.ms, delay: f.delayMs.ms),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.effect.emoji} ТЕБЯ ПРИКОЛОЛИ!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.red.shade300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.effect.fromName}: ${widget.effect.title}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          widget.effect.bossEffect,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FloatEmoji {
  _FloatEmoji({
    required this.emoji,
    required this.left,
    required this.top,
    required this.size,
    required this.delayMs,
  });

  final String emoji;
  final double left;
  final double top;
  final double size;
  final int delayMs;
}
