import 'package:flutter/material.dart';

import '../../constants/eevee_assets.dart';

class EeveeCycler extends StatefulWidget {
  const EeveeCycler({
    super.key,
    required this.names,
    required this.size,
    required this.cycleDuration,
    this.childBuilder,
  });

  final List<String> names;
  final double size;
  final Duration cycleDuration;
  final Widget Function(String name, Animation<double> animation)? childBuilder;

  @override
  State<EeveeCycler> createState() => _EeveeCyclerState();
}

class _EeveeCyclerState extends State<EeveeCycler>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.cycleDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.asset(
          EeveeAssets.path(EeveeAssets.brand),
          fit: BoxFit.contain,
        ),
      );
    }

    final n = widget.names.length;
    final sliceDuration = 1.0 / n;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(n, (i) {
          final start = i * sliceDuration;
          final fadeIn = start;
          final visible = start + sliceDuration * 0.2;
          final fadeOut = start + sliceDuration * 0.95;
          final end = start + sliceDuration;

          final animation = TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: (visible - fadeIn) / sliceDuration),
            TweenSequenceItem(tween: ConstantTween(1.0), weight: (fadeOut - visible) / sliceDuration),
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: (end - fadeOut) / sliceDuration),
          ]).animate(
            CurvedAnimation(
              parent: _controller,
              curve: Interval(start, i == n - 1 ? 1.0 : start + sliceDuration),
            ),
          );

          final name = widget.names[i];

          if (widget.childBuilder != null) {
            return widget.childBuilder!(name, animation);
          }

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Opacity(
              opacity: animation.value,
              child: child,
            ),
            child: Image.asset(
              EeveeAssets.path(name),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          );
        }),
      ),
    );
  }
}
