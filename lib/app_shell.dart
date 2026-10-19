part of 'app.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state, this.prayer});
  final AppState state;
  final PrayerRuntime? prayer;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  int? _previousLearning;
  @override
  void initState() {
    super.initState();
    _previousLearning = widget.state.learningSurahId;
    widget.state.addListener(_progressChanged);
  }

  void _progressChanged() {
    final current = widget.state.learningSurahId;
    if (_previousLearning != null &&
        current == null &&
        widget.state.memorizedIds.contains(_previousLearning)) {
      setState(() => tab = 2);
    }
    _previousLearning = current;
  }

  @override
  void dispose() {
    widget.state.removeListener(_progressChanged);
    super.dispose();
  }

  void showTab(int index) => setState(() => tab = index.clamp(0, 3));
  void browse() => setState(() => tab = 1);
  void showPrayer() => setState(() => tab = 3);
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: tab,
              children: [
                HomeScreen(
                  state: widget.state,
                  onBrowse: browse,
                  prayer: widget.prayer,
                  onPrayers: () => setState(() => tab = 3),
                ),
                LibraryScreen(state: widget.state),
                MemoryScreen(state: widget.state, onBrowse: browse),
                if (widget.prayer != null)
                  PrayerScreen(runtime: widget.prayer!, app: widget.state)
                else
                  const Center(child: Text('مواقيت الصلاة')),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SuwarBottomNavigation(
      selectedIndex: tab,
      onSelected: showTab,
    ),
  );
}
