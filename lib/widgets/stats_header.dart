import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_list/providers/todo_provider.dart';

/// One-line, labelled summary of the day: "3 to do · 1 overdue · 2 done ·
/// Habits 1/4". Every number says what it counts, colour is only used to
/// flag what needs attention (overdue), and habits are included.
class StatsHeader extends StatelessWidget {
  const StatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final strong = base?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final parts = <InlineSpan>[];
    void add(String number, String label, {Color? color}) {
      if (parts.isNotEmpty) parts.add(const TextSpan(text: '  ·  '));
      parts.add(TextSpan(
        text: number,
        style: color == null ? strong : strong?.copyWith(color: color),
      ));
      parts.add(TextSpan(
        text: ' $label',
        style: color == null ? null : base?.copyWith(color: color),
      ));
    }

    if (provider.totalCount > 0) {
      add('${provider.pendingCount}', 'to do');
      if (provider.overdueCount > 0) {
        add('${provider.overdueCount}', 'overdue', color: scheme.error);
      }
      add('${provider.completedCount}', 'done');
    }
    if (provider.dailyTotalCount > 0) {
      add('${provider.dailyCompletedCount}/${provider.dailyTotalCount}',
          provider.dailyTotalCount == 1 ? 'habit' : 'habits');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text.rich(TextSpan(style: base, children: parts)),
    );
  }
}
