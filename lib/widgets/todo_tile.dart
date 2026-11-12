import 'package:flutter/material.dart';
import 'package:to_do_list/models/todo.dart';
import 'package:to_do_list/theme/app_theme.dart';
import 'package:to_do_list/widgets/completion_toggle.dart';

class TodoTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TodoTile({
    super.key,
    required this.todo,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Secondary text uses the theme's variant colour (meets 4.5:1),
    // not onSurface faded with opacity.
    final muted = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(todo.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: const SwipeDeleteBackground(),
        child: Card(
          child: InkWell(
            onTap: onTap,
            customBorder: AppTheme.continuous(AppTheme.radiusCard),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
              child: Row(
                children: [
                  CompletionToggle(
                    isCompleted: todo.isCompleted,
                    label: todo.title,
                    onToggle: onToggle,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: todo.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: todo.isCompleted
                                ? muted
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (todo.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            todo.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                        if (!todo.isCompleted) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _PriorityLabel(priority: todo.priority),
                              if (todo.dueDate != null)
                                _dueLabel(context, todo),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Today = warning (amber), overdue = error (red) with the real date,
  /// anything later = neutral.
  /// A timed to-do also shows its time ("Today · 5:30 PM") and turns
  /// overdue as soon as that time passes.
  Widget _dueLabel(BuildContext context, Todo todo) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dueDate = todo.dueDate!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final time = todo.hasDueTime
        ? ' · ${TimeOfDay.fromDateTime(dueDate).format(context)}'
        : '';

    final String text;
    final Color color;
    final IconData icon;
    if (todo.isOverdue(now)) {
      text = due == today
          ? 'Overdue$time'
          : 'Overdue · ${_formatDate(due, today)}$time';
      color = scheme.error;
      icon = Icons.error_outline;
    } else if (due == today) {
      text = 'Today$time';
      color = AppTheme.warning(context);
      icon = Icons.today_outlined;
    } else if (due == today.add(const Duration(days: 1))) {
      text = 'Tomorrow$time';
      color = scheme.onSurfaceVariant;
      icon = Icons.calendar_today_outlined;
    } else {
      text = '${_formatDate(due, today)}$time';
      color = scheme.onSurfaceVariant;
      icon = Icons.calendar_today_outlined;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date, DateTime today) {
    final base = '${date.day} ${_months[date.month - 1]}';
    return date.year == today.year ? base : '$base ${date.year}';
  }
}

/// Priority shown as icon + text, so it never relies on colour alone.
/// Low priority stays neutral; only medium/high draw attention.
class _PriorityLabel extends StatelessWidget {
  final Priority priority;

  const _PriorityLabel({required this.priority});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (IconData icon, Color color) = switch (priority) {
      Priority.high => (Icons.priority_high, scheme.error),
      Priority.medium => (Icons.flag_outlined, AppTheme.warning(context)),
      Priority.low => (Icons.outlined_flag, scheme.onSurfaceVariant),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          priority.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
