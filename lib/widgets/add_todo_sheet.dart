import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_list/models/todo.dart';
import 'package:to_do_list/providers/todo_provider.dart';
import 'package:to_do_list/theme/app_theme.dart';

class AddTodoSheet extends StatefulWidget {
  final Todo? existingTodo;

  /// Optional Task / Daily habit switcher shown in place of the title
  /// when this sheet is hosted by NewItemSheet.
  final Widget? typeSwitcher;

  /// Optional shared title controller (owned by the caller), so text
  /// typed before switching type is kept.
  final TextEditingController? titleController;

  const AddTodoSheet({
    super.key,
    this.existingTodo,
    this.typeSwitcher,
    this.titleController,
  });

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late Priority _priority;
  DateTime? _dueDate; // the day (time part ignored)
  TimeOfDay? _dueTime; // optional time of day
  late String _category;

  bool get _isEditing => widget.existingTodo != null;

  final List<String> _categories = [
    'General',
    'Work',
    'Personal',
    'Shopping',
    'Health',
    'Study',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = widget.titleController ??
        TextEditingController(text: widget.existingTodo?.title ?? '');
    _titleController.addListener(_onTitleChanged);
    _descriptionController =
        TextEditingController(text: widget.existingTodo?.description ?? '');
    _priority = widget.existingTodo?.priority ?? Priority.medium;
    final existing = widget.existingTodo;
    _dueDate = existing?.dueDate;
    if (existing != null && existing.hasDueTime && existing.dueDate != null) {
      _dueTime = TimeOfDay.fromDateTime(existing.dueDate!);
    }
    _category = widget.existingTodo?.category ?? 'General';
  }

  void _onTitleChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    if (widget.titleController == null) _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// The due moment to store: the chosen day, at the chosen time if any.
  DateTime? get _combinedDue {
    final d = _dueDate;
    if (d == null) return null;
    final t = _dueTime;
    return t == null
        ? DateTime(d.year, d.month, d.day)
        : DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  void _saveTodo() {
    if (_titleController.text.trim().isEmpty) return;

    final provider = context.read<TodoProvider>();
    final due = _combinedDue;

    if (_isEditing) {
      provider.updateTodo(
        widget.existingTodo!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          dueDate: due,
          hasDueTime: due != null && _dueTime != null,
          clearDueDate: due == null,
          category: _category,
        ),
      );
    } else {
      provider.addTodo(
        Todo(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          dueDate: due,
          hasDueTime: due != null && _dueTime != null,
          category: _category,
        ),
      );
    }

    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      // Allow an already-past due date when editing an overdue to-do
      // (initialDate must not be before firstDate).
      firstDate: _dueDate != null && _dueDate!.isBefore(DateTime.now())
          ? _dueDate!
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
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
                Text(
                  _isEditing ? 'Edit to-do' : 'New to-do',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            const SizedBox(height: 20),

            // Task title field
            TextField(
              controller: _titleController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              // Return saves, like a quick-add field should.
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveTodo(),
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What needs to be done?',
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

            // Priority selector
            Text(
              'Priority',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: Priority.values.map((p) {
                final isSelected = _priority == p;
                final color = _priorityColor(p);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: p != Priority.high ? 8 : 0,
                    ),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(p.label),
                      selectedColor: color.withValues(alpha: 0.2),
                      // The coloured flag already marks the choice; a
                      // checkmark would be drawn on top of it.
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.flag,
                        color: isSelected
                            ? color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      onSelected: (_) => setState(() => _priority = p),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Category selector
            Text(
              'Category',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _categories.map((cat) {
                final isSelected = _category == cat;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(cat),
                  onSelected: (_) => setState(() => _category = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Due date picker
            InkWell(
              onTap: _pickDate,
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
                      Icons.calendar_today,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate != null
                          ? _formatDate(_dueDate!)
                          : 'Due date (optional)',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    if (_dueDate != null)
                      IconButton(
                        tooltip: 'Remove due date',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _dueDate = null;
                          _dueTime = null;
                        }),
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Optional time: timed to-dos get a "due in 15 min" and a
            // "due now" alert; all-day ones get a 9:00 "due today" alert.
            if (_dueDate != null) ...[
              const SizedBox(height: 12),
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
                      Icon(Icons.schedule, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dueTime != null
                              ? _dueTime!.format(context)
                              : 'Time (optional) · reminder at 9:00 AM',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      if (_dueTime != null)
                        IconButton(
                          tooltip: 'Remove time',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _dueTime = null),
                          icon: Icon(
                            Icons.close,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _titleController.text.trim().isEmpty
                    ? null
                    : _saveTodo,
                child: Text(
                  _isEditing ? 'Save' : 'Add to-do',
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

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Same format as the task rows: "3 Nov", plus the year if not this year.
  String _formatDate(DateTime d) {
    final base = '${d.day} ${_months[d.month - 1]}';
    return d.year == DateTime.now().year ? base : '$base ${d.year}';
  }

  // Same semantics as the task rows: high = error, medium = warning,
  // low = neutral.
  Color _priorityColor(Priority priority) {
    final scheme = Theme.of(context).colorScheme;
    switch (priority) {
      case Priority.high:
        return scheme.error;
      case Priority.medium:
        return AppTheme.warning(context);
      case Priority.low:
        return scheme.onSurfaceVariant;
    }
  }
}
