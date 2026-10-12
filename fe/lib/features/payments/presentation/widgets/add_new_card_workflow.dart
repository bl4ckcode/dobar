import 'package:flutter/material.dart';
import 'package:barz/core/design/tokens/colors.dart';

enum AddCardStep { number, expiry, name, confirm }

class AddNewCardWorkflow extends StatefulWidget {
  final bool isDark;
  final VoidCallback onClose;
  final Function(Map<String, String>) onComplete;

  const AddNewCardWorkflow({
    super.key,
    required this.isDark,
    required this.onClose,
    required this.onComplete,
  });

  @override
  State<AddNewCardWorkflow> createState() => _AddNewCardWorkflowState();
}

class _AddNewCardWorkflowState extends State<AddNewCardWorkflow>
    with SingleTickerProviderStateMixin {
  AddCardStep _currentStep = AddCardStep.number;
  String _cardNumber = "";
  String _expiry = "";
  String _cvv = "";
  String _name = "";

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  final FocusNode _focusNodeNumber = FocusNode();
  final FocusNode _focusNodeExpiry = FocusNode();
  final FocusNode _focusNodeCvv = FocusNode();
  final FocusNode _focusNodeName = FocusNode();

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _updateProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodeNumber.requestFocus();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _focusNodeNumber.dispose();
    _focusNodeExpiry.dispose();
    _focusNodeCvv.dispose();
    _focusNodeName.dispose();
    super.dispose();
  }

  bool _isInit = false;

  void _updateProgress() {
    double targetProgress =
        (AddCardStep.values.indexOf(_currentStep) + 1) /
        AddCardStep.values.length;

    double beginValue = 0.0;
    if (_isInit) {
      beginValue = _progressAnimation.value;
    }
    _isInit = true;

    _progressAnimation = Tween<double>(begin: beginValue, end: targetProgress)
        .animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
        );
    _progressController.forward(from: 0.0);
  }

  String _detectBrand(String num) {
    final clean = num.replaceAll(' ', '');
    if (clean.startsWith('4')) return 'VISA';
    if (clean.startsWith('5')) return 'MC';
    if (clean.startsWith('6')) return 'ELO';
    if (clean.startsWith('3')) return 'AMEX';
    return 'VISA';
  }

  Color _getBrandColor(String brand) {
    switch (brand) {
      case 'VISA':
        return Colors.blue.shade600;
      case 'MC':
        return Colors.orange.shade500;
      case 'ELO':
        return Colors.yellow.shade600;
      case 'AMEX':
        return Colors.blue.shade400;
      default:
        return Colors.blue.shade600;
    }
  }

  bool _isStepValid() {
    switch (_currentStep) {
      case AddCardStep.number:
        return _cardNumber.replaceAll(' ', '').length >= 15;
      case AddCardStep.expiry:
        return _expiry.length >= 4 && _cvv.length >= 3;
      case AddCardStep.name:
        return _name.trim().length >= 3;
      case AddCardStep.confirm:
        return true;
    }
  }

  void _handleNext() {
    if (!_isStepValid()) return;

    int nextIndex = AddCardStep.values.indexOf(_currentStep) + 1;
    if (nextIndex < AddCardStep.values.length) {
      setState(() {
        _currentStep = AddCardStep.values[nextIndex];
        _updateProgress();
      });
      // Handle focus
      if (_currentStep == AddCardStep.expiry) _focusNodeExpiry.requestFocus();
      if (_currentStep == AddCardStep.name) _focusNodeName.requestFocus();
    } else {
      _handleConfirm();
    }
  }

  void _handleBack() {
    int prevIndex = AddCardStep.values.indexOf(_currentStep) - 1;
    if (prevIndex >= 0) {
      setState(() {
        _currentStep = AddCardStep.values[prevIndex];
        _updateProgress();
      });
    } else {
      widget.onClose();
    }
  }

  void _handleConfirm() {
    final clean = _cardNumber.replaceAll(' ', '');
    widget.onComplete({
      'brand': _detectBrand(clean),
      'last4': clean.length >= 4 ? clean.substring(clean.length - 4) : clean,
      'expiry': _expiry,
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? textOnDark : textPrimary;
    final mutedTextColor = widget.isDark ? textSecondary : textSecondary;
    final inputBgColor = widget.isDark ? barzDarkLight : surfaceMuted;

    final brand = _detectBrand(_cardNumber);
    final brandColor = _getBrandColor(brand);

    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _handleBack,
              icon: Icon(Icons.arrow_back, color: textColor),
              style: IconButton.styleFrom(backgroundColor: inputBgColor),
            ),
            Text(
              'Step ${AddCardStep.values.indexOf(_currentStep) + 1} of ${AddCardStep.values.length}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: mutedTextColor,
              ),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: Icon(Icons.close, color: mutedTextColor),
              style: IconButton.styleFrom(backgroundColor: inputBgColor),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Progress bar
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: inputBgColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: barzGold,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: barzGold.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Card Preview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B2B2B), Color(0xFF141414)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      brand,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline,
                    color: Colors.white38,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                _cardNumber.isEmpty ? '•••• •••• •••• ••••' : _cardNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CARDHOLDER',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _name.isEmpty ? 'YOUR NAME' : _name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'EXPIRES',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _expiry.isEmpty ? 'MM/YY' : _expiry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Animated Form Content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _buildCurrentStep(textColor, inputBgColor),
        ),

        const SizedBox(height: 24),

        // Action Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isStepValid() ? _handleNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentStep == AddCardStep.confirm
                  ? barzGold
                  : (widget.isDark ? Colors.white : barzDark),
              foregroundColor: _currentStep == AddCardStep.confirm
                  ? barzDark
                  : (widget.isDark ? barzDark : Colors.white),
              disabledBackgroundColor: inputBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: _currentStep == AddCardStep.confirm ? 4 : 0,
            ),
            child: Text(
              _currentStep == AddCardStep.confirm ? 'Save Card' : 'Continue',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep(Color textColor, Color inputBgColor) {
    if (_currentStep == AddCardStep.number) {
      return Column(
        key: const ValueKey('number'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card Number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            focusNode: _focusNodeNumber,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: textColor,
              fontFamily: 'monospace',
              letterSpacing: 2,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: '0000 0000 0000 0000',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
              prefixIcon: Icon(
                Icons.credit_card,
                color: textColor.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: inputBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              String clean = value.replaceAll(RegExp(r'\D'), '');
              if (clean.length > 16) clean = clean.substring(0, 16);
              String formatted = '';
              for (int i = 0; i < clean.length; i++) {
                if (i > 0 && i % 4 == 0) formatted += ' ';
                formatted += clean[i];
              }
              setState(() {
                _cardNumber = formatted;
              });
            },
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: _cardNumber,
                selection: TextSelection.collapsed(offset: _cardNumber.length),
              ),
            ),
          ),
        ],
      );
    } else if (_currentStep == AddCardStep.expiry) {
      return Row(
        key: const ValueKey('expiry'),
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expiry Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  focusNode: _focusNodeExpiry,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'MM/YY',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.3),
                    ),
                    filled: true,
                    fillColor: inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    String clean = value.replaceAll(RegExp(r'\D'), '');
                    if (clean.length > 4) clean = clean.substring(0, 4);
                    String formatted = clean;
                    if (clean.length >= 3) {
                      formatted =
                          '${clean.substring(0, 2)}/${clean.substring(2)}';
                    }
                    setState(() {
                      _expiry = formatted;
                    });
                  },
                  controller: TextEditingController.fromValue(
                    TextEditingValue(
                      text: _expiry,
                      selection: TextSelection.collapsed(
                        offset: _expiry.length,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CVV',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  focusNode: _focusNodeCvv,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: '•••',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.3),
                    ),
                    filled: true,
                    fillColor: inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    String clean = value.replaceAll(RegExp(r'\D'), '');
                    if (clean.length > 4) clean = clean.substring(0, 4);
                    setState(() {
                      _cvv = clean;
                    });
                  },
                  controller: TextEditingController.fromValue(
                    TextEditingValue(
                      text: _cvv,
                      selection: TextSelection.collapsed(offset: _cvv.length),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_currentStep == AddCardStep.name) {
      return Column(
        key: const ValueKey('name'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cardholder Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            focusNode: _focusNodeName,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Name on card',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
              filled: true,
              fillColor: inputBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _name = value.toUpperCase();
              });
            },
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: _name,
                selection: TextSelection.collapsed(offset: _name.length),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        key: const ValueKey('confirm'),
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: barzGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: barzGold, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Card ready to save',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_detectBrand(_cardNumber)} ending in ${_cardNumber.replaceAll(' ', '').substring(_cardNumber.replaceAll(' ', '').length - 4)} • Expires $_expiry',
            style: TextStyle(
              fontSize: 14,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }
  }
}
