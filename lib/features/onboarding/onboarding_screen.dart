import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../prayer/prayer_runtime.dart';
import 'known_selection_screen.dart';
import 'welcome_art.dart';
export 'known_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.state, this.prayer});
  final AppState state;
  final PrayerRuntime? prayer;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      backgroundColor: SuwarColors.green,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(766, constraints.maxHeight),
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const WelcomeArt(),
                    SizedBox(
                      height: 112 * scale,
                      child: Center(
                        child: Text(
                          'سُوَر',
                          style: headingStyle(
                            context,
                            size: 72,
                            color: SuwarColors.ivory,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 40 * scale),
                        child: const Center(
                          child: Text(
                            'احفظ، وراجع، واقرأ في صلاتك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: SuwarColors.ivory,
                              fontSize: 19,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 32 * scale),
                        child: const Center(
                          child: Text(
                            'رفيقك مع القرآن، خطوة بخطوة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFC7D5C8),
                              fontSize: 14,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: SuwarColors.paper,
                            foregroundColor: SuwarColors.green,
                            minimumSize: const Size(double.infinity, 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => KnownSelectionScreen(
                                state: state,
                                onboarding: true,
                                prayer: prayer,
                              ),
                            ),
                          ),
                          child: const Text(
                            'ابدأ رحلتك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 19),
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 32 * scale),
                      child: const Center(
                        child: Text(
                          'بالعربية · رواية ورش عن نافع',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD1D7C8),
                            fontSize: 13,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 29),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
