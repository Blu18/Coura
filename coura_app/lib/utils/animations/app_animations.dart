// animated_motivational_card.dart
import 'package:flutter/material.dart';

class AnimatedMotivationalCard extends StatelessWidget {
  final Future<String> future;
  final Color backgroundColor;
  final Color textColor;
  final Color loadingColor;
  final double fontSize;

  const AnimatedMotivationalCard({
    Key? key,
    required this.future,
    this.backgroundColor = const Color.fromARGB(255, 229, 245, 235),
    this.textColor = Colors.black87,
    this.loadingColor = const Color.fromARGB(255, 2, 54, 10),
    this.fontSize = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return PulsingLoadingIndicator(color: loadingColor);
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FadeInSlideContainer(
            backgroundColor: backgroundColor,
            child: Text(
              snapshot.data!,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor,
              ),
              textAlign: TextAlign.start,
            ),
          );
        }

        return SizedBox.shrink();
      },
    );
  }
}

class PulsingLoadingIndicator extends StatelessWidget {
  final Color color;
  final double size;

  const PulsingLoadingIndicator({
    Key? key,
    required this.color,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: 0.3 + (value * 0.7),
            child: Transform.scale(
              scale: 0.8 + (value * 0.2),
              child: SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 3,
                ),
              ),
            ),
          );
        },
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
              child: Opacity(
                opacity: value,
                child: this.child,
              ),
            );
          },
        ),
      ),
    );
  }
}