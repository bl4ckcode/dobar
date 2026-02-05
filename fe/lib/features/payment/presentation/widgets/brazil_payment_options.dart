import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barz/core/design/tokens/colors.dart';

class BrazilPaymentOptions extends StatefulWidget {
  final VoidCallback onSelectPix;
  final VoidCallback onSelectNubank;
  final double total;

  const BrazilPaymentOptions({
    super.key,
    required this.onSelectPix,
    required this.onSelectNubank,
    required this.total,
  });

  @override
  State<BrazilPaymentOptions> createState() => _BrazilPaymentOptionsState();
}

class _BrazilPaymentOptionsState extends State<BrazilPaymentOptions> {
  bool _showPixModal = false;
  bool _copied = false;

  final String _pixCode = '00020126580014br.gov.bcb.pix0136a1b2c3d4-e5f6';

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  void _handleCopyPix() {
    Clipboard.setData(ClipboardData(text: _pixCode));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Brazilian Payment Methods',
            style: TextStyle(
              color: isDark ? textOnDark : textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildPixButton()),
              const SizedBox(width: 12),
              Expanded(child: _buildNubankButton()),
            ],
          ),
        ),
        if (_showPixModal) _buildPixModal(isDark),
      ],
    );
  }

  Widget _buildPixButton() {
    return GestureDetector(
      onTap: () => setState(() => _showPixModal = true),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00A884), Color(0xFF128C7E)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A884).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPixIcon(),
            const SizedBox(width: 10),
            const Text(
              'Pay with PIX',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNubankButton() {
    return GestureDetector(
      onTap: widget.onSelectNubank,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A05BE), Color(0xFF6E04A5)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A05BE).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Nu',
                style: TextStyle(
                  color: Color(0xFF8A05BE),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Pay with Nubank',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _PixIconPainter()),
    );
  }

  Widget _buildPixModal(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _showPixModal = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? barzDarkLight : surfaceWhite,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: barzDark.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pay with PIX',
                        style: TextStyle(
                          color: isDark ? textOnDark : textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showPixModal = false),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF444444)
                                : surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: isDark
                                ? const Color(0xFFB0B0B0)
                                : textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.grey.shade100, Colors.grey.shade200],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.qr_code_2,
                        size: 100,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _formatCurrency(widget.total),
                    style: const TextStyle(
                      color: barzGold,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan with your banking app',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFB0B0B0) : textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _handleCopyPix,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF333333) : surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _copied ? Icons.check : Icons.copy,
                            size: 18,
                            color: _copied
                                ? successGreen
                                : (isDark ? textOnDark : textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _copied ? 'Copied!' : 'Copy PIX code',
                            style: TextStyle(
                              color: _copied
                                  ? successGreen
                                  : (isDark ? textOnDark : textPrimary),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payment expires in 30 minutes',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF888888) : textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = size.width / 2;
    final offset = size.width * 0.25;

    path.moveTo(center, 0);
    path.lineTo(center + offset, offset);
    path.lineTo(size.width, center);
    path.lineTo(center + offset, center + offset);
    path.lineTo(center, size.height);
    path.lineTo(center - offset, center + offset);
    path.lineTo(0, center);
    path.lineTo(center - offset, offset);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
