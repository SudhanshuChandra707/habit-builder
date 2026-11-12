import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_list/models/daily_task.dart';
import 'package:to_do_list/providers/todo_provider.dart';
import 'package:to_do_list/services/clock_service.dart';
import 'package:to_do_list/theme/app_theme.dart';

class AddDailyTaskSheet extends StatefulWidget {
  final DailyTask? existingTask;

  /// Optional Task / Daily habit switcher shown in place of the title
  /// when this sheet is hosted by NewItemSheet.
  final Widget? typeSwitcher;

  /// Optional shared title controller (owned by the caller), so text
  /// typed before switching type is kept.
  final TextEditingController? titleController;

  const AddDailyTaskSheet({
    super.key,
    this.existingTask,
    this.typeSwitcher,
    this.titleController,
  });

  @override
  State<AddDailyTaskSheet> createState() => _AddDailyTaskSheetState();
}

class _AddDailyTaskSheetState extends State<AddDailyTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TimeOfDay _reminderTime;
  late bool _reminderEnabled;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _titleController = widget.titleController ??
        TextEditingController(text: widget.existingTask?.title ?? '');
    _titleController.addListener(_onTitleChanged);
    _descriptionController = TextEditingController(text: widget.existingTask?.description ?? '');
    _reminderTime = widget.existingTask?.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
    _reminderEnabled = widget.existingTask?.reminderEnabled ?? true;
  }

  void _onTitleChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    if (widget.titleController == null) _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) return;

    final provider = context.read<TodoProvider>();

    if (_isEditing) {
      provider.updateDailyTask(
        widget.existingTask!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          reminderTime: _reminderTime,
          reminderEnabled: _reminderEnabled,
        ),
      );
    } else {
      provider.addDailyTask(
        DailyTask(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          reminderTime: _reminderTime,
          reminderEnabled: _reminderEnabled,
        ),
      );
    }

    Navigator.pop(context);
  }

  Future<void> _addClockAlarm() async {
    final title = _titleController.text.trim();
    final ok = await ClockService.addDailyAlarm(
      time: _reminderTime,
      label: title.isEmpty ? 'Daily habit' : title,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Clock app found to set the alarm')),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
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
            // Drag handle
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
            const SizedBox(height: 20),

            // Title
            widget.typeSwitcher ??
            Row(
              children: [
                Icon(Icons.repeat, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Edit daily habit' : 'New daily habit',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Task title field
            TextField(
              controller: _titleController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveTask(),
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What do you want to do daily?',
                prefixIcon: Icon(Icons.task_alt),
              ),
            ),
            const SizedBox(height: 16),

            // Description field
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add some details',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // Reminder time picker
            Text(
              'Reminder time',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatTime(_reminderTime),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Every day',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Enable reminder toggle
            SwitchListTile(
              value: _reminderEnabled,
              onChanged: (value) => setState(() => _reminderEnabled = value),
              title: const Text('Enable reminder'),
              subtitle: const Text('Alert at this time, and a nudge an hour later if not done'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: theme.colorScheme.primary,
            ),

            // Hand a real, repeating alarm to the phone's Clock app.
            if (ClockService.isSupported) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addClockAlarm,
                  icon: const Icon(Icons.alarm_add),
                  label: const Text('Add alarm to Clock app'),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _titleController.text.trim().isEmpty ? null : _saveTask,
                child: Text(
                  _isEditing ? 'Save' : 'Add daily habit',
                  style: const TextStyle(
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
