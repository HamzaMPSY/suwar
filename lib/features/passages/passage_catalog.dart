import 'passage_models.dart';

class PassagePreset {
  const PassagePreset({
    required this.id,
    required this.name,
    required this.range,
  });
  final String id, name;
  final PassageRange range;
}

abstract final class PassageCatalog {
  // Exact bundled Warsh boundaries; the complete Kursi spans two source ayahs.
  static const presets = [
    PassagePreset(
      id: 'ayat-al-kursi',
      name: 'آية الكرسي',
      range: PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
    ),
    PassagePreset(
      id: 'ayat-al-birr',
      name: 'آية البر',
      range: PassageRange(surahId: 2, startAyah: 176, endAyah: 176),
    ),
    PassagePreset(
      id: 'end-al-baqara',
      name: 'آخر آيتين من البقرة',
      range: PassageRange(surahId: 2, startAyah: 284, endAyah: 285),
    ),
  ];
}
