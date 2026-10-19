enum PrayerKind {
  fajr('الفجر'),
  dhuhr('الظهر'),
  asr('العصر'),
  maghrib('المغرب'),
  isha('العشاء');

  const PrayerKind(this.label);
  final String label;
}

enum PrayerMethod {
  morocco('حساب المغرب'),
  muslimWorldLeague('رابطة العالم الإسلامي'),
  egyptian('الهيئة المصرية للمساحة'),
  karachi('جامعة العلوم الإسلامية بكراتشي');

  const PrayerMethod(this.label);
  final String label;
}

enum AsrConvention {
  standard('الظل الواحد'),
  hanafi('الظلّان — الحنفي');

  const AsrConvention(this.label);
  final String label;
}

class PrayerCity {
  const PrayerCity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timeZone,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String timeZone;

  static const casablanca = PrayerCity(
    id: 'casablanca',
    name: 'الدار البيضاء',
    latitude: 33.5731,
    longitude: -7.5898,
    timeZone: 'Africa/Casablanca',
  );
  static const List<PrayerCity> cities = [
    casablanca,
    PrayerCity(
      id: 'rabat',
      name: 'الرباط',
      latitude: 34.0209,
      longitude: -6.8416,
      timeZone: 'Africa/Casablanca',
    ),
    PrayerCity(
      id: 'sale',
      name: 'سلا',
      latitude: 34.0531,
      longitude: -6.7985,
      timeZone: 'Africa/Casablanca',
    ),
    PrayerCity(
      id: 'temara',
      name: 'تمارة',
      latitude: 33.9287,
      longitude: -6.9063,
      timeZone: 'Africa/Casablanca',
    ),
    PrayerCity(
      id: 'marrakesh',
      name: 'مراكش',
      latitude: 31.6295,
      longitude: -7.9811,
      timeZone: 'Africa/Casablanca',
    ),
    PrayerCity(
      id: 'fes',
      name: 'فاس',
      latitude: 34.0181,
      longitude: -5.0078,
      timeZone: 'Africa/Casablanca',
    ),
    PrayerCity(
      id: 'tangier',
      name: 'طنجة',
      latitude: 35.7595,
      longitude: -5.8340,
      timeZone: 'Africa/Casablanca',
    ),
    PrayerCity(
      id: 'agadir',
      name: 'أكادير',
      latitude: 30.4278,
      longitude: -9.5981,
      timeZone: 'Africa/Casablanca',
    ),
  ];
}

class PrayerSettings {
  PrayerSettings({
    this.city = PrayerCity.casablanca,
    this.method = PrayerMethod.morocco,
    this.asr = AsrConvention.standard,
    this.remindersEnabled = false,
    Set<PrayerKind>? enabledPrayers,
    this.leadMinutes = 0,
    this.includeSuggestions = true,
  }) : enabledPrayers = Set.unmodifiable(enabledPrayers ?? PrayerKind.values) {
    if (leadMinutes != 0 && leadMinutes != 10) {
      throw ArgumentError.value(leadMinutes, 'leadMinutes');
    }
    if (!city.latitude.isFinite ||
        city.latitude.abs() > 90 ||
        !city.longitude.isFinite ||
        city.longitude.abs() > 180 ||
        city.timeZone.isEmpty) {
      throw ArgumentError.value(city, 'city');
    }
  }

  final PrayerCity city;
  final PrayerMethod method;
  final AsrConvention asr;
  final bool remindersEnabled;
  final Set<PrayerKind> enabledPrayers;
  final int leadMinutes;
  final bool includeSuggestions;

  PrayerSettings copyWith({
    PrayerCity? city,
    PrayerMethod? method,
    AsrConvention? asr,
    bool? remindersEnabled,
    Set<PrayerKind>? enabledPrayers,
    int? leadMinutes,
    bool? includeSuggestions,
  }) => PrayerSettings(
    city: city ?? this.city,
    method: method ?? this.method,
    asr: asr ?? this.asr,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    enabledPrayers: enabledPrayers ?? this.enabledPrayers,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    includeSuggestions: includeSuggestions ?? this.includeSuggestions,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'city': city.id,
    'method': method.name,
    'asr': asr.name,
    'remindersEnabled': remindersEnabled,
    'enabledPrayers': enabledPrayers.map((prayer) => prayer.name).toList(),
    'leadMinutes': leadMinutes,
    'includeSuggestions': includeSuggestions,
  };

  factory PrayerSettings.fromJson(Map<String, dynamic> data) {
    if (data['version'] != 1) throw const FormatException('Unknown version');
    final city = PrayerCity.cities.firstWhere(
      (city) => city.id == data['city'],
      orElse: () => throw const FormatException('Unknown prayer city'),
    );
    return PrayerSettings(
      city: city,
      method: PrayerMethod.values.byName(
        data['method'] as String? ?? 'morocco',
      ),
      asr: AsrConvention.values.byName(data['asr'] as String? ?? 'standard'),
      remindersEnabled: data['remindersEnabled'] as bool? ?? false,
      enabledPrayers: data['enabledPrayers'] == null
          ? null
          : (data['enabledPrayers'] as List<dynamic>)
                .map((value) => PrayerKind.values.byName(value as String))
                .toSet(),
      leadMinutes: data['leadMinutes'] as int? ?? 0,
      includeSuggestions: data['includeSuggestions'] as bool? ?? true,
    );
  }
}

class PrayerOccurrence {
  const PrayerOccurrence({required this.kind, required this.timeUtc});
  final PrayerKind kind;
  final DateTime timeUtc;
}
