import 'package:flutter/material.dart';
import 'theme.dart';
import 'suwar_icons.dart';

class SuwarNavigationScope extends InheritedWidget {
  const SuwarNavigationScope({
    super.key,
    required this.selectTab,
    required super.child,
  });
  final ValueChanged<int> selectTab;
  static SuwarNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuwarNavigationScope>();
  @override
  bool updateShouldNotify(SuwarNavigationScope oldWidget) =>
      selectTab != oldWidget.selectTab;
}

class SuwarBottomNavigation extends StatelessWidget {
  const SuwarBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: SuwarColors.paper,
      border: Border(top: BorderSide(color: SuwarColors.line)),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: 50 + MediaQuery.textScalerOf(context).scale(12) * 1.65,
        child: Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(child: _destination(context, i)),
          ],
        ),
      ),
    ),
  );
  Widget _destination(BuildContext context, int index) {
    const labels = ['اليوم', 'القرآن', 'حفظي', 'الصلاة'];
    const symbols = [
      SuwarSymbol.home,
      SuwarSymbol.book,
      SuwarSymbol.learning,
      SuwarSymbol.prayer,
    ];
    final selected = index == selectedIndex;
    final color = selected ? SuwarColors.green : SuwarColors.muted;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: labels[index],
      onTap: () => onSelected(index),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onSelected(index),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (selected)
                Positioned(
                  top: 8,
                  child: Container(
                    width: 52,
                    height: 33,
                    decoration: BoxDecoration(
                      color: SuwarColors.sage,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              Positioned(
                top: 13,
                child: SuwarIcon(symbols[index], size: 22, color: color),
              ),
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.65,
                    color: color,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
