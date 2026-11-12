import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_list/models/todo.dart';
import 'package:to_do_list/models/daily_task.dart';
import 'package:to_do_list/models/habit.dart';
import 'package:to_do_list/models/collection.dart';
import 'package:to_do_list/services/notification_service.dart';
import 'package:to_do_list/widgets/celebration.dart';

class TodoProvider extends ChangeNotifier {
  List<Todo> _todos = [];
  List<DailyTask> _dailyTasks = [];
  List<Habit> _habits = [];
  List<Collection> _collections = [];
  String _filter = 'All';
  String _searchQuery = '';
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoaded = false;

  static const String _todosKey = 'todos';
  static const String _dailyTasksKey = 'daily_tasks';
  static const String _habitsKey = 'habits';
  static const String _collectionsKey = 'collections';
  static const String _themeKey = 'theme_mode';

  List<Todo> get todos => _filteredTodos;
  List<Todo> get allTodos => List.unmodifiable(_todos);
  List<DailyTask> get dailyTasks => List.unmodifiable(_dailyTasks);
  List<Habit> get habits => List.unmodifiable(_habits);
  List<Collection> get collections => List.unmodifiable(_collections);
  String get filter => _filter;
  String get searchQuery => _searchQuery;
  ThemeMode get themeMode => _themeMode;

  /// False until saved data has been read, so screens don't flash an
  /// empty state on cold start.
  bool get isLoaded => _isLoaded;

  int get totalCount => _todos.length;
  int get completedCount => _todos.where((t) => t.isCompleted).length;
  int get pendingCount => _todos.where((t) => !t.isCompleted).length;
  int get dailyCompletedCount => _dailyTasks.where((t) => t.isCompletedToday).length;
  int get dailyTotalCount => _dailyTasks.length;
  int get overdueCount {
    final now = DateTime.now();
    return _todos.where((t) => t.isOverdue(now)).length;
  }

