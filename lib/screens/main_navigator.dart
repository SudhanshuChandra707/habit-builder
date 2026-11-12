import 'package:flutter/material.dart';
import 'package:to_do_list/screens/home_screen.dart';
import 'package:to_do_list/screens/habit_builder_screen.dart';
import 'package:to_do_list/screens/collections_screen.dart';
import 'package:to_do_list/widgets/glass_island.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _Tab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String addTooltip;

  const _Tab(this.icon, this.selectedIcon, this.label, this.addTooltip);
}

class _MainNavigatorState extends State<MainNavigator> {
  /// Height of every island in the bar (capsule and + circle).
  static const double _islandHeight = 56;

  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HabitBuilderScreen(),
    CollectionsScreen(),
  ];

  static const _tabs = [
    _Tab(
        Icons.task_alt_outlined, Icons.task_alt, 'Tasks', 'New to-do or habit'),
    _Tab(Icons.auto_graph_outlined, Icons.auto_graph, 'Habits', 'New habit'),
    _Tab(Icons.grid_view_outlined, Icons.grid_view, 'Lists', 'New list'),
  ];

  /// The + island runs the add action of whichever tab is showing.
  void _onAdd() {
    switch (_currentIndex) {
      case 0:
        HomeScreen.showNewItemSheet(context);
      case 1:
        HabitBuilderScreen.showAddHabitSheet(context);
      case 2:
        CollectionsScreen.showAddCollectionDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      extendBody: true,
      bottomNavigationBar: _buildDock(context),
    );
  }

  /// Compact floating bar in the style of iOS toolbars: a glass capsule of
  /// tab icons and a separate glass circle for +, with content scrolling
  /// underneath. Continuous (superellipse) corners throughout.
  Widget _buildDock(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            GlassIsland.capsule(
              height: _islandHeight,
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _tabs.length; i++) _buildTab(i),
                ],
              ),
            ),
            const Spacer(),
            _buildAddIsland(),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab = _tabs[index];
    final isSelected = _currentIndex == index;
    final scheme = Theme.of(context).colorScheme;
    const innerHeight = _islandHeight - 8; // capsule padding 4 + 4
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(innerHeight / 2),
    );

    return Tooltip(
      message: tab.label,
      child: Semantics(
        label: tab.label,
        selected: isSelected,
        button: true,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: shape,
            onTap: () => setState(() => _currentIndex = index),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150), // tab switch: quick
              curve: Curves.easeOut,
              width: 64,
              height: innerHeight,
              decoration: ShapeDecoration(
                shape: shape,
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.primary.withValues(alpha: 0),
              ),
              child: Icon(
                isSelected ? tab.selectedIcon : tab.icon,
                size: 24,
                color: isSelected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddIsland() {
    final scheme = Theme.of(context).colorScheme;
    final tooltip = _tabs[_currentIndex].addTooltip;

    return GlassIsland.capsule(
      height: _islandHeight,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          label: tooltip,
          button: true,
          excludeSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _onAdd,
              child: SizedBox.square(
                dimension: _islandHeight,
                child: Icon(Icons.add, size: 28, color: scheme.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
