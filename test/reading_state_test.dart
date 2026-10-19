import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/reading/reading_state.dart';

void main() {
  late QuranRepository repository;
  setUpAll(() {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reading source IDs accept Warsh Quraysh verse five, reject nonexistent six',
    () {
      expect(
        ReadingPosition.fromJson({'surahId': 106, 'ayahNumber': 5}, repository),
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      for (final invalid in [
        {'surahId': 106, 'ayahNumber': 6},
        {'surahId': 106, 'ayahNumber': 0},
        {'surahId': 115, 'ayahNumber': 1},
        {'surahId': 106, 'ayahNumber': '5'},
      ]) {
        expect(
          () => ReadingPosition.fromJson(invalid, repository),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'snapshot roundtrip is immutable and rejects duplicate or invalid bookmarks',
    () {
      const a = ReadingPosition(surahId: 106, ayahNumber: 5);
      final source = [a];
      final snapshot = ReadingSnapshot(position: a, bookmarks: source);
      source.clear();
      expect(snapshot.bookmarks, [a]);
      expect(() => snapshot.bookmarks.clear(), throwsUnsupportedError);
      expect(
        ReadingSnapshot.fromJson(snapshot.toJson(), repository).toJson(),
        snapshot.toJson(),
      );
      expect(
        () => ReadingSnapshot.fromJson({
          'version': 1,
          'position': null,
          'bookmarks': [a.toJson(), a.toJson()],
        }, repository),
        throwsFormatException,
      );
      expect(
        () => ReadingSnapshot.fromJson({
          ...snapshot.toJson(),
          'version': 2,
        }, repository),
        throwsFormatException,
      );
    },
  );

  test(
    'legacy ordinal seed maps to actual source ayah and leaves original keys intact',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final app = AppState(repository: repository, preferences: preferences);
      await app.setMemorized({112, 114});
      await app.setLastRead(106, 4);
      await preferences.setString('suwar.prayer.v1', '{"preserved":true}');
      final quran = preferences.getString(AppState.storageKey);
      final state = ReadingState(app: app, preferences: preferences);
      await state.flush();
      expect(
        state.snapshot.position,
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      expect(preferences.getString(AppState.storageKey), quran);
      expect(preferences.getString('suwar.prayer.v1'), '{"preserved":true}');
      state.dispose();
      app.dispose();
    },
  );

  test(
    'empty sidecar seeds once and does not reinterpret later legacy changes',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final app = AppState(repository: repository, preferences: preferences);
      final original = ReadingState(app: app, preferences: preferences);
      await original.flush();
      expect(original.snapshot.position, isNull);
      await app.setLastRead(106, 4);
      final restored = ReadingState(app: app, preferences: preferences);
      expect(restored.snapshot.position, isNull);
      original.dispose();
      restored.dispose();
      app.dispose();
    },
  );

  test(
    'queued bookmarking operations preserve additions and reversal across reload',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final app = AppState(repository: repository, preferences: preferences);
      final state = ReadingState(app: app, preferences: preferences);
      const a = ReadingPosition(surahId: 106, ayahNumber: 5);
      const b = ReadingPosition(surahId: 112, ayahNumber: 2);
      expect(
        await Future.wait([
          state.toggleBookmark(a),
          state.toggleBookmark(b),
          state.toggleBookmark(a),
          state.savePosition(b),
        ]),
        everyElement(isTrue),
      );
      final restored = ReadingState(app: app, preferences: preferences);
      expect(restored.snapshot.position, b);
      expect(restored.snapshot.bookmarks, [b]);
      state.dispose();
      restored.dispose();
      app.dispose();
    },
  );

  test(
    'corrupt reading snapshot is retained until backed up before new write',
    () async {
      SharedPreferences.setMockInitialValues({
        ReadingState.storageKey: '{broken',
      });
      final preferences = await SharedPreferences.getInstance();
      final app = AppState(repository: repository, preferences: preferences);
      final state = ReadingState(app: app, preferences: preferences);
      expect(state.error, isNotNull);
      expect(preferences.getString(ReadingState.storageKey), '{broken');
      expect(
        await state.toggleBookmark(
          const ReadingPosition(surahId: 112, ayahNumber: 1),
        ),
        isTrue,
      );
      expect(preferences.getString(ReadingState.recoveryKey), '{broken');
      expect(state.error, isNull);
      state.dispose();
      app.dispose();
    },
  );

  test(
    'recovery collision rejects replacement without changing reading snapshot',
    () async {
      SharedPreferences.setMockInitialValues({
        ReadingState.storageKey: '{broken',
        ReadingState.recoveryKey: 'previous recovery',
      });
      final preferences = await SharedPreferences.getInstance();
      final app = AppState(repository: repository, preferences: preferences);
      final state = ReadingState(app: app, preferences: preferences);
      expect(
        await state.savePosition(
          const ReadingPosition(surahId: 112, ayahNumber: 1),
        ),
        isFalse,
      );
      expect(state.snapshot.position, isNull);
      expect(preferences.getString(ReadingState.storageKey), '{broken');
      expect(
        preferences.getString(ReadingState.recoveryKey),
        'previous recovery',
      );
      state.dispose();
      app.dispose();
    },
  );
}
