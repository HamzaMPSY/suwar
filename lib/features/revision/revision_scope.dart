import 'package:flutter/widgets.dart';
import 'revision_state.dart';

class RevisionScope extends InheritedWidget {
  const RevisionScope({super.key, required this.state, required super.child});
  final RevisionState state;
  static RevisionState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RevisionScope>()?.state;
  @override
  bool updateShouldNotify(RevisionScope oldWidget) => oldWidget.state != state;
}
