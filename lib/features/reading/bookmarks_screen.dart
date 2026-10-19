import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../quran/reader_screen.dart';
import 'reading_scope.dart';
import 'reading_state.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key, required this.app});
  final AppState app;
  void _open(BuildContext context, ReadingPosition p) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            state: app,
            surah: app.repository.surah(p.surahId),
            initialAyahNumber: p.ayahNumber,
          ),
        ),
      );
  Widget _entry(
    BuildContext context,
    ReadingState state,
    ReadingPosition p, {
    required bool bookmark,
  }) => Column(
    key: ValueKey(
      '${bookmark ? 'bookmark' : 'resume'}-${p.surahId}-${p.ayahNumber}',
    ),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 55),
        child: Text(
          'سورة ${app.repository.surah(p.surahId).name} · الآية ${displayNumber(p.ayahNumber)}',
          style: headingStyle(context, size: 26),
        ),
      ),
      const SizedBox(height: 35),
      PrimaryAction(
        label: bookmark ? 'فتح الآية' : 'متابعة القراءة',
        onPressed: () => _open(context, p),
      ),
      if (bookmark) ...[
        const SizedBox(height: 24),
        PrimaryAction(
          label: 'إزالة العلامة',
          secondary: true,
          backgroundColor: SuwarColors.paper,
          onPressed: () => state.toggleBookmark(p),
        ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) {
    final state = ReadingScope.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: state == null
            ? const Center(
                child: Text('علامات القراءة غير متاحة في هذه الجلسة.'),
              )
            : ListenableBuilder(
                listenable: state,
                builder: (context, _) {
                  final position = state.snapshot.position;
                  final bookmarks = state.snapshot.bookmarks;
                  final separateResume =
                      position != null && !bookmarks.contains(position);
                  final empty = position == null && bookmarks.isEmpty;
                  return ListView(
                    children: [
                      ScreenHeading(
                        title: 'علاماتي وموضعي',
                        subtitle: 'عد إلى الآية التي اخترتها',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 43, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.error != null)
                              DesignNotice(message: state.error!),
                            if (empty)
                              const EmptyMessage(
                                icon: Icons.bookmark_border,
                                title: 'لم تحفظ علامات بعد',
                                message:
                                    'افتح سورة، ثم اختر علامة الآية التي تريد العودة إليها.',
                              ),
                            if (separateResume) ...[
                              _entry(context, state, position, bookmark: false),
                              if (bookmarks.isNotEmpty) ...[
                                const SizedBox(height: 36),
                                const Divider(),
                                const SizedBox(height: 36),
                              ],
                            ],
                            for (var i = 0; i < bookmarks.length; i++) ...[
                              if (i > 0) ...[
                                const SizedBox(height: 36),
                                const Divider(),
                                const SizedBox(height: 36),
                              ],
                              _entry(
                                context,
                                state,
                                bookmarks[i],
                                bookmark: true,
                              ),
                            ],
                            if (!empty) ...[
                              const SizedBox(height: 84),
                              const DesignNotice(
                                minHeight: 130,
                                message:
                                    'تُحفظ علاماتك على هذا الجهاز. إزالة العلامة لا تغيّر موضع المتابعة أو محفوظاتك.',
                              ),
                            ],
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
}
