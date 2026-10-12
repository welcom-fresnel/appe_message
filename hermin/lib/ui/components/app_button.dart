import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, tonal }

enum AppButtonSize { md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
              );

    final minHeight = size == AppButtonSize.lg ? 52.0 : 44.0;

    switch (variant) {
      case AppButtonVariant.secondary:
        return OutlinedButton(onPressed: loading ? null : onPressed, style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(minHeight)), child: child);
      case AppButtonVariant.tonal:
        return FilledButton.tonal(onPressed: loading ? null : onPressed, style: FilledButton.styleFrom(minimumSize: Size.fromHeight(minHeight)), child: child);
      case AppButtonVariant.primary:
        return FilledButton(onPressed: loading ? null : onPressed, style: FilledButton.styleFrom(minimumSize: Size.fromHeight(minHeight)), child: child);
    }
  }
}
