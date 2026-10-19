import 'package:flutter/material.dart';
import '../../core/theme.dart';

class OnboardingSteps extends StatelessWidget {
  const OnboardingSteps({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: i <= step ? SuwarColors.green : SuwarColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    ],
  );
}
