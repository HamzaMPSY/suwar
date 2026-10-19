import 'package:flutter/widgets.dart';
import 'reading_state.dart';

class ReadingScope extends InheritedWidget {
  const ReadingScope({super.key, required this.state, required super.child});
  final ReadingState state;
  static ReadingState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingScope>()?.state;
  @override
  bool updateShouldNotify(ReadingScope oldWidget) => oldWidget.state != state;
}
