import 'package:barz/core/api/api_endpoints.dart';
import 'package:dio/dio.dart';
import '../domain/venue_list_item.dart';
import '../domain/venue_repository.dart';

class VenueRepositoryImpl implements VenueRepository {
  final Dio dio;
  VenueRepositoryImpl({required this.dio});

  @override
  Future<VenuePage> fetch(VenueQuery query) async {
    final response = await dio.get(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.bars}',
      queryParameters: query.toQueryParameters(),
    );
    final items = (response.data as List)
        .whereType<Map<String, dynamic>>()
        .map(VenueListItem.fromJson)
        .toList();
    final total =
        int.tryParse(response.headers.value('x-total-count') ?? '') ??
        query.offset + items.length;
    final hasMore =
        (response.headers.value('x-has-more') ?? '').toLowerCase() == 'true';
    return VenuePage(items: items, total: total, hasMore: hasMore);
  }
}
