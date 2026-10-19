import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/widgets.dart';
import '../memory/learning_screen.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.state,
    this.selectionMode = false,
  });
  final AppState state;
  final bool selectionMode;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int filter = 0;
  String query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final app = widget.state;
      final key = normalizeSearch(query);
      final surahs = app.repository.surahs
          .where(
            (s) =>
                (filter == 0 ||
                    filter == 1 && app.memorizedIds.contains(s.number) ||
                    filter == 2 && app.learningSurahId == s.number) &&
                (key.isEmpty ||
                    normalizeSearch(s.name).contains(key) ||
                    normalizeSearch(s.nameEnglish).contains(key) ||
                    '${s.number}' == key),
          )
          .toList();
      return CustomScrollView(
        key: PageStorageKey(
          widget.selectionMode ? 'selection-library' : 'quran-library',
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                ScreenHeading(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 21, 24, 17),
                  title: widget.selectionMode
                      ? 'ماذا تحفظ من القرآن؟'
                      : 'القرآن الكريم',
                  subtitle: widget.selectionMode
                      ? 'اختر السور التي تحفظها كاملة.'
                      : '114 سورة · رواية ورش عن نافع',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        container: true,
                        child: TextField(
                          style: const TextStyle(fontSize: 14, height: 1.65),
                          readOnly: !widget.selectionMode,
                          onTap: widget.selectionMode
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SearchScreen(state: app),
                                  ),
                                ),
                          onChanged: (value) => setState(() => query = value),
                          decoration: const InputDecoration(
                            hintText: 'ابحث عن سورة',
                            constraints: BoxConstraints(minHeight: 54),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(14),
                              child: SuwarIcon(SuwarSymbol.search),
                            ),
                          ),
                        ),
                      ),
                      if (!widget.selectionMode) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (index, label, width) in [
                              (0, 'الكل', 88.0),
                              (1, 'محفوظاتي', 112.0),
                              (2, 'أحفظها الآن', 118.0),
                            ])
                              SuwarChoicePill(
                                label: label,
                                selected: filter == index,
                                width: width,
                                onTap: () => setState(() => filter = index),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 13),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (surahs.isEmpty)
            SliverToBoxAdapter(
              child: EmptyMessage(
                icon: Icons.menu_book_outlined,
                title: filter == 2
                    ? 'اختر سورة لتبدأ حفظها'
                    : 'لا توجد سور هنا بعد',
                message: filter == 2
                    ? 'افتح سورة ثم اختر التدريب على الحفظ لتتابعها هنا.'
                    : 'حدّد السور التي تحفظها كاملة لتظهر في محفوظاتك.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              sliver: SliverList.builder(
                itemCount: surahs.length,
                itemBuilder: (context, index) {
                  final s = surahs[index];
                  final known = app.memorizedIds.contains(s.number);
                  return Column(
                    children: [
                      SurahTile(
                        surah: s,
                        memorized: known,
                        trailing: widget.selectionMode
                            ? Checkbox(
                                value: known,
                                semanticLabel: 'أحفظ سورة ${s.name}',
                                onChanged: (_) => app.toggleMemorized(s.number),
                              )
                            : null,
                        onTap: () {
                          if (widget.selectionMode) {
                            app.toggleMemorized(s.number);
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => filter == 2
                                  ? LearningScreen(state: app, surah: s)
                                  : ReaderScreen(state: app, surah: s),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 3),
                    ],
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}
