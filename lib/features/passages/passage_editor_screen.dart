import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'passage_models.dart';
import 'passage_scope.dart';
import 'passage_read_screen.dart';

Future<SavedPassage?> openPassageEditor(
  BuildContext context, {
  required AppState app,
  SavedPassage? passage,
  int? surahId,
  int? startAyah,
  int? endAyah,
  String? initialName,
}) => Navigator.of(context).push<SavedPassage>(
  MaterialPageRoute(
    builder: (_) => PassageEditorScreen(
      app: app,
      passage: passage,
      surahId: surahId,
      startAyah: startAyah,
      endAyah: endAyah,
      initialName: initialName,
    ),
  ),
);

class PassageEditorScreen extends StatefulWidget {
  const PassageEditorScreen({
    super.key,
    required this.app,
    this.passage,
    this.surahId,
    this.startAyah,
    this.endAyah,
    this.initialName,
  });
  final AppState app;
  final SavedPassage? passage;
  final int? surahId, startAyah, endAyah;
  final String? initialName;
  @override
  State<PassageEditorScreen> createState() => _PassageEditorScreenState();
}

class _PassageEditorScreenState extends State<PassageEditorScreen> {
  late final TextEditingController name;
  late final TextEditingController start;
  late final TextEditingController end;
  late int surahId;
  String? error;
  @override
  void initState() {
    super.initState();
    final range = widget.passage?.range;
    surahId = range?.surahId ?? widget.surahId ?? 2;
    name = TextEditingController(
      text: widget.initialName ?? widget.passage?.name ?? '',
    );
    start = TextEditingController(
      text: displayNumber(range?.startAyah ?? widget.startAyah ?? 1),
    );
    end = TextEditingController(
      text: displayNumber(range?.endAyah ?? widget.endAyah ?? 1),
    );
  }

  @override
  void dispose() {
    name.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }

