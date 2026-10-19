import 'package:flutter/widgets.dart';
import 'passage_state.dart';

class PassageScope extends InheritedWidget {
  const PassageScope({super.key, required this.state, required super.child});
  final PassageState state;
  static PassageState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PassageScope>()?.state;
  static PassageState of(BuildContext context) => maybeOf(context)!;
  @override
  bool updateShouldNotify(PassageScope oldWidget) => oldWidget.state != state;
}
