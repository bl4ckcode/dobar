import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/ui/primitives/barz_app_bar.dart';
import 'package:barz/ui/primitives/barz_card.dart';
import 'package:barz/ui/primitives/barz_button.dart';

/// Screen to seed test data into the backend for development
class CreateBarScreen extends StatefulWidget {
  const CreateBarScreen({super.key});

  @override
  State<CreateBarScreen> createState() => _CreateBarScreenState();
}

class _CreateBarScreenState extends State<CreateBarScreen> {
  bool _loading = false;
  final List<String> _logs = [];

  void _log(String message) {
    setState(() => _logs.add(message));
  }

  // ============ TEST DATA ============

  final List<Map<String, dynamic>> _testBars = [
    {
      'name': 'Bar do Zé',
      'address': 'Rua Augusta, 1234, São Paulo, SP',
      'phone_number': '+5511988887777',
      'email': 'contato@bardoze.com.br',
      'latitude': -23.5530,
      'longitude': -46.6587,
    },
    {
      'name': 'Boteco da Esquina',
      'address': 'Av. Paulista, 2000, São Paulo, SP',
      'phone_number': '+5511977776666',
      'email': 'contato@boteco.com.br',
      'latitude': -23.5610,
      'longitude': -46.6560,
    },
    {
      'name': 'Cervejaria Artesanal',
      'address': 'Rua Oscar Freire, 500, São Paulo, SP',
      'phone_number': '+5511966665555',
      'email': 'contato@cervejaria.com.br',
      'latitude': -23.5620,
      'longitude': -46.6720,
    },
  ];

  final List<Map<String, dynamic>> _testMenuItems = [
    {'name': 'Brahma Chopp', 'description': 'Chopp gelado 300ml', 'price': 8.90, 'category': 'Cervejas'},
    {'name': 'Heineken', 'description': 'Long neck 330ml', 'price': 12.90, 'category': 'Cervejas'},
    {'name': 'Caipirinha', 'description': 'Limão, cachaça e açúcar', 'price': 18.00, 'category': 'Drinks'},
    {'name': 'Batata Frita', 'description': 'Porção 400g com cheddar e bacon', 'price': 32.00, 'category': 'Petiscos'},
    {'name': 'Picanha na Chapa', 'description': 'Com farofa e vinagrete', 'price': 65.00, 'category': 'Petiscos'},
  ];

  final List<Map<String, dynamic>> _testPromotions = [
    {
      'title': 'Happy Hour 2x1',
      'description': 'Compre um chopp, leve dois! Válido de segunda a quinta das 17h às 20h.',
      'discount_type': 'bogo',
      'discount_value': 100.0,
      'start_time': '17:00',
      'end_time': '20:00',
      'recurring': true,
      'recurring_days': 'monday,tuesday,wednesday,thursday',
      'terms': 'Válido apenas para chopp',
      'is_active': true,
    },
    {
      'title': '20% OFF Caipirinha',
      'description': 'Desconto especial em todas as caipirinhas aos fins de semana.',
      'discount_type': 'percentage',
      'discount_value': 20.0,
      'start_time': '12:00',
      'end_time': '23:00',
      'recurring': true,
      'recurring_days': 'saturday,sunday',
      'terms': 'Não acumulativo',
      'is_active': true,
    },
  ];

  // ============ API CALLS ============

  Future<void> _ensureOwnerExists() async {
    try {
      await DioNetwork.appAPI.post(
        '${ApiEndpoints.baseUrl}/barowners/',
        data: {
          'id': 1,
          'name': 'Test Owner',
          'phone_number': '+5511999999999',
          'email': 'owner@barz.com',
        },
      );
      _log('✓ Owner created');
    } catch (e) {
      _log('→ Owner already exists or skipped');
    }
  }

  Future<int?> _createBar(Map<String, dynamic> barData) async {
    try {
      final formData = FormData.fromMap({
        ...barData,
        'owner_id': 1,
        'image': MultipartFile.fromBytes(
          _generatePlaceholderImage(),
          filename: 'bar.png',
          contentType: DioMediaType('image', 'png'),
        ),
      });

      final response = await DioNetwork.appAPI.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.bars}',
        data: formData,
      );