  /// Whether dark mode is what the user actually sees right now,
  /// including when the app is following the system appearance.
  bool get isDarkActive {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  List<Todo> get _filteredTodos {
    var filtered = List<Todo>.from(_todos);

    // Apply filter
    switch (_filter) {
      case 'Active':
        filtered = filtered.where((t) => !t.isCompleted).toList();
        break;
      case 'Completed':
        filtered = filtered.where((t) => t.isCompleted).toList();
        break;
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) =>
              t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort: incomplete first, then by priority (high to low), then by date
    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (a.priority != b.priority) {
        return b.priority.index.compareTo(a.priority.index);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  // Load todos from local storage
  Future<void> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    // Load todos
    final todosJson = prefs.getString(_todosKey);
    if (todosJson != null) {
      final List<dynamic> decoded = jsonDecode(todosJson);
      _todos = decoded.map((json) => Todo.fromJson(json)).toList();
    }

    // Load daily tasks
    final dailyTasksJson = prefs.getString(_dailyTasksKey);
    if (dailyTasksJson != null) {
      final List<dynamic> decoded = jsonDecode(dailyTasksJson);
      _dailyTasks = decoded.map((json) => DailyTask.fromJson(json)).toList();

      // Reset daily tasks if it's a new day
      for (var task in _dailyTasks) {
        task.checkAndResetDaily();
      }
    }

    // Load habits
    final habitsJson = prefs.getString(_habitsKey);
    if (habitsJson != null) {
      final List<dynamic> decoded = jsonDecode(habitsJson);
      _habits = decoded.map((json) => Habit.fromJson(json)).toList();
    }

    // Load collections
    final collectionsJson = prefs.getString(_collectionsKey);
    if (collectionsJson != null) {
      final List<dynamic> decoded = jsonDecode(collectionsJson);
      _collections = decoded.map((json) => Collection.fromJson(json)).toList();
    }

    _isLoaded = true;
    notifyListeners();

    // Rebuild every alert in the device's time zone (clears stale ones).
    final notifications = NotificationService();
    unawaited(notifications.rescheduleAll(
      todos: _todos,
      dailyTasks: _dailyTasks,
      habits: _habits,
    ));

    // "Mark done" from a notification: the one that launched the app, and
    // any tapped while it's running.
    final launch = notifications.takeLaunchIntent();
    if (launch != null) handleNotificationIntent(launch);
    _intentSubscription ??=
        notifications.intents.listen(handleNotificationIntent);
  }

  StreamSubscription<NotificationIntent>? _intentSubscription;

  /// Applies a notification's "Mark done" button to the right item.
  void handleNotificationIntent(NotificationIntent intent) {
    if (!intent.markDone) return;
    switch (intent.kind) {
      case 'todo':
        final todo = _todos.where((t) => t.id == intent.id).firstOrNull;
        if (todo != null && !todo.isCompleted) toggleTodo(todo.id);
      case 'daily':
        final task = _dailyTasks.where((t) => t.id == intent.id).firstOrNull;
        if (task != null && !task.isCompletedToday) toggleDailyTask(task.id);
      case 'habit':
        final habit = _habits.where((h) => h.id == intent.id).firstOrNull;
        final index = intent.index;
        if (habit != null &&
            index != null &&
            index >= 0 &&
            index < habit.completionStatus.length &&
            !habit.completionStatus[index]) {
          toggleHabitCompletion(habit.id, index);
        }
    }
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  // Save todos to local storage
  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = jsonEncode(_todos.map((t) => t.toJson()).toList());
    await prefs.setString(_todosKey, todosJson);
  }

  // Save daily tasks to local storage
  Future<void> _saveDailyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final dailyTasksJson = jsonEncode(_dailyTasks.map((t) => t.toJson()).toList());
    await prefs.setString(_dailyTasksKey, dailyTasksJson);
  }

  // Add a new todo
  void addTodo(Todo todo) {
    _todos.add(todo);
    _saveTodos();
    NotificationService().scheduleTodoReminder(todo);
    notifyListeners();
  }

  // Update an existing todo
  void updateTodo(Todo updatedTodo) {
    final index = _todos.indexWhere((t) => t.id == updatedTodo.id);
    if (index != -1) {
      _todos[index] = updatedTodo;
      _saveTodos();
      NotificationService().scheduleTodoReminder(updatedTodo);
      notifyListeners();
    }
  }

  // Delete a todo
  void deleteTodo(String id) {
    _todos.removeWhere((t) => t.id == id);
    _saveTodos();
    NotificationService().cancelNotification(id);
    notifyListeners();
  }

  // Put a deleted todo back (used by Undo)
  void restoreTodo(Todo todo, int index) {
    if (_todos.any((t) => t.id == todo.id)) return;
    _todos.insert(index.clamp(0, _todos.length), todo);
    _saveTodos();
    if (!todo.isCompleted) {
      NotificationService().scheduleTodoReminder(todo);
    }
    notifyListeners();
  }

  // Toggle completion status
  void toggleTodo(String id) {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      _todos[index].isCompleted = !_todos[index].isCompleted;
      _saveTodos();
      if (_todos[index].isCompleted) {
        Celebration.fire('todo:$id');
        NotificationService().cancelNotification(id);
      } else {
        NotificationService().scheduleTodoReminder(_todos[index]);
      }
      notifyListeners();
    }
  }

