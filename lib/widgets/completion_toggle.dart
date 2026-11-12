import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:to_do_list/theme/app_theme.dart';

/// Round "done" checkbox used by task rows.
///
/// The visible circle is 28px, but the tap target is 48x48 (Apple's
/// minimum is 44pt) so it is easy to hit without opening the row's
/// edit sheet. It highlights on press, gives a light haptic when a task
/// is completed, and is announced to screen readers as a checkbox.
class CompletionToggle extends StatelessWidget {
  final bool isCompleted;
  final String label;
  final VoidCallback onToggle;

  const CompletionToggle({
    super.key,
    required this.isCompleted,
    required this.label,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      checked: isCompleted,
      label: label,
      onTapHint: isCompleted ? 'mark as not done' : 'mark as done',
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            radius: 24,
            onTap: () {
              if (!isCompleted) HapticFeedback.lightImpact();
              onToggle();
            },
            child: Center(
              child: AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 120), // frequent → quick
                curve: Curves.easeOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isCompleted ? scheme.primary : scheme.outline,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? Icon(Icons.check, size: 18, color: scheme.onPrimary)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Red background revealed behind a row while swiping to delete.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(4), // matches Card's default margin
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: ShapeDecoration(
        color: scheme.error,
        shape: AppTheme.continuous(AppTheme.radiusCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete',
            style: TextStyle(
              color: scheme.onError,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.delete_outline, color: scheme.onError),
        ],
      ),
    );
  }
}
