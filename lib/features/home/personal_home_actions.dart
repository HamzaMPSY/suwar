import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../quran/reader_screen.dart';
import '../reading/bookmarks_screen.dart';
import '../reading/reading_scope.dart';
import '../revision/revision_scope.dart';
import '../revision/revision_screen.dart';

class PersonalHomeActions extends StatelessWidget {
  const PersonalHomeActions({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final reading = ReadingScope.maybeOf(context);
    final revision = RevisionScope.maybeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app, ?reading, ?revision]),
      builder: (context, _) {
        final position = reading?.snapshot.position;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (position != null) ...[
              _entry(
                context,
                title: 'موضع القراءة',
                subtitle:
                    'سورة ${app.repository.surah(position.surahId).name} · الآية ${displayNumber(position.ayahNumber)}',
                action: 'متابعة القراءة',
                key: const ValueKey('home-reading-position'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReaderScreen(
                      state: app,
                      surah: app.repository.surah(position.surahId),
                      initialAyahNumber: position.ayahNumber,
                    ),
                  ),
                ),
              ),
            ] else if (reading == null && app.lastReadSurahId != null)
              _entry(
                context,
                title: 'آخر سورة قرأتها',
                subtitle: app.repository.surah(app.lastReadSurahId!).name,
                action: 'متابعة القراءة',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReaderScreen(
                      state: app,
                      surah: app.repository.surah(app.lastReadSurahId!),
                    ),
                  ),
                ),
              ),
            if (reading != null)
              _entry(
                context,
                title: 'علاماتي وموضعي',
                subtitle: 'عد إلى الآية التي اخترتها',
                action: 'علاماتي وموضعي',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookmarksScreen(app: app),
                  ),
                ),
              ),
            if (revision != null)
              _entry(
                context,
                title: 'مراجعة اليوم',
                subtitle: revision.activeIds.isEmpty
                    ? 'اختر السور التي تريد مراجعتها اليوم.'
                    : 'راجعت ${displayNumber(revision.completedToday.length)} من ${displayNumber(revision.activeIds.length)} سور',
                subtitleKey: const ValueKey('home-revision-count'),
                action: 'فتح مراجعتي اليوم',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RevisionScreen(state: revision),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _entry(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onTap,
    Key? key,
    Key? subtitleKey,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      Semantics(
        container: true,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: headingStyle(context, size: 20)),
                      Text(
                        subtitle,
                        key: subtitleKey,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SuwarColors.muted,
                        ),
                      ),
                      if (action != title)
                        Text(
                          action,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: SuwarColors.green,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SuwarIcon(SuwarSymbol.back, size: 20),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
