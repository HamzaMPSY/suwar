import 'package:flutter/material.dart';
import 'audio_library.dart';

final audioRouteObserver = RouteObserver<ModalRoute<void>>();

class AudioScope extends InheritedWidget {
  const AudioScope({super.key, required this.library, required super.child});
  final AudioLibrary library;
  static AudioLibrary? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AudioScope>()?.library;
  @override
  bool updateShouldNotify(AudioScope oldWidget) => oldWidget.library != library;
}
