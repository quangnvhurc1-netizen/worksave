import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../services/celebration.dart';
import '../theme.dart';

/// Pháo hoa + lời chúc mừng khi hoàn thành việc gì đó.
/// Tự lắng nghe [Celebration] nên nơi gọi chỉ cần `Celebration.instance.fire()`.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  static const Duration _visibleFor = Duration(milliseconds: 4200);

  late final ConfettiController _confetti;
  String? _message;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    Celebration.instance.message.addListener(_onMessage);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    Celebration.instance.message.removeListener(_onMessage);
    _confetti.dispose();
    super.dispose();
  }

  void _onMessage() {
    final message = Celebration.instance.message.value;
    if (message == null || !mounted) return;
    _confetti.play();
    setState(() => _message = message);
    _hideTimer?.cancel();
    _hideTimer = Timer(_visibleFor, () {
      if (mounted) setState(() => _message = null);
      Celebration.instance.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              maxBlastForce: 25,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              gravity: 0.25,
              shouldLoop: false,
            ),
          ),
          if (message != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) =>
                      Transform.scale(scale: max(0, value), child: child),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(30),
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl, vertical: 14),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
