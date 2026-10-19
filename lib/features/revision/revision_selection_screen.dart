import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/widgets.dart';
import 'revision_state.dart';

class RevisionSelectionScreen extends StatefulWidget {
  const RevisionSelectionScreen({super.key, required this.state});
  final RevisionState state;
  @override
  State<RevisionSelectionScreen> createState() =>
      _RevisionSelectionScreenState();
}

class _RevisionSelectionScreenState extends State<RevisionSelectionScreen> {
  late Set<int> selected = {...widget.state.activeIds};
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final known = widget.state.app.repository.surahs
        .where((s) => widget.state.app.memorizedIds.contains(s.number))
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            ScreenHeading(
              title: 'سور مراجعتي اليومية',
              subtitle:
                  'اختر من السور التي تحفظها. يمكنك تعديل القائمة في أي وقت.',
              padding: const EdgeInsets.fromLTRB(0, 21, 0, 20),
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 20),
            for (final surah in known)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(surah.name),
                subtitle: Text('${displayNumber(surah.verseCount)} آيات'),
                value: selected.contains(surah.number),
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          selected.add(surah.number);
                        } else {
                          selected.remove(surah.number);
                        }
                      }),
              ),
            const SizedBox(height: 20),
            PrimaryAction(
              label: busy ? 'جارٍ الحفظ' : 'حفظ اختياراتي',
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final ok = await widget.state.setSelection(selected);
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => busy = false);
                      }
                    },
            ),
            if (widget.state.error != null) Text(widget.state.error!),
          ],
        ),
      ),
    );
  }
}
