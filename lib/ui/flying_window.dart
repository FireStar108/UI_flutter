import 'package:flutter/material.dart';
import 'window_item.dart';

class FlyingWindow extends StatefulWidget {
  final WindowData data;
  final Rect startRect;
  final Rect endRect;
  final bool isMinimizing;
  final VoidCallback onComplete;

  const FlyingWindow({
    super.key,
    required this.data,
    required this.startRect,
    required this.endRect,
    required this.isMinimizing,
    required this.onComplete,
  });

  @override
  State<FlyingWindow> createState() => _FlyingWindowState();
}

class _FlyingWindowState extends State<FlyingWindow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Анимации координат центра
  late Animation<double> _xAnimation;
  late Animation<double> _yAnimation;
  
  // Анимации размеров и скруглений
  late Animation<double> _widthAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _radiusAnimation;
  
  // Анимация свечения
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Разворачивание (0.4с), сворачивание (0.6с) для плавности
    final duration = widget.isMinimizing ? const Duration(milliseconds: 600) : const Duration(milliseconds: 400);
    _controller = AnimationController(vsync: this, duration: duration);

    // Определяем промежуточную "сферу" (шарик)
    const double sphereSize = 40.0;
    
    // Дуга полета: X и Y получают разные кривые (одна ускоряется, другая замедляется)
    Curve xCurve = widget.isMinimizing ? Curves.easeOutCubic : Curves.easeInCubic;
    Curve yCurve = widget.isMinimizing ? Curves.easeInCubic : Curves.easeOutCubic;

    _xAnimation = Tween<double>(
      begin: widget.startRect.center.dx,
      end: widget.endRect.center.dx,
    ).animate(CurvedAnimation(parent: _controller, curve: xCurve));

    _yAnimation = Tween<double>(
      begin: widget.startRect.center.dy,
      end: widget.endRect.center.dy,
    ).animate(CurvedAnimation(parent: _controller, curve: yCurve));

    // Сложная анимация формы: Прямоугольник Окна -> Шарик -> Прямоугольник Taskbar
    // Если минимизируем:
    // 0.0 - 0.3: Окно сжимается в шарик (width/height -> 40, radius -> 20)
    // 0.3 - 0.7: Летит шарик (размер 40, radius 20)
    // 0.7 - 1.0: Шарик расширяется в Taskbar Item (width->140, height->48, radius->6)
    
    if (widget.isMinimizing) {
      _widthAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: widget.startRect.width, end: sphereSize), weight: 30),
        TweenSequenceItem(tween: ConstantTween(sphereSize), weight: 40),
        TweenSequenceItem(tween: Tween(begin: sphereSize, end: widget.endRect.width), weight: 30),
      ]).animate(_controller);

      _heightAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: widget.startRect.height, end: sphereSize), weight: 30),
        TweenSequenceItem(tween: ConstantTween(sphereSize), weight: 40),
        TweenSequenceItem(tween: Tween(begin: sphereSize, end: widget.endRect.height), weight: 30),
      ]).animate(_controller);

      _radiusAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 8.0, end: sphereSize / 2), weight: 30),
        TweenSequenceItem(tween: ConstantTween(sphereSize / 2), weight: 40),
        TweenSequenceItem(tween: Tween(begin: sphereSize / 2, end: 6.0), weight: 30),
      ]).animate(_controller);
      
      _glowAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
      ]).animate(_controller);
    } else {
      // При разворачивании - логика обратная
      _widthAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: widget.startRect.width, end: sphereSize), weight: 30),
        TweenSequenceItem(tween: ConstantTween(sphereSize), weight: 40),
        TweenSequenceItem(tween: Tween(begin: sphereSize, end: widget.endRect.width), weight: 30),
      ]).animate(_controller);

      _heightAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: widget.startRect.height, end: sphereSize), weight: 30),
        TweenSequenceItem(tween: ConstantTween(sphereSize), weight: 40),
        TweenSequenceItem(tween: Tween(begin: sphereSize, end: widget.endRect.height), weight: 30),
      ]).animate(_controller);

      _radiusAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 6.0, end: sphereSize / 2), weight: 30),
        TweenSequenceItem(tween: ConstantTween(sphereSize / 2), weight: 40),
        TweenSequenceItem(tween: Tween(begin: sphereSize / 2, end: 8.0), weight: 30),
      ]).animate(_controller);
      
      _glowAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
      ]).animate(_controller);
    }

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
        final currentX = _xAnimation.value;
        final currentY = _yAnimation.value;
        final w = _widthAnimation.value;
        final h = _heightAnimation.value;
        final r = _radiusAnimation.value;
        final glow = _glowAnimation.value;
        
        // Определяем левый верхний угол (чтобы центр всегда был в currentX/Y)
        final left = currentX - w / 2;
        final top = currentY - h / 2;

        return Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              // Если анимация ближе к окну, показываем темно-серый фон окна.
              // Если ближе к шарику (glow==1), показываем акцентный цвет шарика.
              color: Color.lerp(Colors.grey[900], widget.data.color.withValues(alpha: 0.8), glow),
              borderRadius: BorderRadius.circular(r),
              border: Border.all(
                color: widget.data.color.withValues(alpha: 0.5 + 0.5 * glow),
                width: 1.5 + 1.5 * glow,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.data.color.withValues(alpha: 0.6 * glow),
                  blurRadius: 20 * glow,
                  spreadRadius: 5 * glow,
                ),
                BoxShadow(
                  color: widget.data.color.withValues(alpha: 0.3 * glow),
                  blurRadius: 40 * glow,
                  spreadRadius: 10 * glow,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
