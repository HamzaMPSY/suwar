import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../quran/reader_screen.dart';
import 'audio_download_action.dart';
import 'audio_download_detail_screen.dart';
import 'audio_library.dart';
import 'audio_scope.dart';

class AudioDownloadsScreen extends StatefulWidget {
  const AudioDownloadsScreen({super.key, required this.app});
  final AppState app;
  @override
  State<AudioDownloadsScreen> createState() => _AudioDownloadsScreenState();
}

class _AudioDownloadsScreenState extends State<AudioDownloadsScreen> {
  String query = '';
  bool downloadedOnly = false;
  @override
  Widget build(BuildContext context) {
    final library = AudioScope.maybeOf(context);
    if (library == null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              ScreenHeading(
                title: 'التحميل دون إنترنت',
                onBack: () => Navigator.of(context).pop(),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('التلاوات غير متاحة الآن.'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: library.store,
          builder: (context, _) {
            final search = normalizeSearch(query);
            final surahs = widget.app.repository.surahs.where((surah) {
              final matches =
                  search.isEmpty ||
                  normalizeSearch(surah.name).contains(search) ||
                  normalizeSearch(surah.nameEnglish).contains(search) ||
                  '${surah.number}' == search;
              return matches &&
                  (!downloadedOnly ||
                      library.store
                          .entry(library.catalog.recording(surah.number))
                          .ready);
            }).toList();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ScreenHeading(
                        title: 'التحميل دون إنترنت',
                        subtitle: 'اقرأ دون اتصال، وحمّل التلاوة عند الحاجة.',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'القرآن الكريم',
                              style: headingStyle(context, size: 28),
                            ),
                            const Text(
                              'النص متاح على جهازك',
                              style: TextStyle(
                                fontSize: 15,
                                color: SuwarColors.green,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 24),
                            const Text(
                              'الحصري · ورش عن نافع · MP3Quran',
                              style: TextStyle(
                                fontSize: 13,
                                color: SuwarColors.muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => query = value),
                              decoration: const InputDecoration(
                                labelText: 'ابحث باسم السورة أو رقمها',
                                prefixIcon: Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SuwarIcon(SuwarSymbol.search),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                SuwarChoicePill(
                                  label: 'الكل',
                                  selected: !downloadedOnly,
                                  onTap: () =>
                                      setState(() => downloadedOnly = false),
                                ),
                                SuwarChoicePill(
                                  label: 'المحمّلة',
                                  selected: downloadedOnly,
                                  onTap: () =>
                                      setState(() => downloadedOnly = true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (!library.store.supported)
                              const Text(
                                'الاستماع متاح هنا. التنزيل دون إنترنت متاح في نسخة الهاتف.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: SuwarColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (surahs.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد سور هنا. جرّب بحثًا آخر أو اعرض الكل.',
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverList.builder(
                    itemCount: surahs.length,
                    itemBuilder: (context, index) =>
                        _row(context, library, surahs[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AudioLibrary library, Surah surah) {
    final recording = library.catalog.recording(surah.number);
    final entry = library.store.entry(recording);
    void details() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AudioDownloadDetailScreen(app: widget.app, surah: surah),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurahTile(surah: surah, onTap: details),
        AudioDownloadAction(library: library, recording: recording),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton(onPressed: details, child: const Text('تفاصيل التلاوة')),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReaderScreen(state: widget.app, surah: surah),
                ),
              ),
              child: const Text('قراءة السورة'),
            ),
          ],
        ),
        if (entry.ready)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف التلاوة من الجهاز'),
            onPressed: () async {
              if (library.player.recordingId == recording.id) {
                await library.player.stop();
              }
              await library.store.remove(recording);
            },
          ),
        const SizedBox(height: 12),
        const Divider(),
      ],
    );
  }
}
