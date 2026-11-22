import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/quran_repository.dart';

const ayahTopics = {
  'all': 'كل المعاني',
  'comfort': 'طمأنينة',
  'jannah': 'الجنة',
  'power': 'قدرة الله',
};

class RemembranceAyah {
  RemembranceAyah.fromJson(Map<String, dynamic> data)
    : id = data['id'] as String,
      surahId = data['surahId'] as int,
      ayahNumber = data['ayahNumber'] as int,
      topic = data['topic'] as String,
      context = data['context'] as String,
      compact = data['compact'] as bool;
  final String id, topic, context;
  final int surahId, ayahNumber;
  final bool compact;
  Ayah source(QuranRepository repository) =>
      repository.surah(surahId).ayahs.firstWhere((a) => a.number == ayahNumber);
  String reference(QuranRepository repository) =>
      '${repository.surah(surahId).name} · $ayahNumber · ورش';
}

List<RemembranceAyah> decodeRemembranceCatalog(
  String source,
  QuranRepository repository,
) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  if (data['source'] != 'kfgqpc-warsh-v10-6214' || data['version'] != 1) {
    throw const FormatException('Unknown Quran source');
  }
  final items = (data['entries'] as List)
      .map((e) => RemembranceAyah.fromJson(e as Map<String, dynamic>))
      .toList();
  if (items.isEmpty || items.map((e) => e.id).toSet().length != items.length) {
    throw const FormatException('Invalid ayah catalog');
  }
  for (final item in items) {
    if (!ayahTopics.containsKey(item.topic) ||
        item.topic == 'all' ||
        item.id != '${item.surahId}:${item.ayahNumber}') {
      throw const FormatException('Invalid ayah reference');
    }
    item.source(repository);
  }
  return List.unmodifiable(items);
}

RemembranceAyah selectRemembranceAyah(
  List<RemembranceAyah> entries, {
  required DateTime date,
  String topic = 'all',
  int offset = 0,
  bool compact = false,
}) {
  final pool = entries
      .where(
        (e) => (topic == 'all' || e.topic == topic) && (!compact || e.compact),
      )
      .toList();
  if (pool.isEmpty) throw const FormatException('Empty ayah topic');
  final day =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return pool[(day + offset) % pool.length];
}

class AyahWidgetBridge extends ChangeNotifier {
  AyahWidgetBridge(this.repository);
  static const channel = MethodChannel('suwar/ayah_widget');
  final QuranRepository repository;
  final pendingLaunch = ValueNotifier<String?>(null);
  List<RemembranceAyah> entries = [];
  String topic = 'all';
  int offset = 0;
  String? error;
  bool _disposed = false;
  bool _channelInstalled = false;
  Future<void>? _initialization;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  RemembranceAyah? find(String? id) =>
      entries.where((e) => e.id == id).firstOrNull;
  RemembranceAyah? selected({DateTime? date, bool? compact}) => entries.isEmpty
      ? null
      : selectRemembranceAyah(
          entries,
          date: date ?? DateTime.now(),
          topic: topic,
          offset: offset,
          compact: compact ?? isIOS,
        );

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      entries = decodeRemembranceCatalog(
        await rootBundle.loadString('assets/quran/remembrance-catalog.json'),
        repository,
      );
      if (_disposed) return;
      if (supported) {
        _channelInstalled = true;
        channel.setMethodCallHandler((call) async {
          if (call.method == 'openAyah') await consumeLaunch();
        });
        await refresh();
        await consumeLaunch();
      }
    } catch (_) {
      error = 'تعذّر فتح آيات التذكير. حاول مجددًا.';
      _initialization = null;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (!supported) return;
    await _call('getState');
  }

  Future<void> setTopic(String value) async {
    if (!ayahTopics.containsKey(value)) return;
    if (!supported) {
      topic = value;
      offset = 0;
      notifyListeners();
      return;
    }
    await _call('setTopic', value);
  }

  Future<void> next() async {
    if (!supported) {
      offset++;
      notifyListeners();
      return;
    }
    await _call('next');
  }

  Future<void> _call(String method, [Object? argument]) async {
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>(
        method,
        argument,
      );
      if (raw == null ||
          !ayahTopics.containsKey(raw['topic']) ||
          raw['offset'] is! int) {
        throw const FormatException('Invalid widget state');
      }
      topic = raw['topic'] as String;
      offset = raw['offset'] as int;
      error = null;
    } catch (_) {
      error = 'تعذّر تحديث الأداة. حاول مرة أخرى.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> requestPin() async {
    if (!supported || isIOS) return false;
    try {
      return await channel.invokeMethod<bool>('requestPin') ?? false;
    } catch (_) {
      error = 'أضف الأداة من قائمة أدوات الهاتف.';
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<void> consumeLaunch() async {
    if (!supported || _disposed) return;
    try {
      final id = await channel.invokeMethod<String>('consumeAyahLaunch');
      if (!_disposed && find(id) != null) pendingLaunch.value = id;
    } catch (_) {
      /* A missing launch does not prevent offline reading. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_channelInstalled) channel.setMethodCallHandler(null);
    pendingLaunch.dispose();
    super.dispose();
  }
}
