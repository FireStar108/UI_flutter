import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'window_item.dart';

class ExplodingWindow extends StatefulWidget {
  final WindowData data;
  final Rect startRect;
  final VoidCallback onComplete;

  const ExplodingWindow({
    super.key,
    required this.data,
    required this.startRect,
    required this.onComplete,
  });

  @override
  State<ExplodingWindow> createState() => _ExplodingWindowState();
}

class _ExplodingWindowState extends State<ExplodingWindow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Анимация сжатия в шарик
  late Animation<double> _widthAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _radiusAnimation;
  late Animation<double> _glowAnimation;
  
  // Частицы
  final int particleCount = 12;
  late List<Particle> particles;

  @override
  void initState() {
    super.initState();
    // 0.2с на сжатие, 0.4с на разлет частиц
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    const double sphereSize = 40.0;
    
    // Сцена 1: (0.0 - 0.3) Сжатие окна в шар
    _widthAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: widget.startRect.width, end: sphereSize), weight: 30),
      TweenSequenceItem(tween: ConstantTween(sphereSize), weight: 70),
    ]).animate(_controller);

    _heightAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: widget.startRect.height, end: sphereSize), weight: 30),
      TweenSequenceItem(tween: ConstantTween(sphereSize), weight: 70),
    ]).animate(_controller);

    _radiusAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 8.0, end: sphereSize / 2), weight: 30),
      TweenSequenceItem(tween: ConstantTween(sphereSize / 2), weight: 70),
    ]).animate(_controller);
    
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10), // Быстрая вспышка и исчезновение самого шарика
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
    ]).animate(_controller);

    // Подготовка частиц (начинают движение после t=0.4)
    final rnd = math.Random();
    particles = List.generate(particleCount, (i) {
      final angle = rnd.nextDouble() * 2 * math.pi;
      final distance = 60.0 + rnd.nextDouble() * 60.0; // от 60 до 120 пикселей разлет
      final size = 3.0 + rnd.nextDouble() * 6.0; // размер осколка от 3 до 9
      return Particle(
        angle: angle,
        distance: distance,
        size: size,
      );
    });

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final w = _widthAnimation.value;
        final h = _heightAnimation.value;
        final r = _radiusAnimation.value;
        final glow = _glowAnimation.value;
        
        final center = widget.startRect.center;
        final left = center.dx - w / 2;
        final top = center.dy - h / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Само окно (или то, что от него осталось во время сжатия/вспышки)
            if (progress < 0.4)
              Positioned(
                left: left,
                top: top,
                width: w,
                height: h,
                child: Opacity(
                  opacity: progress < 0.3 ? 1.0 : (1.0 - (progress - 0.3) * 10).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color.lerp(Colors.grey[900], widget.data.color.withValues(alpha: 0.8), glow),
                      borderRadius: BorderRadius.circular(r),
                      border: Border.all(
                        color: widget.data.color.withValues(alpha: 0.5 + 0.5 * glow),
                        width: 1.5 + 2 * glow,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.data.color.withValues(alpha: 0.8 * glow),
                          blurRadius: 30 * glow,
                          spreadRadius: 10 * glow,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
            // Частицы (Осколки) - появляются после t=0.35
            if (progress >= 0.35)
              ...particles.map((p) {
                // Прогресс частиц от 0.0 до 1.0 (в интервале 0.35 - 1.0)
                final pProgress = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
                
                // Легкое замедление (easeOut)
                final easeProgress = Curves.easeOutCubic.transform(pProgress);
                
                final pLeft = center.dx + math.cos(p.angle) * p.distance * easeProgress - p.size / 2;
                final pTop = center.dy + math.sin(p.angle) * p.distance * easeProgress - p.size / 2;
                
                // Частицы угасают к концу
                final pOpacity = (1.0 - easeProgress).clamp(0.0, 1.0);

                return Positioned(
                  left: pLeft,
                  top: pTop,
                  width: p.size,
                  height: p.size,
                  child: Opacity(
                    opacity: pOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.data.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.data.color.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class Particle {
  final double angle;
  final double distance;
  final double size;

  Particle({required this.angle, required this.distance, required this.size});
}
