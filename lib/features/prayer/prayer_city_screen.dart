import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'prayer_models.dart';

class PrayerCityScreen extends StatefulWidget {
  const PrayerCityScreen({super.key, required this.settings});
  final PrayerSettings settings;
  @override
  State<PrayerCityScreen> createState() => _PrayerCityScreenState();
}

class _PrayerCityScreenState extends State<PrayerCityScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final normalized = normalizeSearch(query);
    final cities = PrayerCity.cities
        .where(
          (city) =>
              normalizeSearch(city.name).contains(normalized) ||
              city.id.contains(normalized),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            ScreenHeading(
              title: 'اختر مدينتك',
              subtitle: 'تُستخدم المدينة لمواقيت الصلاة فقط.',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  labelText: 'ابحث عن مدينة',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(16),
                    child: SuwarIcon(SuwarSymbol.search),
                  ),
                ),
              ),
            ),
            if (cities.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد مدينة مطابقة ضمن المدن المتاحة.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final city in cities)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(city),
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 88),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    city.name,
                                    style: headingStyle(context, size: 24),
                                  ),
                                  const Text(
                                    'المغرب',
                                    style: TextStyle(
                                      color: SuwarColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.settings.city.id == city.id)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SuwarIcon(SuwarSymbol.check, size: 20),
                              ),
                            const SuwarIcon(SuwarSymbol.pin, size: 24),
                          ],
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'يمكنك تغيير المدينة من إعدادات الصلاة.',
                style: TextStyle(color: SuwarColors.muted, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
