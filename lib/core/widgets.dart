import 'package:flutter/material.dart';
import 'quran_repository.dart';
import 'theme.dart';
import 'ornament.dart';
import 'suwar_icons.dart';
export 'ornament.dart';
export 'suwar_icons.dart';
export 'navigation.dart';

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.padding = const EdgeInsetsDirectional.fromSTEB(24, 21, 24, 20),
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: onBack == null ? 0 : 48,
                end: trailing == null ? 0 : 48,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(title, style: headingStyle(context, size: 32)),
                ),
              ),
            ),
            if (onBack != null)
              PositionedDirectional(
                start: -8,
                top: 1,
                child: IconButton(
                  tooltip: 'رجوع',
                  onPressed: onBack,
                  icon: const SuwarIcon(SuwarSymbol.back),
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
            if (trailing != null)
              PositionedDirectional(end: -8, top: 1, child: trailing!),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: SuwarColors.muted,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class SuwarChoicePill extends StatelessWidget {
  const SuwarChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double? width;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    enabled: onTap != null,
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            widthFactor: 1,
            child: Container(
              width: width,
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? SuwarColors.green : SuwarColors.sage,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: selected ? SuwarColors.paper : SuwarColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.minimumHeight = 56,
    this.verticalPadding = 14,
    this.backgroundColor,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final double minimumHeight, verticalPadding;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(double.infinity, minimumHeight)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'NotoSansArabic',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.6,
        ),
      ),
    );
    final labelWidget = Text(label, textAlign: TextAlign.center);
    return secondary
        ? OutlinedButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: backgroundColor == null
                  ? null
                  : WidgetStatePropertyAll(backgroundColor),
              side: const WidgetStatePropertyAll(
                BorderSide(color: SuwarColors.line),
              ),
            ),
            child: labelWidget,
          )
        : FilledButton(onPressed: onPressed, style: style, child: labelWidget);
  }
}

class SurahTile extends StatelessWidget {
  const SurahTile({
    super.key,
    required this.surah,
    this.memorized = false,
    this.onTap,
    this.trailing,
    this.metadataSuffix,
    this.titleSize = 24,
    this.ornamentSize = 38,
    this.metadataSize = 12,
    this.minimumHeight = 76,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });
  final double titleSize, ornamentSize, metadataSize, minimumHeight;
  final EdgeInsetsGeometry padding;
  final Surah surah;
  final bool memorized;
  final String? metadataSuffix;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minimumHeight),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Rosette(
                  size: ornamentSize,
                  label: displayNumber(surah.number),
                  color: SuwarColors.goldText,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.name,
                      style: headingStyle(context, size: titleSize),
                    ),
                    Text(
                      '${displayNumber(surah.verseCount)} آيات${metadataSuffix == null ? '' : ' · $metadataSuffix'}',
                      style: TextStyle(
                        fontSize: metadataSize,
                        color: SuwarColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (memorized)
                Container(
                  width: 80,
                  constraints: const BoxConstraints(minHeight: 36),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SuwarColors.sage,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'محفوظة',
                    style: TextStyle(fontSize: 12, color: SuwarColors.green),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: SuwarColors.muted,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: SuwarColors.goldText),
        const SizedBox(height: 24),
        Text(
          title,
          style: headingStyle(context, size: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SuwarColors.muted,
            fontSize: 16,
            height: 1.8,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 28), action!],
      ],
    ),
  );
}

/// Quiet informational panel used by the saved production FigCraft frames.
class DesignNotice extends StatelessWidget {
  const DesignNotice({super.key, required this.message, this.minHeight = 110});
  final String message;
  final double minHeight;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    alignment: AlignmentDirectional.centerStart,
    decoration: BoxDecoration(
      color: SuwarColors.sage,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      message,
      style: const TextStyle(
        fontSize: 13,
        height: 1.65,
        color: SuwarColors.green,
      ),
    ),
  );
}
