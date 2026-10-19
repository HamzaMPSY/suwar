import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state, this.initialQuery = ''});
  final AppState state;
  final String initialQuery;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final controller = TextEditingController(text: widget.initialQuery);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: SuwarBottomNavigation(
      selectedIndex: 1,
      onSelected: (i) {
        final scope = SuwarNavigationScope.maybeOf(context);
        if (scope != null) {
          scope.selectTab(i);
        } else {
          Navigator.of(context).pop();
        }
      },
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final app = widget.state;
          final query = normalizeSearch(controller.text);
          final matches = query.isEmpty
              ? <Surah>[]
              : app.repository.surahs
                    .where(
                      (s) =>
                          normalizeSearch(s.name).contains(query) ||
                          normalizeSearch(s.nameEnglish).contains(query) ||
                          '${s.number}' == query,
                    )
                    .toList();
          return ListView(
            children: [
              ScreenHeading(
                title: 'البحث في السور',
                subtitle: 'ابحث بالاسم أو رقم السورة.',
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Semantics(
                      container: true,
                      child: TextField(
                        controller: controller,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'ابحث باسم السورة أو رقمها',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(14),
                            child: SuwarIcon(SuwarSymbol.search),
                          ),
                          suffixIcon: controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح البحث',
                                  onPressed: () => setState(controller.clear),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      query.isEmpty
                          ? 'اكتب اسم السورة أو رقمها'
                          : matches.length == 1
                          ? 'نتيجة واحدة'
                          : '${displayNumber(matches.length)} نتائج',
                      style: const TextStyle(
                        fontSize: 13,
                        color: SuwarColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final surah in matches) ...[
                      SurahTile(
                        surah: surah,
                        memorized: app.memorizedIds.contains(surah.number),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ReaderScreen(state: app, surah: surah),
                          ),
                        ),
                      ),
                      const Divider(),
                    ],
                    if (query.isNotEmpty && matches.isEmpty)
                      const EmptyMessage(
                        icon: Icons.search_off,
                        title: 'لا توجد نتائج',
                        message: 'جرّب اسمًا آخر أو رقم السورة.',
                      ),
                    if (matches.isNotEmpty &&
                        matches.every(
                          (s) => app.memorizedIds.contains(s.number),
                        )) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'من محفوظاتك',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: SuwarColors.green,
                        ),
                      ),
                    ],
                    const SizedBox(height: 140),
                    PrimaryAction(
                      label: 'عرض كل السور',
                      secondary: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 32),
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