  // Set filter
  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  // Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Set appearance: follow the system, or force light/dark
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners(); // update the UI immediately, persist afterwards
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
  }

  // Flip whatever appearance is currently on screen
  void toggleTheme() {
    setThemeMode(isDarkActive ? ThemeMode.light : ThemeMode.dark);
  }

  // Clear completed todos
  void clearCompleted() {
    for (var t in _todos.where((t) => t.isCompleted)) {
      NotificationService().cancelNotification(t.id);
    }
    _todos.removeWhere((t) => t.isCompleted);
    _saveTodos();
    notifyListeners();
  }

  // Daily task methods
  void addDailyTask(DailyTask task) {
    _dailyTasks.add(task);
    _saveDailyTasks();
    NotificationService().scheduleDailyTaskReminder(task);
    notifyListeners();
  }

  void updateDailyTask(DailyTask updatedTask) {
    final index = _dailyTasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _dailyTasks[index] = updatedTask;
      _saveDailyTasks();
      NotificationService().scheduleDailyTaskReminder(updatedTask);
      notifyListeners();
    }
  }

  void deleteDailyTask(String id) {
    _dailyTasks.removeWhere((t) => t.id == id);
    _saveDailyTasks();
    NotificationService().cancelNotification(id);
    notifyListeners();
  }

  // Put a deleted daily task back (used by Undo)
  void restoreDailyTask(DailyTask task, int index) {
    if (_dailyTasks.any((t) => t.id == task.id)) return;
    _dailyTasks.insert(index.clamp(0, _dailyTasks.length), task);
    _saveDailyTasks();
    NotificationService().scheduleDailyTaskReminder(task);
    notifyListeners();
  }

  void toggleDailyTask(String id) {
    final index = _dailyTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _dailyTasks[index].isCompletedToday = !_dailyTasks[index].isCompletedToday;
      if (_dailyTasks[index].isCompletedToday) {
        _dailyTasks[index].lastCompletedDate = DateTime.now();
        Celebration.fire('daily:$id');
      }
      // Keeps the daily repeat; skips today's alerts once it's done.
      NotificationService().scheduleDailyTaskReminder(_dailyTasks[index]);
      _saveDailyTasks();
      notifyListeners();
    }
  }

  // Save habits to local storage
  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = jsonEncode(_habits.map((h) => h.toJson()).toList());
    await prefs.setString(_habitsKey, habitsJson);
  }

  // Habit methods
  void addHabit(Habit habit) {
    _habits.add(habit);
    _saveHabits();
    NotificationService().scheduleHabitReminder(habit);
    notifyListeners();
  }

  void updateHabit(Habit updatedHabit) {
    final index = _habits.indexWhere((h) => h.id == updatedHabit.id);
    if (index != -1) {
      _habits[index] = updatedHabit;
      _saveHabits();
      NotificationService().scheduleHabitReminder(updatedHabit);
      notifyListeners();
    }
  }

  void deleteHabit(String id) {
    _habits.removeWhere((h) => h.id == id);
    _saveHabits();
    NotificationService().cancelNotification(id);
    notifyListeners();
  }

  void toggleHabitCompletion(String habitId, int index) {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex != -1) {
      final wasComplete = _habits[habitIndex].isCompleted;
      _habits[habitIndex].toggleCompletion(index);
      // Only the whole habit finishing (e.g. day 21 of 21) celebrates.
      if (!wasComplete && _habits[habitIndex].isCompleted) {
        Celebration.fire('habit:$habitId');
      }
      _saveHabits();
      NotificationService().scheduleHabitReminder(_habits[habitIndex]);
      notifyListeners();
    }
  }

  // Save collections to local storage
  Future<void> _saveCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionsJson = jsonEncode(_collections.map((c) => c.toJson()).toList());
    await prefs.setString(_collectionsKey, collectionsJson);
  }

  // Collection methods
  void addCollection(Collection collection) {
    _collections.add(collection);
    _saveCollections();
    notifyListeners();
  }

  void updateCollection(Collection updatedCollection) {
    final index = _collections.indexWhere((c) => c.id == updatedCollection.id);
    if (index != -1) {
      _collections[index] = updatedCollection;
      _saveCollections();
      notifyListeners();
    }
  }

  void deleteCollection(String id) {
    _collections.removeWhere((c) => c.id == id);
    _saveCollections();
    notifyListeners();
  }

  void toggleCollectionItem(String collectionId, String itemId) {
    final collectionIndex = _collections.indexWhere((c) => c.id == collectionId);
    if (collectionIndex != -1) {
      final itemIndex = _collections[collectionIndex].items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        final currentStatus = _collections[collectionIndex].items[itemIndex].isCompleted;
        _collections[collectionIndex].items[itemIndex].isCompleted = !currentStatus;
        _saveCollections();
        notifyListeners();
      }
    }
  }

  void addCollectionItem(String collectionId, CollectionItem item) {
    final collectionIndex = _collections.indexWhere((c) => c.id == collectionId);
    if (collectionIndex != -1) {
      _collections[collectionIndex].items.add(item);
      _saveCollections();
      notifyListeners();
    }
  }

  void deleteCollectionItem(String collectionId, String itemId) {
    final collectionIndex = _collections.indexWhere((c) => c.id == collectionId);
    if (collectionIndex != -1) {
      _collections[collectionIndex].items.removeWhere((i) => i.id == itemId);
      _saveCollections();
      notifyListeners();
    }
  }
}
