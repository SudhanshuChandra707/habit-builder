import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_list/models/todo.dart';
import 'package:to_do_list/models/daily_task.dart';
import 'package:to_do_list/providers/todo_provider.dart';
import 'package:to_do_list/services/sun_service.dart';
import 'package:to_do_list/widgets/todo_tile.dart';
import 'package:to_do_list/widgets/daily_task_tile.dart';
import 'package:to_do_list/widgets/add_todo_sheet.dart';
import 'package:to_do_list/widgets/add_daily_task_sheet.dart';
import 'package:to_do_list/widgets/new_item_sheet.dart';
import 'package:to_do_list/widgets/stats_header.dart';
import 'package:to_do_list/widgets/day_progress_arc.dart';

enum _MenuAction { clearCompleted, system, light, dark, sunLocation }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Opened from the + island in the bottom bar.
  static void showNewItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewItemSheet(),
    );
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// "Good afternoon · Thursday, 12 November"
  String _greetingLine() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Good morning'
        : hour >= 12 && hour < 17
            ? 'Good afternoon'
            : hour >= 17 && hour < 21
                ? 'Good evening'
                : 'Good night';
    final date =
        '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
    return '$greeting · $date';
  }

  // ---------------------------------------------------------------- sheets

  void _showEditTodoSheet(Todo todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTodoSheet(existingTodo: todo),
    );
  }

  void _showEditDailyTaskSheet(DailyTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDailyTaskSheet(existingTask: task),
    );
  }

  // ------------------------------------------------------- delete + undo

  void _deleteTodo(Todo todo) {
    final provider = context.read<TodoProvider>();
    final index = provider.allTodos.indexWhere((t) => t.id == todo.id);
    provider.deleteTodo(todo.id);
    _showUndo('To-do deleted', () => provider.restoreTodo(todo, index));
  }

  void _deleteDailyTask(DailyTask task) {
    final provider = context.read<TodoProvider>();
    final index = provider.dailyTasks.indexWhere((t) => t.id == task.id);
    provider.deleteDailyTask(task.id);
    _showUndo(
        'Daily habit deleted', () => provider.restoreDailyTask(task, index));
  }

  void _showUndo(String message, VoidCallback onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
  }

  // ------------------------------------------------------------------ menu

  void _onMenu(_MenuAction action) {
    final provider = context.read<TodoProvider>();
    switch (action) {
      case _MenuAction.clearCompleted:
        _showClearCompletedDialog();
      case _MenuAction.system:
        provider.setThemeMode(ThemeMode.system);
      case _MenuAction.light:
        provider.setThemeMode(ThemeMode.light);
      case _MenuAction.dark:
        provider.setThemeMode(ThemeMode.dark);
      case _MenuAction.sunLocation:
        _toggleSunLocation();
    }
  }

  /// Opt in/out of using the device location for sunrise & sunset.
  Future<void> _toggleSunLocation() async {
    final sun = context.read<SunService>();
    if (sun.usesLocation) {
      await sun.useTimeZone();
      return;
    }
    final ok = await sun.useDeviceLocation();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location unavailable — sunrise and sunset stay based on your time zone',
          ),
        ),
      );
    }
  }

  /// Always present, so the top-bar controls never shift position.
  Widget _buildMenu(TodoProvider provider) {
    final mode = provider.themeMode;
    return PopupMenuButton<_MenuAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz),
      onSelected: _onMenu,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MenuAction.clearCompleted,
          enabled: provider.completedCount > 0,
          child: const ListTile(
            leading: Icon(Icons.delete_sweep_outlined),
            title: Text('Clear completed'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text('Appearance'),
        ),
        CheckedPopupMenuItem(
          value: _MenuAction.system,
          checked: mode == ThemeMode.system,
          child: const Text('Match system'),
        ),
        CheckedPopupMenuItem(
          value: _MenuAction.light,
          checked: mode == ThemeMode.light,
          child: const Text('Light'),
        ),
        CheckedPopupMenuItem(
          value: _MenuAction.dark,
          checked: mode == ThemeMode.dark,
          child: const Text('Dark'),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: _MenuAction.sunLocation,
          checked: context.read<SunService>().usesLocation,
          child: const Text('Sun times from my location'),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TodoProvider>();
    final query = provider.searchQuery.trim().toLowerCase();

    final todos = provider.todos; // already filtered + searched
    final dailyTasks = query.isEmpty
        ? provider.dailyTasks
        : provider.dailyTasks
            .where((t) =>
                t.title.toLowerCase().contains(query) ||
                t.description.toLowerCase().contains(query))
            .toList();

    final hasAnything = provider.totalCount > 0 || provider.dailyTotalCount > 0;
    final noSearchResults =
        query.isNotEmpty && todos.isEmpty && dailyTasks.isEmpty;

    // Space taken by the floating bottom bar (provided by MainNavigator's
    // Scaffold via extendBody).
    final barInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Tasks'),
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: [_buildMenu(provider)],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _greetingLine(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const StatsHeader(),
                _buildSunArc(theme),
                if (hasAnything) _buildSearchField(theme, provider),
              ],
            ),
          ),

          if (!provider.isLoaded)
            // Saved data still loading: show nothing rather than a
            // misleading "No tasks yet".
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (!hasAnything)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                icon: Icons.checklist_rounded,
                title: 'No tasks yet',
                message: 'Tap + to add a to-do or a daily habit',
              ),
            )
          else if (noSearchResults)
            SliverToBoxAdapter(
              child: _buildEmptyState(
                icon: Icons.search_off,
                title: 'No results',
                message: 'Nothing matches “${provider.searchQuery.trim()}”',
                padTop: 32,
              ),
            )
          else ...[
            // ---------------------------------------------- Daily Habits
            if (dailyTasks.isNotEmpty) ...[
              _sectionHeader(theme, 'Daily habits'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.builder(
                  itemCount: dailyTasks.length,
                  itemBuilder: (context, index) {
                    final task = dailyTasks[index];
                    return DailyTaskTile(
                      task: task,
                      onTap: () => _showEditDailyTaskSheet(task),
                      onToggle: () => provider.toggleDailyTask(task.id),
                      onDelete: () => _deleteDailyTask(task),
                    );
                  },
                ),
              ),
            ],

            // --------------------------------------------------- To-dos
            // The filter chips live with the list they actually filter.
            if (provider.totalCount > 0) ...[
              _sectionHeader(theme, 'To-dos'),
              SliverToBoxAdapter(child: _buildFilterChips(theme, provider)),
              if (todos.isEmpty)
                SliverToBoxAdapter(child: _buildFilteredEmpty(provider))
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  sliver: SliverList.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return TodoTile(
                        todo: todo,
                        onTap: () => _showEditTodoSheet(todo),
                        onToggle: () => provider.toggleTodo(todo.id),
                        onDelete: () => _deleteTodo(todo),
                      );
                    },
                  ),
                ),
            ],
          ],

          // Keep the last row clear of the floating bottom bar.
          SliverToBoxAdapter(child: SizedBox(height: barInset + 16)),
        ],
      ),
    );
  }

  /// The 24-hour sky circle (day above the horizon, night mirrored below),
  /// driven by today's real sunrise/sunset in local time.
  Widget _buildSunArc(ThemeData theme) {
    final sun = context.watch<SunService>();
    final basis = switch (sun.source) {
      SunSource.location => 'your location',
      SunSource.timeZone => 'your time zone',
      SunSource.estimate => 'an estimate from your time zone',
    };
    final noSunToday = sun.sunriseTime == null || sun.sunsetTime == null;

    return Tooltip(
      message: noSunToday
          ? "The sun doesn't rise or set here today; showing 6 AM to 6 PM."
          : 'Sunrise and sunset based on $basis. Change in the ⋯ menu.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: DayProgressArc(
          height: 200,
          arcThickness: 12,
          sunSize: 24,
          sunriseTime: sun.sunriseTime ?? const TimeOfDay(hour: 6, minute: 0),
          sunsetTime: sun.sunsetTime ?? const TimeOfDay(hour: 18, minute: 0),        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme, TodoProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: provider.setSearchQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: provider.searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    _searchController.clear();
                    provider.setSearchQuery('');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, TodoProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ['All', 'Active', 'Completed'].map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: provider.filter == filter,
              label: Text(filter),
              onSelected: (_) => provider.setFilter(filter),
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: theme.colorScheme.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Shown when to-dos exist but the current filter/search hides them all.
  Widget _buildFilteredEmpty(TodoProvider provider) {
    final query = provider.searchQuery.trim();
    final String title;
    final String message;
    if (query.isNotEmpty) {
      title = 'No matching to-dos';
      message = 'Nothing in ${provider.filter.toLowerCase()} matches “$query”';
    } else if (provider.filter == 'Active') {
      title = 'All done';
      message = 'Every to-do is completed';
    } else {
      title = 'No completed to-dos yet';
      message = 'Tick a to-do to see it here';
    }
    return _buildEmptyState(
      icon: provider.filter == 'Active'
          ? Icons.celebration_outlined
          : Icons.inbox_outlined,
      title: title,
      message: message,
      padTop: 24,
      compact: true,
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    double padTop = 0,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, padTop, 24, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 48 : 80,
              color: secondary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: (compact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCompletedDialog() {
    final count = context.read<TodoProvider>().completedCount;
    showDialog(
      context: context,
      builder: (ctx) {
        final error = Theme.of(ctx).colorScheme.error;
        return AlertDialog(
          title: const Text('Clear completed?'),
          content: Text(
            count == 1
                ? 'This permanently removes 1 completed to-do.'
                : 'This permanently removes $count completed to-dos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: error),
              onPressed: () {
                context.read<TodoProvider>().clearCompleted();
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }
}
