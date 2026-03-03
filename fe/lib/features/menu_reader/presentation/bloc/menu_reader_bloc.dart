import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/menu_reader/domain/models/menu_extraction.dart';
import 'package:barz/features/menu_reader/domain/repositories/menu_reader_repository.dart';
import 'menu_reader_event.dart';
import 'menu_reader_state.dart';

class MenuReaderBloc extends Bloc<MenuReaderEvent, MenuReaderState> {
  final MenuReaderRepository repository;

  MenuReaderBloc({required this.repository}) : super(const MenuReaderState()) {
    on<ExtractMenuFromImage>(_onExtractFromImage);
    on<ExtractMenuFromUrl>(_onExtractFromUrl);
    on<ToggleItemSelection>(_onToggleItem);
    on<UpdateItemDetails>(_onUpdateItem);
    on<UpdateCategoryName>(_onUpdateCategory);
    on<SaveExtractedItems>(_onSaveItems);
    on<ResetMenuReader>(_onReset);
  }

  Future<void> _onExtractFromImage(
    ExtractMenuFromImage event,
    Emitter<MenuReaderState> emit,
  ) async {
    emit(state.copyWith(status: MenuReaderStatus.extracting));

    final result = await repository.extractMenuFromImage(
      imageBytes: event.imageBytes,
      fileName: event.fileName,
      barId: event.barId,
      languageHint: event.languageHint,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: MenuReaderStatus.error,
          errorMessage: failure.errorMessage,
        ),
      ),
      (extraction) => emit(
        state.copyWith(
          status: MenuReaderStatus.extracted,
          extraction: extraction,
          editableCategories: extraction.categories,
          confidence: extraction.confidence,
        ),
      ),
    );
  }

  Future<void> _onExtractFromUrl(
    ExtractMenuFromUrl event,
    Emitter<MenuReaderState> emit,
  ) async {
    emit(state.copyWith(status: MenuReaderStatus.extracting));

    final result = await repository.extractMenuFromUrl(
      menuUrl: event.menuUrl,
      barId: event.barId,
      languageHint: event.languageHint,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: MenuReaderStatus.error,
          errorMessage: failure.errorMessage,
        ),
      ),
      (extraction) => emit(
        state.copyWith(
          status: MenuReaderStatus.extracted,
          extraction: extraction,
          editableCategories: extraction.categories,
          confidence: extraction.confidence,
        ),
      ),
    );
  }

  void _onToggleItem(ToggleItemSelection event, Emitter<MenuReaderState> emit) {
    final categories = List<ExtractedCategory>.from(state.editableCategories);
    final category = categories[event.categoryIndex];
    final items = List<ExtractedItem>.from(category.items);
    final item = items[event.itemIndex];

    items[event.itemIndex] = item.copyWith(isSelected: !item.isSelected);
    categories[event.categoryIndex] = category.copyWith(items: items);

    emit(
      state.copyWith(
        status: MenuReaderStatus.editing,
        editableCategories: categories,
      ),
    );
  }

  void _onUpdateItem(UpdateItemDetails event, Emitter<MenuReaderState> emit) {
    final categories = List<ExtractedCategory>.from(state.editableCategories);
    final category = categories[event.categoryIndex];
    final items = List<ExtractedItem>.from(category.items);
    final item = items[event.itemIndex];

    items[event.itemIndex] = item.copyWith(
      name: event.name ?? item.name,
      price: event.price ?? item.price,
      description: event.description ?? item.description,
    );
    categories[event.categoryIndex] = category.copyWith(items: items);

    emit(
      state.copyWith(
        status: MenuReaderStatus.editing,
        editableCategories: categories,
      ),
    );
  }

  void _onUpdateCategory(
    UpdateCategoryName event,
    Emitter<MenuReaderState> emit,
  ) {
    final categories = List<ExtractedCategory>.from(state.editableCategories);
    categories[event.categoryIndex] = categories[event.categoryIndex].copyWith(
      name: event.name,
    );

    emit(
      state.copyWith(
        status: MenuReaderStatus.editing,
        editableCategories: categories,
      ),
    );
  }

  Future<void> _onSaveItems(
    SaveExtractedItems event,
    Emitter<MenuReaderState> emit,
  ) async {
    emit(state.copyWith(status: MenuReaderStatus.saving));

    final result = await repository.saveExtractedItems(
      barId: event.barId,
      categories: state.editableCategories,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: MenuReaderStatus.error,
          errorMessage: failure.errorMessage,
        ),
      ),
      (_) => emit(state.copyWith(status: MenuReaderStatus.saved)),
    );
  }

  void _onReset(ResetMenuReader event, Emitter<MenuReaderState> emit) {
    emit(const MenuReaderState());
  }
}