  Future<void> _chooseSurah() async {
    final selected = await Navigator.of(context).push<Surah>(
      MaterialPageRoute(
        builder: (_) => _PassageSurahPicker(repository: widget.app.repository),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        surahId = selected.number;
        error = null;
      });
    }
  }

  Future<void> _preview() async {
    FocusScope.of(context).unfocus();
    PassageRange range;
    try {
      range = PassageRange.fromInput(
        surah: '$surahId',
        start: start.text,
        end: end.text,
        repository: widget.app.repository,
      );
      if (name.text.trim().runes.length > 120) {
        throw const FormatException('اختر اسمًا لا يتجاوز 120 حرفًا.');
      }
    } on FormatException catch (e) {
      setState(() => error = e.message.toString());
      return;
    }
    setState(() => error = null);
    final existing = widget.passage;
    if (existing != null && existing.range != range) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('تغيير آيات المقطع؟'),
          content: const Text(
            'تغيير الآيات يعيد المقطع إلى «غير محفوظ» ويوقف اقتراحه للصلاة. ستراجع النص قبل حفظ التغيير.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('معاينة التغييرات'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<SavedPassage>(
      MaterialPageRoute(
        builder: (_) => _PassagePreviewScreen(
          app: widget.app,
          range: range,
          name: name.text.trim(),
          existingId: existing?.id,
        ),
      ),
    );
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 26),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: SuwarColors.muted),
        ),
      ),
      const SizedBox(height: 6),
      Semantics(
        label: label,
        child: TextField(
          controller: controller,
          key: ValueKey(
            number
                ? (label == 'من الآية' ? 'passage-start' : 'passage-end')
                : 'passage-name',
          ),
          style: const TextStyle(fontSize: 17, height: 1.6),
          keyboardType: number ? TextInputType.number : TextInputType.text,
          textInputAction: number ? TextInputAction.done : TextInputAction.next,
          decoration: InputDecoration(
            isDense: true,
            constraints: const BoxConstraints(minHeight: 56),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            errorText: number && error != null ? '' : null,
          ),
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const PageStorageKey('passage-editor'),
              children: [
                ScreenHeading(
                  title: widget.passage == null
                      ? 'تفاصيل المقطع'
                      : 'تغيير آيات المقطع',
                  subtitle: 'آيات متتابعة من سورة واحدة',
                  onBack: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 3, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field('اسم المقطع', name),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 28),
                        child: const Text(
                          'يمكنك اختيار اسمك الخاص، أو ترك الاسم فارغًا.',
                          style: TextStyle(
                            fontSize: 12,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 26),
                        child: const Text(
                          'السورة',
                          style: TextStyle(
                            fontSize: 13,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        key: const ValueKey('passage-surah'),
                        onPressed: _chooseSurah,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            height: 1.6,
                            fontFamily: 'NotoSansArabic',
                          ),
                          backgroundColor: SuwarColors.paper,
                          side: const BorderSide(color: SuwarColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.app.repository.surah(surahId).name,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_left,
                              textDirection: TextDirection.ltr,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final a = _field('من الآية', start, number: true);
                          final b = _field('إلى الآية', end, number: true);
                          return constraints.maxWidth < 300 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      22
                              ? Column(
                                  children: [a, const SizedBox(height: 16), b],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: a),
                                    const SizedBox(width: 16),
                                    Expanded(child: b),
                                  ],
                                );
                        },
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: Color(0xFF8A512B),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'سورة ${widget.app.repository.surah(surahId).name} تضم ${displayNumber(widget.app.repository.surah(surahId).verseCount)} آية في هذا المصحف.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 15),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: const Text(
                          'ترقيم الآيات بحسب مصحف ورش المستخدم هنا.',
                          style: TextStyle(
                            fontSize: 12,
                            color: SuwarColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.passage != null)
                        const DesignNotice(
                          message:
                              'تغيير الآيات يعيد المقطع إلى «غير محفوظ» ويوقف اقتراحه للصلاة. تغيير الاسم لا يفعل ذلك.',
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 36),
                          child: const Text(
                            'ستراجع النص كاملًا قبل حفظ المقطع.',
                            style: TextStyle(
                              fontSize: 13,
                              color: SuwarColors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryAction(
                  label: widget.passage == null
                      ? 'معاينة المقطع'
                      : 'معاينة التغييرات',
                  onPressed: _preview,
                ),
                if (widget.passage == null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'الاسم خاص بك، ولا يغيّر نص القرآن.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: SuwarColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PassagePreviewScreen extends StatefulWidget {
  const _PassagePreviewScreen({
    required this.app,
    required this.range,
    required this.name,
    this.existingId,
  });
  final AppState app;
  final PassageRange range;
  final String name;
  final String? existingId;
  @override
  State<_PassagePreviewScreen> createState() => _PassagePreviewScreenState();
}

class _PassagePreviewScreenState extends State<_PassagePreviewScreen> {
  bool busy = false;
  Future<void> _save() async {
    setState(() => busy = true);
    final state = PassageScope.of(context);
    try {
      final result = widget.existingId == null
          ? await state.create(range: widget.range, name: widget.name)
          : await state.update(
              widget.existingId!,
              range: widget.range,
              name: widget.name,
            );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error ?? 'تعذّر الحفظ. حاول مجددًا.')),
        );
      } else if (result.duplicate) {
        final open = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('المقطع موجود لديك'),
            content: Text(
              'حفظته باسم «${result.passage.displayName(widget.app.repository)}». ستبقى إعدادات المقطع كما هي.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('العودة لتحديد آيات أخرى'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('فتح المقطع الموجود'),
              ),
            ],
          ),
        );
        if (mounted) {
          // The recovery action explicitly returns to the preserved editor.
          Navigator.pop(context, open == true ? result.passage : null);
        }
      } else {
        Navigator.pop(context, result.passage);
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PassageTextView(
    app: widget.app,
    range: widget.range,
    name: widget.name,
    actionLabel: busy ? 'جارٍ الحفظ…' : 'حفظ المقطع',
    onAction: busy ? null : _save,
    footer: 'الحفظ هنا لا يعني أنك تحفظ الآيات عن ظهر قلب.',
  );
}

class _PassageSurahPicker extends StatefulWidget {
  const _PassageSurahPicker({required this.repository});
  final QuranRepository repository;
  @override
  State<_PassageSurahPicker> createState() => _PassageSurahPickerState();
}

class _PassageSurahPickerState extends State<_PassageSurahPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final q = normalizeSearch(query);
    final found = widget.repository.surahs
        .where(
          (s) =>
              q.isEmpty ||
              normalizeSearch(s.name).contains(q) ||
              normalizeSearch(s.nameEnglish).contains(q) ||
              '${s.number}' == q,
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeading(
                title: 'اختر السورة',
                subtitle: 'البحث في السور الـ 114',
                onBack: () => Navigator.pop(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'ابحث باسم السورة أو رقمها',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
            ),
            if (found.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد سور مطابقة. جرّب اسمًا أو رقمًا آخر.'),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: found.length,
                itemBuilder: (context, index) => SurahTile(
                  surah: found[index],
                  onTap: () => Navigator.pop(context, found[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
