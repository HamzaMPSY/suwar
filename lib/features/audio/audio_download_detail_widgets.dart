import 'package:flutter/material.dart';
import '../../core/theme.dart';

Widget audioDetailCard(
  BuildContext context, {
  required double minHeight,
  required List<Widget> children,
}) => Container(
  constraints: BoxConstraints(minHeight: minHeight),
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
  decoration: BoxDecoration(
    color: SuwarColors.paper,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: SuwarColors.line),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  ),
);
Widget audioDetailNotice(String text, double height) => Container(
  constraints: BoxConstraints(minHeight: height),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: SuwarColors.sage,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: SuwarColors.green),
    ),
  ),
);
Widget audioDetailLine(
  BuildContext context,
  String text,
  double height, {
  required double size,
  bool display = false,
  bool centered = false,
}) => ConstrainedBox(
  constraints: BoxConstraints(minHeight: height),
  child: Align(
    alignment: centered ? Alignment.center : AlignmentDirectional.centerStart,
    child: Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: display
          ? headingStyle(context, size: size)
          : TextStyle(fontSize: size, color: SuwarColors.muted, height: 1.65),
    ),
  ),
);
