import 'package:flutter/material.dart';
import '../../core/quran_presentation.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_controls.dart';
import '../audio/audio_scope.dart';
import 'learning_completion.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key, required this.state, required this.surah});
  final AppState state;
  final Surah surah;
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  late int _index;
  bool _hidden = false;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _index = widget.state.learningSurahId == widget.surah.number
        ? widget.state.learningAyahIndex.clamp(0, widget.surah.verseCount - 1)
        : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.state.setLearningProgress(widget.surah.number, _index);
      }
    });
  }

  Future<void> _advance() async {
    await AudioScope.maybeOf(context)?.player.stop();
    if (!mounted) return;
    if (_index + 1 == widget.surah.verseCount) {
      setState(() {
        _complete = true;
        _hidden = false;
      });
    } else {
      setState(() {
        _index++;
        _hidden = false;
      });
      await widget.state.setLearningProgress(widget.surah.number, _index);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ScreenHeading(
                    title: _complete
                        ? 'أتممت جلسة الحفظ'
                        : 'سورة ${widget.surah.name}',
                    subtitle: _complete
                        ? 'سورة ${widget.surah.name} · ${displayNumber(widget.surah.verseCount)} آيات'
                        : 'الآية ${displayNumber(_index + 1)} من ${displayNumber(widget.surah.verseCount)} · رواية ورش',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    child: _complete
                        ? LearningCompletion(
                            state: widget.state,
                            surah: widget.surah,
                            onReview: () {
                              setState(() {
                                _complete = false;
                                _index = 0;
                                _hidden = false;
                              });
                              widget.state.setLearningProgress(
                                widget.surah.number,
                                0,
                              );
                            },
                          )
                        : _practice(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  TextStyle get _verseStyle => TextStyle(
    fontFamily: 'Warsh',
    fontSize: widget.state.quranFontSize + 1,
    height: 1.8,
    color: SuwarColors.green,
  );

  Widget _practice(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        label: 'تقدّم الحفظ',
        value: '${_index + 1} من ${widget.surah.verseCount}',
        child: Row(
          spacing: 12,
          children: [
            for (var part = 0; part < 3; part++)
              Expanded(
                child: LinearProgressIndicator(
                  value: (((_index + 1) / widget.surah.verseCount) * 3 - part)
                      .clamp(0.0, 1.0),
                  color: SuwarColors.green,
                  backgroundColor: SuwarColors.line,
                  minHeight: 4,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Text(
        _hidden ? 'سمّع لنفسك' : 'استمع، ثم كرّر',
        textAlign: TextAlign.center,
        style: headingStyle(context, size: 26),
      ),
      SizedBox(height: _hidden ? 69 : 49),
      if (!_hidden) ...[
        Container(
          constraints: const BoxConstraints(minHeight: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SelectableText.rich(
            QuranPresentation(widget.surah.ayahs[_index]).span(_verseStyle),
            semanticsLabel: QuranPresentation(
              widget.surah.ayahs[_index],
            ).accessibleText,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: _verseStyle,
          ),
        ),
        const SizedBox(height: 32),
        AudioControls(
          surah: widget.surah,
          ayahNumber: widget.surah.ayahs[_index].number,
        ),
        const SizedBox(height: 36),
        PrimaryAction(
          label: 'أخفِ الآية واختبر حفظك',
          onPressed: () {
            AudioScope.maybeOf(context)?.player.stop();
            setState(() => _hidden = true);
          },
        ),
      ] else ...[
        const Center(
          child: SuwarIcon(
            SuwarSymbol.eye,
            size: 42,
            color: SuwarColors.goldText,
          ),
        ),
        const SizedBox(height: 31),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Text(
            'النص مخفي الآن',
            textAlign: TextAlign.center,
            style: headingStyle(context, size: 21),
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: const Text(
            'خذ وقتك، ثم تحقّق من حفظك.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.7),
          ),
        ),
        const SizedBox(height: 68),
        PrimaryAction(
          label: 'إظهار الآية',
          secondary: true,
          onPressed: () => setState(() => _hidden = false),
        ),
        const SizedBox(height: 22),
        PrimaryAction(label: 'أتقنت هذه الآية', onPressed: _advance),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () => setState(() => _hidden = false),
          child: const Text('أحتاج إلى التكرار'),
        ),
      ],
    ],
  );
}
