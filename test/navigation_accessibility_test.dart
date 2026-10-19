import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suwar/core/widgets.dart';

void main() {
  testWidgets('screen-reader taps activate tabs and choice pills', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var tab = 0;
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuwarChoicePill(
            label: 'محفوظاتي',
            selected: false,
            onTap: () => picked = true,
          ),
          bottomNavigationBar: SuwarBottomNavigation(
            selectedIndex: 0,
            onSelected: (value) => tab = value,
          ),
        ),
      ),
    );
    final choice = tester.getSemantics(find.bySemanticsLabel('محفوظاتي'));
    choice.owner!.performAction(choice.id, SemanticsAction.tap);
    expect(picked, isTrue);
    final destination = tester.getSemantics(find.bySemanticsLabel('القرآن'));
    destination.owner!.performAction(destination.id, SemanticsAction.tap);
    expect(tab, 1);
    semantics.dispose();
  });
}
