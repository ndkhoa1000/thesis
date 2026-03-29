import 'package:flutter/material.dart';

enum StateViewTone { adaptive, light, dark }

class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    required this.title,
    this.message,
    this.padding = const EdgeInsets.all(24),
    this.backgroundColor,
    this.tone = StateViewTone.adaptive,
    this.mainAxisSize = MainAxisSize.min,
  });

  final String title;
  final String? message;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final StateViewTone tone;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context, tone);
    final content = Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: mainAxisSize,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accentColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.foregroundColor.withValues(alpha: 0.84),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (backgroundColor == null) {
      return content;
    }

    return ColoredBox(color: backgroundColor!, child: content);
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Thử lại',
    this.padding = const EdgeInsets.all(24),
    this.tone = StateViewTone.adaptive,
    this.mainAxisSize = MainAxisSize.min,
  });

  final String title;
  final String message;
  final Future<void> Function()? onRetry;
  final String retryLabel;
  final EdgeInsetsGeometry padding;
  final StateViewTone tone;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context, tone);
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: mainAxisSize,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.accentColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foregroundColor.withValues(alpha: 0.84),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onRetry?.call(),
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(24),
    this.tone = StateViewTone.adaptive,
    this.mainAxisSize = MainAxisSize.min,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final StateViewTone tone;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context, tone);
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: mainAxisSize,
          children: [
            Icon(icon, size: 56, color: colors.accentColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foregroundColor.withValues(alpha: 0.84),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_outlined),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateViewColors {
  const _StateViewColors({
    required this.foregroundColor,
    required this.accentColor,
  });

  final Color foregroundColor;
  final Color accentColor;
}

_StateViewColors _resolveColors(BuildContext context, StateViewTone tone) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = switch (tone) {
    StateViewTone.adaptive => Theme.of(context).brightness == Brightness.dark,
    StateViewTone.light => false,
    StateViewTone.dark => true,
  };

  return _StateViewColors(
    foregroundColor: isDark ? Colors.white : colorScheme.onSurface,
    accentColor: isDark ? colorScheme.primaryFixed : colorScheme.primary,
  );
}
