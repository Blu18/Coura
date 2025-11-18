import 'package:flutter/material.dart';

class AnimatedCard extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  const AnimatedCard({
    Key? key,
    required this.text,
    this.backgroundColor = const Color.fromARGB(255, 229, 245, 235),
    this.textColor = Colors.black87,
    this.fontSize = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeInSlideContainer(
      backgroundColor: backgroundColor,
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, color: textColor),
        textAlign: TextAlign.start,
      ),
    );
  }
}

class FadeInSlideContainer extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final Duration? duration;

  const FadeInSlideContainer({
    Key? key,
    required this.child,
    this.backgroundColor = const Color.fromARGB(255, 229, 245, 235),
    this.borderRadius,
    this.padding,
    this.duration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: duration ?? Duration(milliseconds: 500),
      child: AnimatedContainer(
        duration: duration ?? Duration(milliseconds: 400),
        curve: Curves.easeOut,
        padding: padding ?? EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: duration ?? Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: this.child),
            );
          },
        ),
      ),
    );
  }
}
