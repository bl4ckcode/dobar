import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_bloc.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_event.dart';
import 'package:barz/features/promotions/presentation/bloc/promotions_state.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/shared/presentation/widget/safe_network_image.dart';

class PromotionDetailPage extends StatelessWidget {
  final int promotionId;

  const PromotionDetailPage({super.key, required this.promotionId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getItInjector<PromotionsBloc>()
        ..add(LoadPromotionById(promotionId)),
      child: Scaffold(
        backgroundColor: barzYellowSoft,
        appBar: AppBar(
          title: const Text('Promotion'),
          backgroundColor: barzBlack,
          foregroundColor: barzYellow,
        ),
        body: BlocBuilder<PromotionsBloc, PromotionsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(state.error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              );
            }
            if (state.selectedPromotion == null) {
              return const Center(child: Text('Promotion not found'));
            }
            return _buildContent(context, state.selectedPromotion!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PromotionModel promo) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero image
          SafeNetworkImage(
            imageUrl: promo.imageUrl,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: Container(
              height: 200,
              color: barzYellow,
              child: const Icon(Icons.local_offer, size: 64, color: barzBlack),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Discount badge
                _buildDiscountBadge(promo),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  promo.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: barzBlack,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Description
                if (promo.description != null && promo.description!.isNotEmpty)
                  Text(
                    promo.description!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                const SizedBox(height: 24),
                
                // Time info
                _buildInfoCard(
                  icon: Icons.access_time,
                  title: 'Valid Hours',
                  content: '${promo.startTime ?? '00:00'} - ${promo.endTime ?? '23:59'}',
                ),
                const SizedBox(height: 12),
                
                // Days info
                if (promo.recurringDays.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.calendar_today,
                    title: 'Available Days',
                    content: _formatDays(promo.recurringDays),
                  ),
                const SizedBox(height: 12),
                
                // Date range
                if (promo.startDate != null || promo.endDate != null)
                  _buildInfoCard(
                    icon: Icons.date_range,
                    title: 'Valid Period',
                    content: _formatDateRange(promo.startDate, promo.endDate),
                  ),
                const SizedBox(height: 12),
                
                // Terms
                if (promo.terms != null && promo.terms!.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.info_outline,
                    title: 'Terms & Conditions',
                    content: promo.terms!,
                  ),
                const SizedBox(height: 24),
                
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: promo.isActive ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        promo.isActive ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: promo.isActive ? Colors.green[700] : Colors.red[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        promo.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: promo.isActive ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountBadge(PromotionModel promo) {
    String discountText;
    switch (promo.discountType) {
      case PromoDiscountType.percentage:
        discountText = '${promo.discountValue.toInt()}% OFF';
      case PromoDiscountType.fixed:
        discountText = 'R\$ ${promo.discountValue.toStringAsFixed(2)} OFF';
      case PromoDiscountType.bogo:
        discountText = 'Buy 1 Get 1 FREE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: barzBlack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        discountText,
        style: const TextStyle(
          color: barzYellow,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: barzYellowDark, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: barzBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDays(List<String> days) {
    final dayNames = {
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };
    return days.map((d) => dayNames[d.toLowerCase()] ?? d).join(', ');
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    final startStr = start != null 
        ? '${start.day}/${start.month}/${start.year}'
        : 'Now';
    final endStr = end != null 
        ? '${end.day}/${end.month}/${end.year}'
        : 'Ongoing';
    return '$startStr - $endStr';
  }
}
