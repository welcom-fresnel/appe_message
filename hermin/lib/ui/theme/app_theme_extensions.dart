import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 20,
    this.xxl = 24,
    this.xxxl = 32,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;

  @override
  AppSpacing copyWith({double? xs, double? sm, double? md, double? lg, double? xl, double? xxl, double? xxxl}) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      xxxl: xxxl ?? this.xxxl,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t) ?? xs,
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      xl: lerpDouble(xl, other.xl, t) ?? xl,
      xxl: lerpDouble(xxl, other.xxl, t) ?? xxl,
      xxxl: lerpDouble(xxxl, other.xxxl, t) ?? xxxl,
    );
  }
}

@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.pill = 999,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pill;

  @override
  AppRadii copyWith({double? sm, double? md, double? lg, double? xl, double? pill}) {
    return AppRadii(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pill: pill ?? this.pill,
    );
  }

  @override
  AppRadii lerp(ThemeExtension<AppRadii>? other, double t) {
    if (other is! AppRadii) return this;
    return AppRadii(
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      xl: lerpDouble(xl, other.xl, t) ?? xl,
      pill: lerpDouble(pill, other.pill, t) ?? pill,
    );
  }
}

@immutable
class AppDurations extends ThemeExtension<AppDurations> {
  const AppDurations({
    this.fast = const Duration(milliseconds: 120),
    this.normal = const Duration(milliseconds: 180),
    this.slow = const Duration(milliseconds: 240),
  });

  final Duration fast;
  final Duration normal;
  final Duration slow;

  @override
  AppDurations copyWith({Duration? fast, Duration? normal, Duration? slow}) {
    return AppDurations(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
    );
  }

  @override
  AppDurations lerp(ThemeExtension<AppDurations>? other, double t) {
    if (other is! AppDurations) return this;
    return AppDurations(
      fast: Duration(milliseconds: lerpDouble(fast.inMilliseconds.toDouble(), other.fast.inMilliseconds.toDouble(), t)!.round()),
      normal: Duration(milliseconds: lerpDouble(normal.inMilliseconds.toDouble(), other.normal.inMilliseconds.toDouble(), t)!.round()),
      slow: Duration(milliseconds: lerpDouble(slow.inMilliseconds.toDouble(), other.slow.inMilliseconds.toDouble(), t)!.round()),
    );
  }
}
