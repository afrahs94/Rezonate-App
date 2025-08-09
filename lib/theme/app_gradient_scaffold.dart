import 'package:flutter/material.dart';

/// You already defined AppGradients in main.dart as a ThemeExtension.
/// This scaffold pulls the gradient from Theme and applies it app-wide.
class AppGradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;

  const AppGradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.padding,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final grads = Theme.of(context).extension<AppGradients>();
    final bgTop = grads?.top ?? const Color(0xFFD7C3F1);
    final bgBottom = grads?.bottom ?? const Color(0xFFBDE8CA);

    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: body,
    );

    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgTop, bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: safeArea ? SafeArea(child: content) : content,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Copy of your ThemeExtension (must match the one in main.dart)
@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  final Color top;
  final Color bottom;
  const AppGradients({required this.top, required this.bottom});

  @override
  AppGradients copyWith({Color? top, Color? bottom}) =>
      AppGradients(top: top ?? this.top, bottom: bottom ?? this.bottom);

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return AppGradients(
      top: Color.lerp(top, other.top, t) ?? top,
      bottom: Color.lerp(bottom, other.bottom, t) ?? bottom,
    );
  }
}
