import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class LearningCompletion extends StatelessWidget {
  const LearningCompletion({
    super.key,
    required this.state,
    required this.surah,
    required this.onReview,
  });
  final AppState state;
  final Surah surah;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 28),
      const Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            GeometricOrnament(size: 154, color: Color(0xFFD9D4B8)),
            CircleAvatar(
              radius: 36,
              backgroundColor: SuwarColors.green,
              child: SuwarIcon(
                SuwarSymbol.check,
                size: 34,
                color: SuwarColors.paper,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Text(
          'خطوة جميلة في رحلتك',
          style: headingStyle(context, size: 29),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 19),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: const Text(
          'هل تستطيع تسميع السورة كاملة؟',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, height: 1.7),
        ),
      ),
      const SizedBox(height: 82),
      PrimaryAction(
        label: 'نعم، أضفها إلى محفوظاتي',
        onPressed: () async {
          await state.finishLearning(surah.number);
          if (!context.mounted) return;
          final error = state.storageError;
          if (error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error)));
            return;
          }
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
      const SizedBox(height: 16),
      PrimaryAction(
        label: 'أحتاج إلى مراجعة',
        secondary: true,
        onPressed: onReview,
      ),
      const SizedBox(height: 26),
      const Text(
        'يمكنك تغيير حالة الحفظ في أي وقت.',
        textAlign: TextAlign.center,
        style: TextStyle(color: SuwarColors.muted, fontSize: 13),
      ),
    ],
  );
}
