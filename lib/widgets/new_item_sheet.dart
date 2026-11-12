import 'package:flutter/material.dart';
import 'package:to_do_list/widgets/add_daily_task_sheet.dart';
import 'package:to_do_list/widgets/add_todo_sheet.dart';

enum NewItemType { task, dailyHabit }

/// One sheet for creating anything from the + button.
///
/// It opens straight on the regular task form (the common path), with a
/// Task / Daily habit switch at the top instead of a separate chooser
/// sheet. The title typed so far is kept when switching.
class NewItemSheet extends StatefulWidget {
  const NewItemSheet({super.key});

  @override
  State<NewItemSheet> createState() => _NewItemSheetState();
}

class _NewItemSheetState extends State<NewItemSheet> {
  final _titleController = TextEditingController();
  NewItemType _type = NewItemType.task;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Widget _switcher() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<NewItemType>(
        segments: const [
          ButtonSegment(
            value: NewItemType.task,
            label: Text('To-do'),
            icon: Icon(Icons.task_alt),
          ),
          ButtonSegment(
            value: NewItemType.dailyHabit,
            label: Text('Daily habit'),
            icon: Icon(Icons.repeat),
          ),
        ],
        selected: {_type},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _type = s.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    return AnimatedSize(
      duration: duration,
      curve: const Cubic(0.23, 1, 0.32, 1), // strong ease-out
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: const Cubic(0.23, 1, 0.32, 1),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, if (current != null) current],
        ),
        child: _type == NewItemType.task
            ? AddTodoSheet(
                key: const ValueKey(NewItemType.task),
                typeSwitcher: _switcher(),
                titleController: _titleController,
              )
            : AddDailyTaskSheet(
                key: const ValueKey(NewItemType.dailyHabit),
                typeSwitcher: _switcher(),
                titleController: _titleController,
              ),
      ),
    );
  }
}
