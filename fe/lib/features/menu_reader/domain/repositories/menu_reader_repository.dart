import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/menu_reader/domain/models/menu_extraction.dart';

abstract class MenuReaderRepository {
  Future<Either<Failure, MenuExtraction>> extractMenuFromImage({
    required File imageFile,
    required int barId,
    String? languageHint,
  });

  Future<Either<Failure, MenuExtraction>> extractMenuFromUrl({
    required String menuUrl,
    required int barId,
    String? languageHint,
  });

  Future<Either<Failure, bool>> saveExtractedItems({
    required int barId,
    required List<ExtractedCategory> categories,
  });
}
