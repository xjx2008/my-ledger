class Category {
  final int? id;
  final String name;
  final String type; // 'expense' or 'income'
  final int colorValue;
  final String icon;
  final int sortOrder;
  final int isPreset;

  const Category({
    this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    required this.icon,
    this.sortOrder = 0,
    this.isPreset = 0,
  });

  Category copyWith({
    int? id,
    String? name,
    String? type,
    int? colorValue,
    String? icon,
    int? sortOrder,
    int? isPreset,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'color': colorValue,
        'icon': icon,
        'sort_order': sortOrder,
        'is_preset': isPreset,
      };

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String,
        colorValue: map['color'] as int,
        icon: map['icon'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        isPreset: (map['is_preset'] as int?) ?? 0,
      );
}

class RecordItem {
  final int? id;
  final int amountCents; // 金额，单位：分（整数，避免浮点误差）
  final String type; // 'expense' or 'income'
  final int categoryId;
  final String note;
  final String payment; // 支付方式 id：wechat / alipay / card / cash / other
  final DateTime date;
  final DateTime createdAt;

  const RecordItem({
    this.id,
    required this.amountCents,
    required this.type,
    required this.categoryId,
    this.note = '',
    this.payment = 'wechat',
    required this.date,
    required this.createdAt,
  });

  RecordItem copyWith({
    int? id,
    int? amountCents,
    String? type,
    int? categoryId,
    String? note,
    String? payment,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return RecordItem(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      payment: payment ?? this.payment,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'amount_cents': amountCents,
        'type': type,
        'category_id': categoryId,
        'note': note,
        'payment': payment,
        'date': date.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory RecordItem.fromMap(Map<String, Object?> map) => RecordItem(
        id: map['id'] as int?,
        amountCents: map['amount_cents'] as int,
        type: map['type'] as String,
        categoryId: map['category_id'] as int,
        note: (map['note'] as String?) ?? '',
        payment: (map['payment'] as String?) ?? 'wechat',
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class Summary {
  final int expenseCents;
  final int incomeCents;

  const Summary({required this.expenseCents, required this.incomeCents});

  int get balanceCents => incomeCents - expenseCents;
}

class CategoryTotal {
  final Category category;
  final int totalCents;

  const CategoryTotal({required this.category, required this.totalCents});
}
