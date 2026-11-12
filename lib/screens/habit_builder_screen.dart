import 'package:flutter/material.dart';
import 'package:to_do_list/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:to_do_list/models/habit.dart';
import 'package:to_do_list/providers/todo_provider.dart';

class HabitBuilderScreen extends StatelessWidget {
  const HabitBuilderScreen({super.key});

  /// Opened from the + island in the bottom bar.
  static void showAddHabitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddHabitSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<TodoProvider>().habits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Builder'),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => context.read<TodoProvider>().toggleTheme(),
          ),
        ],
      ),
      body: habits.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              // Bottom padding clears the floating bottom bar.
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
              itemCount: habits.length,
              itemBuilder: (context, index) {
                return HabitCard(habit: habits[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_graph_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Build Better Habits',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a habit to start tracking your progress',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}

class HabitCard extends StatelessWidget {
  final Habit habit;

  const HabitCard({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title and Progress
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (habit.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          habit.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${habit.targetCount} ${habit.durationType.label}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Progress Circle
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: habit.isCompleted
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: habit.progressPercentage / 100,
                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        color: theme.colorScheme.primary,
                        strokeWidth: 4,
                      ),
                      Text(
                        '${habit.progressPercentage.toInt()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  onSelected: (value) {
                    if (value == 'delete') {
                      context.read<TodoProvider>().deleteHabit(habit.id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete,
                              color: theme.colorScheme.error, size: 20),
                          const SizedBox(width: 8),
                          Text('Delete Habit',
                              style: TextStyle(color: theme.colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),

          // Checkboxes Grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(habit.targetCount, (index) {
                final isCompleted = habit.completionStatus[index];
                final currentIntervalIndex = habit.getCurrentIntervalIndex();
                final isMissed = habit.isMissed(index);
                final isCurrent = habit.isCurrent(index);
                final isLockedFuture = habit.isLockedFuture(index);

                return GestureDetector(
                  onTap: isCurrent
                      ? () {
                          context.read<TodoProvider>().toggleHabitCompletion(habit.id, index);
                        }
                      : () {
                          // Show a brief explanation of why it's locked
                          ScaffoldMessenger.of(context).clearSnackBars();
                          String message;
                          if (isMissed) {
                            message = 'This time slot was missed.';
                          } else if (isLockedFuture) {
                            message = 'This box unlocks in ${index - currentIntervalIndex} ${habit.durationType.label.toLowerCase()}';
                          } else if (isCompleted) {
                            message = 'Already completed.';
                          } else {
                            message = 'Locked.';
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? theme.colorScheme.primary
                          : isMissed
                              ? theme.colorScheme.error.withValues(alpha: 0.15)
                              : (isCurrent
                                  ? theme.scaffoldBackgroundColor
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.05)),
                      border: Border.all(
                        color: isCompleted
                            ? theme.colorScheme.primary
                            : isMissed
                                ? theme.colorScheme.error
                                : (isCurrent
                                    ? AppTheme.warning(context)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.1)),
                        width: isCurrent && !isCompleted ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isCompleted
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : (isMissed
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  )
                                ]
                              : null),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLockedFuture)
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          )
                        else
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCompleted
                                  ? theme.colorScheme.onPrimary
                                  : isMissed
                                      ? theme.colorScheme.error
                                      : (isCurrent
                                          ? AppTheme.warning(context)
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ),
                        if (isCompleted)
                          Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                        if (isMissed && !isCompleted)
                          Icon(
                            Icons.close,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class AddHabitSheet extends StatefulWidget {
  const AddHabitSheet({super.key});

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<AddHabitSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController(text: '7');
  HabitDurationType _durationType = HabitDurationType.days;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _saveHabit() {
    if (_titleController.text.trim().isEmpty) return;

    final targetCount = int.tryParse(_targetController.text) ?? 7;
    if (targetCount <= 0 || targetCount > 365) return; // Basic validation

    context.read<TodoProvider>().addHabit(
      Habit(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        targetCount: targetCount,
        durationType: _durationType,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: AppTheme.sheetDecoration(theme.scaffoldBackgroundColor),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Build a New Habit',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                hintText: 'e.g., Read a book, Drink water...',
                prefixIcon: Icon(Icons.auto_graph),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Why are you building this habit?',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Target Duration',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Count',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SegmentedButton<HabitDurationType>(
                    segments: const [
                      ButtonSegment(
                        value: HabitDurationType.days,
                        label: Text('Days'),
                      ),
                      ButtonSegment(
                        value: HabitDurationType.hours,
                        label: Text('Hours'),
                      ),
                    ],
                    selected: {_durationType},
                    onSelectionChanged: (Set<HabitDurationType> newSelection) {
                      setState(() => _durationType = newSelection.first);
                    },
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _titleController.text.trim().isEmpty ? null : _saveHabit,
                child: const Text(
                  'Create Habit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
