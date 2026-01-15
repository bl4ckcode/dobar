import 'package:equatable/equatable.dart';

class MenuExtraction extends Equatable {
  final double confidence;
  final List<ExtractedCategory> categories;
  final String rawText;
  final String currencyDetected;
  final String? extractionMethod;

  const MenuExtraction({
    required this.confidence,
    required this.categories,
    required this.rawText,
    required this.currencyDetected,
    this.extractionMethod,
  });

  factory MenuExtraction.fromJson(Map<String, dynamic> json) {
    return MenuExtraction(
      confidence: (json['confidence'] as num).toDouble(),
      categories: (json['categories'] as List)
          .map((c) => ExtractedCategory.fromJson(c))
          .toList(),
      rawText: json['raw_text'] ?? '',
      currencyDetected: json['currency_detected'] ?? 'BRL',
      extractionMethod: json['extraction_method'],
    );
  }

  int get totalItems => categories.fold(0, (sum, c) => sum + c.items.length);

  @override
  List<Object?> get props => [confidence, categories, rawText, currencyDetected, extractionMethod];
}

class ExtractedCategory extends Equatable {
  final String name;
  final List<ExtractedItem> items;

  const ExtractedCategory({
    required this.name,
    required this.items,
  });

  factory ExtractedCategory.fromJson(Map<String, dynamic> json) {
    return ExtractedCategory(
      name: json['name'] ?? 'Sem Categoria',
      items: (json['items'] as List?)
          ?.map((i) => ExtractedItem.fromJson(i))
          .toList() ?? [],
    );
  }

  ExtractedCategory copyWith({String? name, List<ExtractedItem>? items}) {
    return ExtractedCategory(
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [name, items];
}

class ExtractedItem extends Equatable {
  final String name;
  final double price;
  final String? description;
  final bool isSelected;

  const ExtractedItem({
    required this.name,
    required this.price,
    this.description,
    this.isSelected = true,
  });

  factory ExtractedItem.fromJson(Map<String, dynamic> json) {
    return ExtractedItem(
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'],
      isSelected: true,
    );
  }

  ExtractedItem copyWith({
    String? name,
    double? price,
    String? description,
    bool? isSelected,
  }) {
    return ExtractedItem(
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toMenuItemJson() {
    return {
      'name': name,
      'price': price,
      if (description != null) 'description': description,
    };
  }

  @override
  List<Object?> get props => [name, price, description, isSelected];
}
