import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'prayer_models.dart';

class PrayerLocationControls extends StatelessWidget {
  const PrayerLocationControls({
    super.key,
    required this.settings,
    required this.busy,
    required this.onUpdate,
  });
  final PrayerSettings settings;
  final bool busy;
  final ValueChanged<PrayerSettings> onUpdate;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<PrayerCity>(
        key: ValueKey(settings.city.id),
        initialValue: settings.city,
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'المدينة'),
        items: PrayerCity.cities
            .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
            .toList(),
        onChanged: busy
            ? null
            : (c) {
                if (c != null) {
                  onUpdate(settings.copyWith(city: c));
                }
              },
      ),
      const SizedBox(height: 36),
      DropdownButtonFormField<PrayerMethod>(
        key: ValueKey(settings.method),
        initialValue: settings.method,
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'طريقة الحساب'),
        items: PrayerMethod.values
            .map(
              (m) => DropdownMenuItem(
                value: m,
                child: Text(
                  m.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: busy
            ? null
            : (m) {
                if (m != null) {
                  onUpdate(settings.copyWith(method: m));
                }
              },
      ),
      const SizedBox(height: 36),
      DropdownButtonFormField<AsrConvention>(
        key: ValueKey(settings.asr),
        initialValue: settings.asr,
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'حساب العصر'),
        items: AsrConvention.values
            .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
            .toList(),
        onChanged: busy
            ? null
            : (a) {
                if (a != null) {
                  onUpdate(settings.copyWith(asr: a));
                }
              },
      ),
      const SizedBox(height: 36),
      const Text(
        'الأوقات تقديرية بحسب الحساب، وليست جدولًا رسميًا منقولًا. لا نستخدم موقعك أو نرسله إلى أي خادم.',
        style: TextStyle(color: SuwarColors.muted, fontSize: 13, height: 1.8),
      ),
    ],
  );
}

Widget prayerSettingsRow(String label, String value, VoidCallback? action) =>
    InkWell(
      onTap: action,
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        value,
                        style: const TextStyle(
                          color: SuwarColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: SuwarColors.green,
                ),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 6),
        ],
      ),
    );
