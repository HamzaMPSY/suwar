import '../passages/passage_scope.dart';
import '../passages/passage_editor_screen.dart';
import '../passages/passage_detail_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../audio/audio_controls.dart';
import '../audio/audio_scope.dart';
import '../audio/audio_download_action.dart';
import '../memory/learning_screen.dart';
import '../reading/bookmarks_screen.dart';
import '../reading/reading_scope.dart';
import '../reading/reading_state.dart';
import 'reader_ayah.dart';
import 'reader_controls.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.state,
    required this.surah,
    this.initialAyahNumber,
  });
  final AppState state;
  final Surah surah;
  final int? initialAyahNumber;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _anchorKey = GlobalKey();
  int _anchorIndex = 0;
  bool _initialized = false;
  bool _invalidTarget = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final saved = ReadingScope.maybeOf(context)?.snapshot.position;
    final target =
        widget.initialAyahNumber ??
        (saved?.surahId == widget.surah.number ? saved?.ayahNumber : null);
    if (target != null) {
      final index = widget.surah.ayahs.indexWhere(
        (ayah) => ayah.number == target,
      );
      _invalidTarget = index < 0;
      _anchorIndex = index < 0 ? 0 : index;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.state.setLastRead(widget.surah.number, _anchorIndex);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showControls() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('أدوات القراءة', style: headingStyle(context, size: 28)),
                ReaderControls(state: widget.state, surah: widget.surah),
                ListTile(
                  title: const Text('بداية السورة'),
                  leading: const Icon(Icons.vertical_align_top),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _anchorIndex = 0);
                  },
                ),
                ListTile(
                  title: const Text('تدرّب على الحفظ'),
                  leading: const SuwarIcon(SuwarSymbol.learning),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LearningScreen(
                          state: widget.state,
                          surah: widget.surah,
                        ),
                      ),
                    );
                  },
                ),
                if (ReadingScope.maybeOf(this.context) != null)
                  ListTile(
                    title: const Text('علاماتي وموضعي'),
                    leading: const Icon(Icons.bookmarks_outlined),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(this.context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BookmarksScreen(app: widget.state),
                        ),
                      );
                    },
                  ),
                if (AudioScope.maybeOf(this.context) case final audio?) ...[
                  AudioDownloadAction(
                    library: audio,
                    recording: audio.catalog.recording(widget.surah.number),
                  ),
                  const Text(
                    'محمود خليل الحصري · ورش عن نافع\nمصدر التلاوة والتوقيت: MP3Quran',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: SuwarColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reading = ReadingScope.maybeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, ?reading]),
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  ScreenHeading(
                    title: 'سورة ${widget.surah.name}',
                    subtitle:
                        'رواية ورش عن نافع · ${displayNumber(widget.surah.verseCount)} آيات',
                    onBack: () => Navigator.of(context).maybePop(),
                    trailing: IconButton(
                      tooltip: 'أدوات القراءة',
                      onPressed: _showControls,
                      icon: const SuwarIcon(SuwarSymbol.settings),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      key: ValueKey('reader-list-$_anchorIndex'),
                      controller: _scroll,
                      // Earlier verses grow upward from the actual target, without pixel estimates.
                      center: _anchorIndex == 0 ? null : _anchorKey,
                      slivers: [
                        SliverToBoxAdapter(child: _header(reading)),
                        if (_anchorIndex > 0)
                          SliverList.builder(
                            itemCount: _anchorIndex,
                            itemBuilder: (context, index) =>
                                _ayah(_anchorIndex - 1 - index, reading),
                          ),
                        SliverList.builder(
                          key: _anchorKey,
                          itemCount: widget.surah.verseCount - _anchorIndex,
                          itemBuilder: (context, index) =>
                              _ayah(_anchorIndex + index, reading),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: ReaderControls(
                              state: widget.state,
                              surah: widget.surah,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ReadingState? reading) => Column(
    children: [
      Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(height: 58, width: double.infinity),
          const Rosette(size: 46),
          PositionedDirectional(
            end: 16,
            child: AudioControls(surah: widget.surah, compact: true),
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        child: Divider(height: 1),
      ),
      if (_invalidTarget)
        const Text(
          'الآية المطلوبة غير متاحة. عُرضت بداية السورة.',
          textAlign: TextAlign.center,
        ),
      if (reading?.error != null)
        Text(reading!.error!, textAlign: TextAlign.center),
      const SizedBox(height: 12),
    ],
  );

  Widget _ayah(int index, ReadingState? reading) {
    final ayah = widget.surah.ayahs[index];
    return ReaderAyah(
      key: ValueKey('reader-ayah-${widget.surah.number}-${ayah.number}'),
      surahId: widget.surah.number,
      ayah: ayah,
      fontSize: widget.state.quranFontSize,
      onCreatePassage: PassageScope.maybeOf(context) == null
          ? null
          : () async {
              final result = await openPassageEditor(
                context,
                app: widget.state,
                surahId: widget.surah.number,
                startAyah: ayah.number,
                endAyah: ayah.number,
              );
              if (result != null && mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PassageDetailScreen(
                      app: widget.state,
                      passageId: result.id,
                      fromReader: true,
                    ),
                  ),
                );
              }
            },
      reading: reading,
      highlighted: _anchorIndex > 0 && index == _anchorIndex,
    );
  }
}