      final barId = response.data['id'] as int;
      _log('✓ Bar "${barData['name']}" created (id: $barId)');
      return barId;
    } catch (e) {
      _log('✗ Bar "${barData['name']}" failed: ${_shortError(e)}');
      return null;
    }
  }

  Future<int?> _createMenu(int barId, String menuName) async {
    try {
      final response = await DioNetwork.appAPI.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.menusCreate}',
        data: {
          'bar_id': barId,
          'name': menuName,
          'description': 'Menu principal do bar',
          'is_active': true,
        },
      );

      final menuId = response.data['id'] as int;
      _log('  ✓ Menu "$menuName" created (id: $menuId)');
      return menuId;
    } catch (e) {
      _log('  ✗ Menu creation failed: ${_shortError(e)}');
      return null;
    }
  }

  Future<void> _addMenuItem(int menuId, Map<String, dynamic> item) async {
    try {
      await DioNetwork.appAPI.post(
        '${ApiEndpoints.baseUrl}/menus/$menuId/items/',
        data: {
          'name': item['name'],
          'description': item['description'],
          'price': item['price'],
          'category': item['category'],
          'is_available': true,
        },
      );
      _log('    ✓ Item "${item['name']}" added');
    } catch (e) {
      _log('    ✗ Item "${item['name']}" failed: ${_shortError(e)}');
    }
  }

  Future<void> _createPromotion(int barId, Map<String, dynamic> promo) async {
    try {
      final formData = FormData.fromMap({
        'bar_id': barId,
        ...promo,
      });

      await DioNetwork.appAPI.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.promotions}',
        data: formData,
      );
      _log('  ✓ Promotion "${promo['title']}" created');
    } catch (e) {
      _log('  ✗ Promotion "${promo['title']}" failed: ${_shortError(e)}');
    }
  }

  Future<void> _seedAllData() async {
    setState(() {
      _loading = true;
      _logs.clear();
    });

    _log('🚀 Starting data seeding...\n');

    // 1. Create owner
    await _ensureOwnerExists();
    _log('');

    // 2. Create bars with menus, items, and promotions
    for (int i = 0; i < _testBars.length; i++) {
      final bar = _testBars[i];
      _log('📍 Creating bar ${i + 1}/${_testBars.length}: ${bar['name']}');

      final barId = await _createBar(bar);
      if (barId == null) continue;

      // Create menu for this bar
      final menuId = await _createMenu(barId, 'Cardápio Principal');
      if (menuId != null) {
        // Add menu items
        for (final item in _testMenuItems) {
          await _addMenuItem(menuId, item);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Create promotions for first 2 bars only
      if (i < 2) {
        _log('  📢 Adding promotions...');
        for (final promo in _testPromotions) {
          await _createPromotion(barId, promo);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      _log('');
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _log('✅ Seeding complete! Go back to Home to see your bars.');
    setState(() => _loading = false);
  }

  String _shortError(dynamic e) {
    final str = e.toString();
    return str.length > 60 ? '${str.substring(0, 60)}...' : str;
  }

  List<int> _generatePlaceholderImage() {
    return [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEB, 0x00, 0x00,
      0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarzAppBar(title: 'Seed Test Data'),
      body: Container(
        decoration: const BoxDecoration(gradient: yellowBackgroundGradient),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: BarzCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storage, color: barzYellowDark),
                          const SizedBox(width: 12),
                          Text(
                            'Seed Development Data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Creates ${_testBars.length} bars with menus (${_testMenuItems.length} items each) and ${_testPromotions.length} promotions.',
                        style: TextStyle(color: textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: BarzButton(
                              text: _loading ? 'Seeding...' : 'Seed All Data',
                              onPressed: _loading ? null : _seedAllData,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => context.go('/'),
                            icon: Icon(Icons.home, color: barzBlack),
                            tooltip: 'Back to Home',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Logs
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: barzBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          'Press "Seed All Data" to start',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          Color color = Colors.white70;
                          if (log.startsWith('✓')) color = Colors.greenAccent;
                          if (log.startsWith('✗')) color = Colors.redAccent;
                          if (log.startsWith('→')) color = Colors.amber;
                          if (log.startsWith('🚀') || log.startsWith('✅')) {
                            color = barzYellow;
                          }
                          if (log.startsWith('📍') || log.startsWith('📢')) {
                            color = Colors.white;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
