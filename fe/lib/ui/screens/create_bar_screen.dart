import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:barz/core/network/dio_network.dart';
import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/ui/primitives/barz_app_bar.dart';
import 'package:barz/ui/primitives/barz_card.dart';
import 'package:barz/ui/primitives/barz_button.dart';

class CreateBarScreen extends StatefulWidget {
  const CreateBarScreen({super.key});

  @override
  State<CreateBarScreen> createState() => _CreateBarScreenState();
}

class _CreateBarScreenState extends State<CreateBarScreen> {
  bool _loading = false;
  String? _message;
  int _barCount = 0;

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
    {
      'name': 'Rooftop Lounge',
      'address': 'Al. Santos, 800, São Paulo, SP',
      'phone_number': '+5511955554444',
      'email': 'contato@rooftop.com.br',
      'latitude': -23.5650,
      'longitude': -46.6510,
    },
    {
      'name': 'Pub Irlandês',
      'address': 'Rua Haddock Lobo, 300, São Paulo, SP',
      'phone_number': '+5511944443333',
      'email': 'contato@pubirl.com.br',
      'latitude': -23.5580,
      'longitude': -46.6630,
    },
  ];

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
    } catch (e) {}
  }

  Future<void> _createBar(Map<String, dynamic> barData) async {
    setState(() {
      _loading = true;
      _message = 'Creating ${barData['name']}...';
    });

    try {
      await _ensureOwnerExists();

      final formData = FormData.fromMap({
        ...barData,
        'owner_id': 1,
        'image': MultipartFile.fromBytes(
          _generatePlaceholderImage(),
          filename: 'bar.png',
          contentType: DioMediaType('image', 'png'),
        ),
      });

      await DioNetwork.appAPI.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.bars}',
        data: formData,
      );

      setState(() {
        _barCount++;
        _message = '✓ ${barData['name']} created! ($_barCount total)';
      });
    } catch (e) {
      setState(() {
        final errStr = e.toString();
        _message = '✗ Failed: ${errStr.length > 100 ? errStr.substring(0, 100) : errStr}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createAllBars() async {
    for (final bar in _testBars) {
      await _createBar(bar);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    setState(() => _message = 'Done! Created $_barCount bars. Go back to see them.');
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
      appBar: const BarzAppBar(title: 'Create Bars'),
      body: Container(
        decoration: const BoxDecoration(gradient: yellowBackgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BarzCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seed Test Bars',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Creates 5 test bars in São Paulo for development.',
                      style: TextStyle(color: textSecondary),
                    ),
                    const SizedBox(height: 16),
                    if (_message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: barzBlack.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_message!, style: TextStyle(color: textPrimary)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    BarzButton(
                      text: _loading ? 'Creating...' : 'Create All Bars',
                      onPressed: _loading ? null : _createAllBars,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_testBars.length, (i) {
              final bar = _testBars[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BarzCard(
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: barzYellowSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.store, color: barzYellowDark),
                    ),
                    title: Text(bar['name'], style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(bar['address'], maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(Icons.add_circle, color: barzYellowDark),
                      onPressed: _loading ? null : () => _createBar(bar),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
