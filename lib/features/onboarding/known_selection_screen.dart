import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/quran_repository.dart';
import '../prayer/prayer_runtime.dart';
import 'onboarding_prayer_setup.dart';
import 'onboarding_selection_view.dart';

class KnownSelectionScreen extends StatefulWidget {
  const KnownSelectionScreen({
    super.key,
    required this.state,
    this.onboarding = false,
    this.prayer,
  });
  final AppState state;
  final bool onboarding;
  final PrayerRuntime? prayer;
  @override
  State<KnownSelectionScreen> createState() => _KnownSelectionScreenState();
}

class _KnownSelectionScreenState extends State<KnownSelectionScreen> {
  late Set<int> selected = {...widget.state.memorizedIds};
  String query = '';
  bool saving = false;
  Future<void> save() async {
    setState(() => saving = true);
    await widget.state.setMemorized(selected);
    if (widget.state.storageError == null &&
        widget.onboarding &&
        widget.prayer == null) {
      await widget.state.completeOnboarding();
    }
    if (!mounted) return;
    setState(() => saving = false);
    if (widget.state.storageError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.state.storageError!)));
      return;
    }
    if (widget.onboarding && widget.prayer != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OnboardingPrayerSetup(
            state: widget.state,
            prayer: widget.prayer!,
          ),
        ),
      );
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onboarding) {
      return OnboardingSelectionView(
        app: widget.state,
        selected: selected,
        saving: saving,
        onToggle: (number) => setState(() {
          if (!selected.add(number)) selected.remove(number);
        }),
        onContinue: save,
        onSkip: save,
      );
    }
    final queryKey = normalizeSearch(query);
    final filtered = widget.state.repository.surahs
        .where(
          (s) =>
              normalizeSearch(s.name).contains(queryKey) ||
              s.number.toString() == queryKey,
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeading(
                title: 'ماذا تحفظ من القرآن؟',
                subtitle: 'اختر السور التي تحفظها كاملة. يمكنك تعديلها لاحقًا.',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    labelText: 'ابحث عن سورة',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'لا توجد سورة بهذا الاسم',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final surah = filtered[index];
                    void toggle() => setState(() {
                      if (!selected.add(surah.number)) {
                        selected.remove(surah.number);
                      }
                    });
                    return Column(
                      children: [
                        SurahTile(
                          surah: surah,
                          onTap: toggle,
                          trailing: Checkbox(
                            value: selected.contains(surah.number),
                            onChanged: (_) => toggle(),
                            semanticLabel: 'أحفظ سورة ${surah.name}',
                          ),
                        ),
                        const Divider(),
                      ],
                    );
                  }, childCount: filtered.length),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected.isEmpty
                    ? 'لم تحدد أي سورة بعد'
                    : 'عدد السور المختارة: ${displayNumber(selected.length)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SuwarColors.green),
              ),
              const SizedBox(height: 10),
              PrimaryAction(
                label: saving
                    ? 'جارٍ الحفظ…'
                    : widget.onboarding
                    ? 'متابعة'
                    : 'حفظ اختياراتي',
                onPressed: saving ? null : save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
