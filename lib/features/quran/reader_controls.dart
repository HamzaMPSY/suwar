import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/widgets.dart';
import '../../core/theme.dart';

class ReaderControls extends StatelessWidget {
  const ReaderControls({super.key, required this.state, required this.surah});
  final AppState state;
  final Surah surah;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'حجم الخط',
                  style: TextStyle(fontSize: 13, color: SuwarColors.muted),
                ),
              ),
              IconButton(
                tooltip: 'تصغير الخط',
                onPressed: state.quranFontSize <= 22
                    ? null
                    : () => state.setQuranFontSize(state.quranFontSize - 2),
                icon: const Icon(Icons.text_decrease_rounded),
              ),
              IconButton(
                tooltip: 'تكبير الخط',
                onPressed: state.quranFontSize >= 42
                    ? null
                    : () => state.setQuranFontSize(state.quranFontSize + 2),
                icon: const Icon(Icons.text_increase_rounded),
              ),
            ],
          ),
          PrimaryAction(
            label: state.memorizedIds.contains(surah.number)
                ? 'محفوظة ✓'
                : 'حفظت هذه السورة',
            secondary: true,
            onPressed: () => state.toggleMemorized(surah.number),
          ),
          const SizedBox(height: 8),
          const Text(
            'اضغط لتعديل حالة الحفظ',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: SuwarColors.muted),
          ),
        ],
      ),
    ),
  );
}
