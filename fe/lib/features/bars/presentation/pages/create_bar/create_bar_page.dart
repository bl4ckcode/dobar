import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'steps/find_bar_step.dart';
import 'steps/basic_info_step.dart';
import 'steps/photos_step.dart';
import 'steps/hours_step.dart';
import 'steps/bank_account_step.dart';
import 'steps/review_step.dart';

class CreateBarPage extends StatefulWidget {
  const CreateBarPage({super.key});

  @override
  State<CreateBarPage> createState() => _CreateBarPageState();
}

class _CreateBarPageState extends State<CreateBarPage> {
  int _currentStep = 0;
  final _formData = CreateBarFormData();
  final _pageController = PageController();
  bool _isSubmitting = false;

  static const _totalSteps = 6;

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    
    setState(() => _isSubmitting = true);
    
    final l10n = AppLocalizations.of(context)!;
    final barUsecase = getItInjector<BarUsecase>();
    
    // Convert operating hours to API format
    final operatingHoursMap = <String, dynamic>{};
    for (final entry in _formData.operatingHours.entries) {
      final hours = entry.value;
      operatingHoursMap[entry.key] = {
        'is_closed': !hours.isOpen,
        if (hours.isOpen && hours.openTime != null)
          'open': '${hours.openTime!.hour.toString().padLeft(2, '0')}:${hours.openTime!.minute.toString().padLeft(2, '0')}',
        if (hours.isOpen && hours.closeTime != null)
          'close': '${hours.closeTime!.hour.toString().padLeft(2, '0')}:${hours.closeTime!.minute.toString().padLeft(2, '0')}',
      };
    }
    
    final result = await barUsecase.createBar(
      name: _formData.name,
      address: _formData.address,
      latitude: _formData.latitude ?? 0,
      longitude: _formData.longitude ?? 0,
      phoneNumber: _formData.phone,
      email: _formData.email,
      countryCode: _formData.countryCode,
      businessId: _formData.businessId.isNotEmpty ? _formData.businessId : null,
      businessIdType: _formData.countryConfig.businessIdLabel,
      logoUrl: _formData.logoPath,
      coverUrl: _formData.coverPath,
      photoUrls: _formData.photoPaths.isNotEmpty ? _formData.photoPaths : null,
      operatingHours: operatingHoursMap.isNotEmpty ? operatingHoursMap : null,
      bankAccount: _formData.bankAccount.toJson(_formData.countryCode),
    );
    
    if (!mounted) return;
    
    setState(() => _isSubmitting = false);
    
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.errorMessage),
            backgroundColor: errorRed,
          ),
        );
      },
      (bar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.bar_created_success),
            backgroundColor: successGreen,
          ),
        );
        context.pop(true);
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: barzGoldSoft,
      appBar: AppBar(
        backgroundColor: barzDark,
        foregroundColor: Colors.white,
        title: Text(l10n.create_bar),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context, l10n),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(l10n),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                FindBarStep(
                  formData: _formData,
                  onNext: _nextStep,
                ),
                BasicInfoStep(
                  formData: _formData,
                  onNext: _nextStep,
                  onBack: _previousStep,
                ),
                PhotosStep(
                  formData: _formData,
                  onNext: _nextStep,
                  onBack: _previousStep,
                ),
                HoursStep(
                  formData: _formData,
                  onNext: _nextStep,
                  onBack: _previousStep,
                ),
                BankAccountStep(
                  formData: _formData,
                  onNext: _nextStep,
                  onBack: _previousStep,
                ),
                ReviewStep(
                  formData: _formData,
                  onSubmit: _submit,
                  onBack: _previousStep,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(AppLocalizations l10n) {
    final stepLabels = [
      l10n.step_find_bar,
      l10n.step_basic_info,
      l10n.step_photos,
      l10n.step_hours,
      l10n.step_payment,
      l10n.step_review,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      color: surfaceWhite,
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted ? barzGold : surfaceDim,
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? barzGold
                            : isCurrent
                                ? barzDark
                                : surfaceDim,
                        border: isCurrent
                            ? Border.all(color: barzGold, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: barzDark)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : textSecondary,
                                ),
                              ),
                      ),
                    ).animate(target: isCurrent ? 1 : 0).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.1, 1.1),
                          duration: 200.ms,
                        ),
                    if (index < _totalSteps - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted ? barzGold : surfaceDim,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            stepLabels[_currentStep],
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discard_changes),
        content: Text(l10n.discard_changes_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: errorRed,
            ),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
  }
}

class CreateBarFormData {
  String name = '';
  String address = '';
  String phone = '';
  String email = '';
  String countryCode = 'BR';
  String businessId = '';
  double? latitude;
  double? longitude;
  String? logoPath;
  String? coverPath;
  List<String> photoPaths = [];
  Map<String, OperatingHours> operatingHours = {};
  BankAccountData bankAccount = BankAccountData();
  
  bool get isBasicInfoValid =>
      name.isNotEmpty && address.isNotEmpty && phone.isNotEmpty && email.isNotEmpty;

  bool get isLocationValid => latitude != null && longitude != null;
  
  CountryFormConfig get countryConfig => CountryFormConfig.forCountry(countryCode);
}

/// Bank account data for payouts - varies by country
class BankAccountData {
  // Brazil-specific
  String bankCode = '';      // 3 digits (e.g., 001 = Banco do Brasil)
  String branchCode = '';    // 4 digits (agência)
  String pixKey = '';        // CPF/CNPJ/email/phone/random
  String pixKeyType = '';    // cpf | cnpj | email | phone | random
  
  // Mexico
  String clabe = '';         // 18 digits - Clave Bancaria Estandarizada
  
  // Argentina
  String cbu = '';           // 22 digits - Clave Bancaria Uniforme
  
  // USA
  String routingNumber = ''; // 9 digits (ABA routing)
  
  // Common fields
  String accountNumber = '';
  String accountType = '';   // checking | savings
  String accountHolderName = '';
  
  Map<String, dynamic> toJson(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'BR':
        if (pixKey.isNotEmpty) {
          return {
            'pix_key': pixKey,
            'pix_key_type': pixKeyType,
          };
        }
        return {
          'bank_code': bankCode,
          'branch_code': branchCode,
          'account_number': accountNumber,
          'account_type': accountType,
        };
      case 'MX':
        return {
          'clabe': clabe,
          'account_holder_name': accountHolderName,
        };
      case 'AR':
        return {
          'cbu': cbu,
          'account_holder_name': accountHolderName,
        };
      case 'US':
        return {
          'routing_number': routingNumber,
          'account_number': accountNumber,
          'account_type': accountType,
        };
      default:
        return {
          'account_number': accountNumber,
          'account_holder_name': accountHolderName,
        };
    }
  }
}

class OperatingHours {
  final bool isOpen;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;

  OperatingHours({
    this.isOpen = false,
    this.openTime,
    this.closeTime,
  });
}
