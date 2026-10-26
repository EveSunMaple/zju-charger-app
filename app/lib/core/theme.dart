import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF3EEE5);
  static const card = Color(0xFFFBF8F1);
  static const card2 = Color(0xFFF6F1E7);
  static const line = Color(0x2460503C);
  static const text = Color(0xFF3B342A);
  static const sub = Color(0xFF8B7E6B);
  static const dim = Color(0x0F60503C);
  static const free = Color(0xFF5C875C);
  static const busy = Color(0xFFBC5A4C);
  static const fault = Color(0xFFA2967F);
  static const accent = Color(0xFFA26B4A);
  static const warn = Color(0xFFB98A3F);
  static const storage = Color(0xFFC4B8A4);
}

class AppText {
  static const heroLabel = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: AppColors.accent,
  );
  static const heroName = TextStyle(
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const number = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const cardTitle = TextStyle(
    fontSize: 13.5,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const small = TextStyle(
    fontSize: 11,
    height: 1.3,
    color: AppColors.sub,
  );
  static const tiny = TextStyle(
    fontSize: 10,
    height: 1.25,
    color: AppColors.sub,
  );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.accent,
        onPrimary: AppColors.card,
        surface: AppColors.card,
        onSurface: AppColors.text,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: AppColors.line,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.card,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A60503C),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0F60503C),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
