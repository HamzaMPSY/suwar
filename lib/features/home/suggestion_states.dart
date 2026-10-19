import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../onboarding/onboarding_screen.dart';
import '../quran/library_screen.dart';
import '../quran/reader_screen.dart';

class EmptySuggestionsScreen extends StatelessWidget {
  const EmptySuggestionsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: SuwarBottomNavigation(
      selectedIndex: 0,
      onSelected: (index) {
        final scope = SuwarNavigationScope.maybeOf(context);
        if (scope != null) {
          scope.selectTab(index);
        } else {
          Navigator.of(context).pop();
        }
      },
    ),
    body: SafeArea(
      child: EmptySuggestionsContent(
        state: state,
        onBack: () => Navigator.of(context).pop(),
        onBrowse: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: SafeArea(child: LibraryScreen(state: state)),
            ),
          ),
        ),
      ),
    ),
  );
}

class EmptySuggestionsContent extends StatelessWidget {
  const EmptySuggestionsContent({
    super.key,
    required this.state,
    required this.onBrowse,
    this.onBack,
    this.footer,
    this.trailing,
  });
  final AppState state;
  final VoidCallback onBrowse;
  final VoidCallback? onBack;
  final Widget? footer;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      ScreenHeading(
        title: 'لنبدأ بما تحفظه',
        subtitle: 'الاقتراحات تأتي من محفوظاتك فقط.',
        onBack: onBack,
        trailing: trailing,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 58),
            const Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Rosette(size: 100),
                    SuwarIcon(SuwarSymbol.book, size: 48),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 47),
            Text(
              'أضف أول سورة تحفظها',
              textAlign: TextAlign.center,
              style: headingStyle(context, size: 29),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: const Center(
                child: Text(
                  'حدّد سورتين على الأقل لتصلك\nاقتراحات متنوعة مع تذكير الصلاة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: SuwarColors.muted),
                ),
              ),
            ),
            const SizedBox(height: 38),
            PrimaryAction(
              label: 'تحديد السور التي أحفظها',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => KnownSelectionScreen(state: state),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryAction(
              label: 'أريد حفظ سورة جديدة',
              secondary: true,
              onPressed: onBrowse,
            ),
            if (footer != null) ...[const SizedBox(height: 56), footer!],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ],
  );
}

class SingleSuggestionScreen extends StatelessWidget {
  const SingleSuggestionScreen({super.key, required this.state, this.subtitle});
  final AppState state;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final known = state.repository.surahs
              .where((s) => state.memorizedIds.contains(s.number))
              .toList();
          if (known.isEmpty) {
            return EmptySuggestionsContent(
              state: state,
              onBack: () => Navigator.of(context).pop(),
              onBrowse: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: SafeArea(child: LibraryScreen(state: state)),
                  ),
                ),
              ),
            );
          }
          final surah = known.first;
          return ListView(
            children: [
              ScreenHeading(
                title: 'محفوظاتك تبدأ بسورة',
                subtitle: subtitle ?? 'اقتراح من حفظك',
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 76),
                    Text(
                      surah.name,
                      textAlign: TextAlign.center,
                      style: headingStyle(context, size: 43),
                    ),
                    const SizedBox(height: 35),
                    const Text(
                      'لديك سورة واحدة محفوظة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17),
                    ),
                    const SizedBox(height: 34),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 84),
                      child: const Center(
                        child: Text(
                          'سنقترح سورة ثانية عندما تضيفها\nإلى محفوظاتك.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 74),
                    PrimaryAction(
                      label: 'مراجعة سورة ${surah.name}',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ReaderScreen(state: state, surah: surah),
                        ),
                      ),
                    ),
                    const SizedBox(height: 19),
                    PrimaryAction(
                      label: 'إضافة سورة أخرى',
                      secondary: true,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => KnownSelectionScreen(state: state),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
