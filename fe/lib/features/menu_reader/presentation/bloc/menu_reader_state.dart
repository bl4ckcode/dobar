import 'package:equatable/equatable.dart';
import 'package:barz/features/menu_reader/domain/models/menu_extraction.dart';

enum MenuReaderStatus {
  initial,
  extracting,
  extracted,
  editing,
  saving,
  saved,
  error,
}

class MenuReaderState extends Equatable {
  final MenuReaderStatus status;
  final MenuExtraction? extraction;
  final List<ExtractedCategory> editableCategories;
  final String? errorMessage;
  final double? confidence;

  const MenuReaderState({
    this.status = MenuReaderStatus.initial,
    this.extraction,
    this.editableCategories = const [],
    this.errorMessage,
    this.confidence,
  });

  int get selectedItemCount {
    int count = 0;
    for (final category in editableCategories) {
      count += category.items.where((i) => i.isSelected).length;
    }
    return count;
  }

  int get totalItemCount {
    int count = 0;
    for (final category in editableCategories) {
      count += category.items.length;
    }
    return count;
  }

  MenuReaderState copyWith({
    MenuReaderStatus? status,
    MenuExtraction? extraction,
    List<ExtractedCategory>? editableCategories,
    String? errorMessage,
    double? confidence,
  }) {
    return MenuReaderState(
      status: status ?? this.status,
      extraction: extraction ?? this.extraction,
      editableCategories: editableCategories ?? this.editableCategories,
      errorMessage: errorMessage,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  List<Object?> get props => [
    status,
    extraction,
    editableCategories,
    errorMessage,
    confidence,
  ];
}
