import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'passage_editor_screen.dart';
import 'passage_models.dart';
import 'passage_scope.dart';

class PassageEditScreen extends StatefulWidget {
  const PassageEditScreen({
    super.key,
    required this.app,
    required this.passage,
  });
  final AppState app;
  final SavedPassage passage;
  @override
  State<PassageEditScreen> createState() => _PassageEditScreenState();
}

class _PassageEditScreenState extends State<PassageEditScreen> {
  late final TextEditingController name;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.passage.name);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    final state = PassageScope.of(context);
    try {
      final saved = await state.update(widget.passage.id, name: name.text);
      if (!mounted) return;
      if (saved != null) {
        Navigator.pop(context, saved.passage);
        return;
      }
      setState(() => error = state.error ?? 'تعذّر الحفظ. حاول مجددًا.');
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _range() async {
    final state = PassageScope.of(context);
    final latest = state.find(widget.passage.id);
    if (latest == null) return;
    final saved = await openPassageEditor(
      context,
      app: widget.app,
      passage: latest,
      initialName: name.text,
    );
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ScreenHeading(
                  title: 'تعديل المقطع',
                  subtitle: widget.passage.range.reference(
                    widget.app.repository,
                  ),
                  onBack: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'اسم المقطع',
                        style: TextStyle(
                          fontSize: 13,
                          color: SuwarColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        label: 'اسم المقطع',
                        child: TextField(
                          key: const ValueKey('passage-rename'),
                          controller: name,
                          decoration: InputDecoration(errorText: error),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'تغيير الاسم يحافظ على حالة الحفظ واختيارك لاقتراح المقطع في الصلاة.',
                        style: TextStyle(
                          fontSize: 15,
                          color: SuwarColors.muted,
                        ),
                      ),
                      const SizedBox(height: 48),
                      PrimaryAction(
                        label: 'تغيير الآيات المحددة',
                        secondary: true,
                        onPressed: busy ? null : _range,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: PrimaryAction(
              label: busy ? 'جارٍ الحفظ…' : 'حفظ الاسم',
              onPressed: busy ? null : _save,
            ),
          ),
        ],
      ),
    ),
  );
}
