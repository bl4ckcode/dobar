import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:dio/dio.dart';

class BarNetworkDataSource {
  final Dio dio;

  BarNetworkDataSource({required this.dio});

  Future<List<BarModel>> getNearbyBars(
      double lat, double lng, double maxDistance) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.bars}',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'max_distance': maxDistance,
        },
      );
      return (response.data as List)
          .map((e) => BarModel.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to fetch bars',
          e.response?.statusCode);
    }
  }

  Future<BarModel> getBar(int barId) async {
    try {
      final response =
          await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.bar(barId)}');
      return BarModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to fetch bar',
          e.response?.statusCode);
    }
  }

  /// Fetch all menus for a bar
  Future<List<MenuModel>> getBarMenus(int barId) async {
    try {
      final response =
          await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.menusForBar(barId)}');
      if (response.data is List) {
        return (response.data as List)
            .map((e) => MenuModel.fromJson(e))
            .toList();
      }
      return [MenuModel.fromJson(response.data)];
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to fetch menus',
          e.response?.statusCode);
    }
  }

  /// Fetch items for a specific menu using new endpoint structure
  /// GET /menus/{menu_id}/items - returns list of items directly
  Future<List<MenuItemModel>> getMenuItems(int menuId) async {
    try {
      final response = await dio
          .get('${ApiEndpoints.baseUrl}${ApiEndpoints.menuItems(menuId)}');
      // New endpoint returns direct list of items
      if (response.data is List) {
        return (response.data as List)
            .map((e) => MenuItemModel.fromJson(e))
            .toList();
      }
      // Legacy endpoint returns {"items": [...]} object
      if (response.data is Map && response.data['items'] is List) {
        return (response.data['items'] as List)
            .map((e) => MenuItemModel.fromJson(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Failed to fetch menu items',
          e.response?.statusCode);
    }
  }

  /// Fetch menus with their items (combines both calls)
  Future<List<MenuModel>> getBarMenusWithItems(int barId) async {
    final menus = await getBarMenus(barId);
    final menusWithItems = <MenuModel>[];
    
    for (final menu in menus) {
      final items = await getMenuItems(menu.id);
      menusWithItems.add(MenuModel(
        id: menu.id,
        barId: menu.barId,
        items: items,
      ));
    }
    
    return menusWithItems;
  }

  /// Create a new bar using the wizard endpoint
  /// POST /bars/wizard
  Future<BarModel> createBar({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String phoneNumber,
    required String email,
    required String countryCode,
    String? businessId,
    String? businessIdType,
    String? stateRegistration,
    String? logoUrl,
    String? coverUrl,
    List<String>? photoUrls,
    Map<String, dynamic>? operatingHours,
    Map<String, dynamic>? bankAccount,
  }) async {
    try {
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.barsWizard}',
        data: {
          'name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'phone_number': phoneNumber,
          'email': email,
          'country_code': countryCode,
          if (businessId != null) 'business_id': businessId,
          if (businessIdType != null) 'business_id_type': businessIdType,
          if (stateRegistration != null) 'state_registration': stateRegistration,
          if (logoUrl != null) 'logo_url': logoUrl,
          if (coverUrl != null) 'cover_url': coverUrl,
          if (photoUrls != null && photoUrls.isNotEmpty) 'photo_urls': photoUrls,
          if (operatingHours != null) 'operating_hours': operatingHours,
          if (bankAccount != null) 'bank_account': bankAccount,
        },
      );
      return BarModel.fromJson(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      String errorMessage = 'Failed to create bar';
      
      if (data is Map<String, dynamic>) {
        // API_ERROR_CONTRACT format: {message: "...", details: {...}}
        if (data['message'] is String) {
          errorMessage = data['message'] as String;
          final details = data['details'];
          if (details is Map<String, dynamic> && details.isNotEmpty) {
            final fieldErrors = details.entries
                .map((e) => e.value is List 
                    ? (e.value as List).join(', ') 
                    : e.value.toString())
                .join('; ');
            errorMessage = '$errorMessage: $fieldErrors';
          }
        } 
        // FastAPI validation format: {detail: [{msg: "..."}]}
        else if (data['detail'] is List) {
          final messages = (data['detail'] as List).map((e) {
            if (e is Map<String, dynamic>) {
              return e['msg'] as String? ?? e.toString();
            }
            return e.toString();
          }).join(', ');
          errorMessage = messages;
        } else if (data['detail'] is String) {
          errorMessage = data['detail'] as String;
        }
      }
      
      throw ServerException(errorMessage, e.response?.statusCode);
    }
  }
}
