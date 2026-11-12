import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_list/models/collection.dart';
import 'package:to_do_list/providers/todo_provider.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final _itemController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _itemController.text.trim();
    if (text.isNotEmpty) {
      context.read<TodoProvider>().addCollectionItem(
            widget.collectionId,
            CollectionItem(text: text),
          );
      _itemController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use select so it rebuilds when items change
    final collection = context.select<TodoProvider, Collection?>((p) {
      try {
        return p.collections.firstWhere((c) => c.id == widget.collectionId);
      } catch (e) {
        return null; // Collection was probably deleted
      }
    });

    if (collection == null) {
      return const Scaffold(body: Center(child: Text('Collection not found')));
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<TodoProvider>().deleteCollection(collection.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar header
          if (collection.items.isNotEmpty)
            LinearProgressIndicator(
              value: collection.progress,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              color: theme.colorScheme.primary,
              minHeight: 4,
            ),

          // Items list
          Expanded(
            child: collection.items.isEmpty
                ? Center(
                    child: Text(
                      'No items yet. Add one below!',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: collection.items.length,
                    itemBuilder: (context, index) {
                      final item = collection.items[index];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          context.read<TodoProvider>().deleteCollectionItem(collection.id, item.id);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: theme.colorScheme.error,
                          child: Icon(Icons.delete, color: theme.colorScheme.onError),
                        ),
                        child: CheckboxListTile(
                          value: item.isCompleted,
                          onChanged: (_) {
                            context.read<TodoProvider>().toggleCollectionItem(collection.id, item.id);
                          },
                          title: Text(
                            item.text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              color: item.isCompleted
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                  : null,
                            ),
                          ),
                          activeColor: theme.colorScheme.primary,
                          checkColor: theme.colorScheme.onPrimary,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      );
                    },
                  ),
          ),

          // Add item bottom area
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Add new item...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _addItem,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
