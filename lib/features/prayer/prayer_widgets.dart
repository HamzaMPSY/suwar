import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'prayer_state.dart';
import 'prayer_format.dart';

class NextPrayerCard extends StatefulWidget {
  const NextPrayerCard({super.key, required this.state, this.onTap});
  final PrayerState state;
  final VoidCallback? onTap;
  @override
  State<NextPrayerCard> createState() => _NextPrayerCardState();
}

class _NextPrayerCardState extends State<NextPrayerCard> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final settings = widget.state.settings;
      final now = DateTime.now().toUtc();
      final next = widget.state.calculator.next(settings, now);
      final local = widget.state.calculator.localTime(settings, next.timeUtc);
      final scaled = MediaQuery.textScalerOf(context).scale(1) > 1.2;
      Widget label(
        String text,
        double size, {
        bool display = false,
        Color? color,
      }) => Text(
        text,
        textAlign: TextAlign.start,
        textDirection: display ? TextDirection.rtl : null,
        style: display
            ? headingStyle(
                context,
                size: size,
                color: color ?? SuwarColors.ivory,
              )
            : TextStyle(
                fontSize: size,
                height: 1.65,
                color: color ?? const Color(0xFFD1D7C8),
              ),
      );
      Widget clock() => Text(
        prayerClock(local),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 29,
          height: 1.65,
          color: SuwarColors.ivory,
        ),
      );
      return Material(
        color: SuwarColors.green,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          container: true,
          button: widget.onTap != null,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                const Positioned(
                  left: -25,
                  top: 60,
                  child: ExcludeSemantics(
                    child: GeometricOrnament(
                      size: 145,
                      color: Color(0xFF3D6253),
                    ),
                  ),
                ),
                if (scaled)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        label('الصلاة القادمة', 13),
                        label(next.kind.label, 40, display: true),
                        clock(),
                        label(
                          prayerCountdown(next.timeUtc.difference(now)),
                          13,
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          right: 20,
                          top: 14,
                          height: 30,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: label('الصلاة القادمة', 13),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          top: 46,
                          height: 62,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: label(next.kind.label, 40, display: true),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          top: 110,
                          height: 48,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: clock(),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          top: 151,
                          height: 25,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: label(
                              prayerCountdown(next.timeUtc.difference(now)),
                              13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PrayerNotice extends StatelessWidget {
  const PrayerNotice({
    super.key,
    required this.message,
    this.icon,
    this.action,
  });
  final String message;
  final IconData? icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: SuwarColors.sage,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: SuwarColors.green, size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: SuwarColors.ink,
                  fontSize: 14,
                  height: 1.8,
                ),
              ),
            ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}
