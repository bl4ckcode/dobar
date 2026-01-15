import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class MenuReaderEvent extends Equatable {
  const MenuReaderEvent();
  @override
  List<Object?> get props => [];
}

class ExtractMenuFromImage extends MenuReaderEvent {
  final File imageFile;
  final int barId;
  final String? languageHint;

  const ExtractMenuFromImage({
    required this.imageFile,
    required this.barId,
    this.languageHint,
  });

  @override
  List<Object?> get props => [imageFile.path, barId, languageHint];
}

class ExtractMenuFromUrl extends MenuReaderEvent {
  final String menuUrl;
  final int barId;
  final String? languageHint;

  const ExtractMenuFromUrl({
    required this.menuUrl,
    required this.barId,
    this.languageHint,
  });

  @override
  List<Object?> get props => [menuUrl, barId, languageHint];
}

class ToggleItemSelection extends MenuReaderEvent {
  final int categoryIndex;
  final int itemIndex;

  const ToggleItemSelection({
    required this.categoryIndex,
    required this.itemIndex,
  });

  @override
  List<Object?> get props => [categoryIndex, itemIndex];
}

class UpdateItemDetails extends MenuReaderEvent {
  final int categoryIndex;
  final int itemIndex;
  final String? name;
  final double? price;
  final String? description;

  const UpdateItemDetails({
    required this.categoryIndex,
    required this.itemIndex,
    this.name,
    this.price,
    this.description,
  });

  @override
  List<Object?> get props => [categoryIndex, itemIndex, name, price, description];
}

class UpdateCategoryName extends MenuReaderEvent {
  final int categoryIndex;
  final String name;

  const UpdateCategoryName({
    required this.categoryIndex,
    required this.name,
  });

  @override
  List<Object?> get props => [categoryIndex, name];
}

class SaveExtractedItems extends MenuReaderEvent {
  final int barId;

  const SaveExtractedItems({required this.barId});

  @override
  List<Object?> get props => [barId];
}

class ResetMenuReader extends MenuReaderEvent {}
