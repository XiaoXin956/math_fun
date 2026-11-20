import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ============================================================
/// 设计系统 · 可复用组件层
/// 与 AppTheme 配套，提供品牌化的卡片 / 按钮 / 装饰，供各页面组合使用。
/// ============================================================

/// 章节小标题：彩色竖条 + 文字，统一各页面的分区视觉。
class SectionTitle extends StatelessWidget {
  final String text;
  final Color accent;
  final Widget? trailing;

  const SectionTitle(
    this.text, {
    super.key,
    this.accent = AppColors.brand,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 彩色圆形图标底座：把 emoji / 图标放进有色圆里，摆脱裸 emoji 的廉价感。
class IconBadge extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;
  final double emojiSize;

  const IconBadge(
    this.emoji, {
    super.key,
    this.color = AppColors.brand,
    this.size = 56,
    this.emojiSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
    );
  }
}

/// 品牌渐变按钮：带发光阴影与按压反馈，用于页面的主要行动点。
class BrandButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool loading;

  const BrandButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.gradient = AppGradients.brand,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    // 用 DecoratedBox + 透明 ElevatedButton 实现渐变：按钮本身背景透明，
    // 渐变由外层绘制；surfaceTintColor 置 0 避免 Material3 覆盖成浅色。
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null && !loading ? null : gradient,
        color: onPressed == null && !loading ? AppColors.line : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: onPressed != null && !loading ? AppShadows.brandGlow : null,
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// 通用渐变容器（供头图 / 计分卡 / 强调块复用）。
class GradientBox extends StatelessWidget {
  final Gradient gradient;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  const GradientBox({
    super.key,
    required this.children,
    this.gradient = AppGradients.hero,
    this.radius = AppRadius.xl,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
