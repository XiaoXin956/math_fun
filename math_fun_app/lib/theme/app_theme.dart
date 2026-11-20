import 'package:flutter/material.dart';

/// ============================================================
/// 数学乐园 · 设计系统 (Design System)
/// ------------------------------------------------------------
/// 界面语言：简洁、专注、以白为主的「做题氛围」。
/// 像一张干净的练习纸 —— 大量留白、克制用色、细线描边，
/// 让题目本身成为视觉焦点。所有色彩 / 圆角 / 阴影 / 字体
/// 层级集中于此，保证全线一致。
/// ============================================================

class AppColors {
  AppColors._();

  // —— 品牌与语义色：沉静墨蓝，专注而不喧宾夺主 ——
  /// 品牌墨蓝：主按钮、品牌标识
  static const brand = Color(0xFF3E5C76);
  static const brandDark = Color(0xFF2C465C);
  static const brandLight = Color(0xFF6C879E);

  /// 成功绿：答对、通关、正向积分（柔和低饱和）
  static const success = Color(0xFF3E9D7E);
  static const successSoft = Color(0xFFEAF5F1);

  /// 信息蓝：限时挑战、提示
  static const info = Color(0xFF4A7BA7);
  static const infoSoft = Color(0xFFEDF3F8);

  /// 靛蓝：年级标识、次强调
  static const purple = Color(0xFF5B6E88);
  static const purpleSoft = Color(0xFFEEF1F5);

  /// 暖金：星星、积分（点缀，不铺张）
  static const star = Color(0xFFD9A441);

  /// 提醒红：答错、扣分
  static const danger = Color(0xFFC9585C);
  static const dangerSoft = Color(0xFFFBEEEF);

  // —— 中性色：以白与冷灰为骨架 ——
  static const ink = Color(0xFF26313D); // 主文字（深墨灰）
  static const inkSoft = Color(0xFF6B7887); // 次要文字
  static const inkFaint = Color(0xFFA6B0BB); // 辅助文字
  static const canvas = Color(0xFFF7F8FA); // 页面极浅灰底（纸背）
  static const surface = Colors.white; // 卡片面（纸张白）
  static const surfaceAlt = Color(0xFFF1F4F7); // 浅冷灰内容底
  static const line = Color(0xFFE4E9EE); // 细线描边
}

/// 圆角刻度：基于 4px 栅格，儿童界面偏大圆角更亲和。
class AppRadius {
  AppRadius._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;
}

/// 阴影：极轻，纸片般的微浮起感，绝不喧宾夺主。
class AppShadows {
  AppShadows._();
  static const soft = [
    BoxShadow(color: Color(0x0A1A2634), blurRadius: 10, offset: Offset(0, 3)),
  ];
  static const medium = [
    BoxShadow(color: Color(0x121A2634), blurRadius: 18, offset: Offset(0, 6)),
  ];
  /// 做题氛围不需要发光；保留同名 token 但改为中性微阴影，避免调用处报错。
  static const brandGlow = [
    BoxShadow(color: Color(0x121A2634), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

/// 极简渐变：近纯色，仅保留细微层次，拒绝花哨。
class AppGradients {
  AppGradients._();

  static const brand = LinearGradient(
    colors: [AppColors.brand, AppColors.brandDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const success = LinearGradient(
    colors: [AppColors.success, Color(0xFF358B70)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  /// 头图改为沉静墨蓝近纯色渐变，营造安静的做题氛围。
  static const hero = LinearGradient(
    colors: [AppColors.brand, AppColors.brandDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// 字体层级：数字与标题更重更醒目，正文清晰易读。
class AppText {
  AppText._();
  static const display = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: -1,
  );
  static const headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const body = TextStyle(fontSize: 16, color: AppColors.ink);
  static const caption = TextStyle(fontSize: 13, color: AppColors.inkSoft);
}

/// 全局统一主题。所有页面共用，保证一致的设计语言。
ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.brand,
    onPrimary: Colors.white,
    primaryContainer: AppColors.surfaceAlt,
    onPrimaryContainer: AppColors.brandDark,
    secondary: AppColors.purple,
    onSecondary: Colors.white,
    tertiary: AppColors.success,
    onTertiary: Colors.white,
    error: AppColors.danger,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.ink),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.line, width: 1),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.inkFaint,
        elevation: 0,
        shadowColor: AppColors.brand.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(Colors.white24),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandDark,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.inkFaint),
      labelStyle: const TextStyle(color: AppColors.inkSoft),
      prefixIconColor: AppColors.brand,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.brandDark,
      unselectedLabelColor: AppColors.inkSoft,
      indicatorColor: AppColors.brand,
      labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brand,
      linearTrackColor: AppColors.surfaceAlt,
      circularTrackColor: AppColors.surfaceAlt,
      linearMinHeight: 10,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: AppText.headline,
      contentTextStyle: AppText.body,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),

    splashFactory: InkSparkle.splashFactory,
  );
}
