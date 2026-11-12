import 'package:uuid/uuid.dart';

class CollectionItem {
  final String id;
  String text;
  bool isCompleted;

  CollectionItem({
    String? id,
    required this.text,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  CollectionItem copyWith({
    String? text,
    bool? isCompleted,
  }) {
    return CollectionItem(
      id: id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as String,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class Collection {
  final String id;
  String title;
  List<CollectionItem> items;
  DateTime createdAt;

  Collection({
    String? id,
    required this.title,
    List<CollectionItem>? items,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        items = items ?? [],
        createdAt = createdAt ?? DateTime.now();

  Collection copyWith({
    String? title,
    List<CollectionItem>? items,
  }) {
    return Collection(
      id: id,
      title: title ?? this.title,
      items: items ?? List.from(this.items),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  int get completedCount => items.where((i) => i.isCompleted).length;
  int get totalCount => items.length;
  double get progress => totalCount > 0 ? completedCount / totalCount : 0.0;
}
