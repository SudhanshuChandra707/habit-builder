import 'package:flutter/material.dart';
import 'package:to_do_list/models/daily_task.dart';
import 'package:to_do_list/theme/app_theme.dart';
import 'package:to_do_list/widgets/completion_toggle.dart';

class DailyTaskTile extends StatelessWidget {
  final DailyTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const DailyTaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(task.id),
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
                    isCompleted: task.isCompletedToday,
                    label: '${task.title}, daily',
                    onToggle: onToggle,
                  ),
                  const SizedBox(width: 8),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: task.isCompletedToday
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompletedToday
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              decoration: task.isCompletedToday
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              task.reminderEnabled
                                  ? Icons.alarm
                                  : Icons.alarm_off,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.reminderEnabled
                                  ? _formatTime(task.reminderTime)
                                  : '${_formatTime(task.reminderTime)} · reminder off',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Repeat icon: neutral, the accent is reserved for state
                  Icon(
                    Icons.repeat,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                    semanticLabel: 'Repeats daily',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
