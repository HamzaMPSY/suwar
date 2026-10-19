import 'package:flutter/material.dart';
import '../../core/theme.dart';

class MemorySectionTabs extends StatelessWidget {
  const MemorySectionTabs({
    super.key,
    required this.passages,
    required this.onChanged,
  });
  final bool passages;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SuwarColors.sage,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        _tab('السور', !passages, () => onChanged(false)),
        _tab('مقاطعي', passages, () => onChanged(true)),
      ],
    ),
  );
  Widget _tab(String label, bool selected, VoidCallback action) => Expanded(
    child: Semantics(
      label: label,
      selected: selected,
      button: true,
      onTap: action,
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: action,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? SuwarColors.paper : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? SuwarColors.green : SuwarColors.muted,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PassageRow extends StatelessWidget {
  const PassageRow({
    super.key,
    required this.title,
    required this.reference,
    required this.status,
    required this.onTap,
    this.memorized = false,
    this.included = false,
  });
  final String title, reference, status;
  final VoidCallback onTap;
  final bool memorized, included;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    container: true,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: SuwarColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: headingStyle(context, size: 25)),
                  Text(
                    reference,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SuwarColors.muted,
                    ),
                  ),
                  Row(
                    children: [
                      if (memorized) ...[
                        const Icon(
                          Icons.check,
                          size: 18,
                          color: SuwarColors.green,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color: included
                                ? SuwarColors.goldText
                                : SuwarColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            const Icon(
              Icons.chevron_left,
              textDirection: TextDirection.ltr,
              size: 22,
              color: SuwarColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}
