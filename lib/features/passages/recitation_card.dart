import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'recitation_target.dart';

class RecitationCard extends StatelessWidget {
  const RecitationCard({super.key, required this.target, required this.onTap});
  final RecitationTarget target;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: SuwarColors.paper,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 158),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SuwarColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              target.isPassage ? 'مقطع محفوظ' : 'سورة كاملة',
              style: const TextStyle(fontSize: 12, color: SuwarColors.goldText),
            ),
            const SizedBox(height: 8),
            Text(target.name, style: headingStyle(context, size: 29)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Text(
                    target.metadata,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SuwarColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_left,
                  textDirection: TextDirection.ltr,
                  size: 20,
                  color: SuwarColors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
