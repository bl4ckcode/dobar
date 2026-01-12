import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../create_bar_page.dart';
import '../widgets/wizard_footer.dart';

/// Bank account collection step for bar creation wizard.
/// 
/// Collects business ID (CNPJ/RFC/CUIT) and bank account details
/// based on the country selected in the Find Bar step.
class BankAccountStep extends StatefulWidget {
  final CreateBarFormData formData;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BankAccountStep({
    super.key,
    required this.formData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<BankAccountStep> createState() => _BankAccountStepState();
}

class _BankAccountStepState extends State<BankAccountStep> {
  late CountryFormConfig _countryConfig;
  bool _usePixKey = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _countryConfig = widget.formData.countryConfig;
    _usePixKey = widget.formData.bankAccount.pixKey.isNotEmpty;
    _checkFormValidity();
  }

  void _checkFormValidity() {
    bool hasBusinessId = !_countryConfig.requiresBusinessId || widget.formData.businessId.isNotEmpty;
    bool hasBankInfo = _hasBankInfo();
    setState(() {
      _isFormValid = hasBusinessId && hasBankInfo;
    });
  }

  bool _hasBankInfo() {
    final bank = widget.formData.bankAccount;
    switch (_countryConfig.code) {
      case CountryCode.br:
        return _usePixKey 
            ? bank.pixKey.isNotEmpty 
            : (bank.bankCode.isNotEmpty && bank.branchCode.isNotEmpty && bank.accountNumber.isNotEmpty);
      case CountryCode.mx:
        return bank.clabe.length == 18;
      case CountryCode.ar:
        return bank.cbu.length == 22;
      case CountryCode.us:
        return bank.routingNumber.length == 9 && bank.accountNumber.isNotEmpty;
      default:
        return bank.accountNumber.isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Expanded(
          child: ResponsiveCenterContainer(
            maxWidth: 720,
            minWidth: 320,
            maxWidthPercentage: 0.6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BarzSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoBanner(l10n),
                  const SizedBox(height: BarzSpacing.xl),
                  
                  if (_countryConfig.requiresBusinessId) ...[
                    _buildSectionHeader(
                      _countryConfig.businessIdLabel ?? l10n.business_id,
                      Icons.badge_rounded,
                    ),
                    const SizedBox(height: BarzSpacing.sm),
                    _buildBusinessIdSection(l10n),
                    const SizedBox(height: BarzSpacing.xl),
                  ],
                  
                  _buildSectionHeader(l10n.bank_account, Icons.account_balance_rounded),
                  const SizedBox(height: BarzSpacing.sm),
                  _buildBankAccountSection(l10n),
                ],
              ),
            ),
          ),
        ),
        WizardFooter(
          onBack: widget.onBack,
          onNext: _validateAndProceed,
          isNextEnabled: _isFormValid,
        ),
      ],
    );
  }

  Widget _buildInfoBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: infoBlueLight,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: infoBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: infoBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.payout_setup_title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.payout_setup_hint,
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: barzGold, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessIdSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: surfaceDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getBusinessIdDescription(),
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          BarzMaskedField(
            hintText: _countryConfig.businessIdHint ?? '',
            customMask: _countryConfig.businessIdMask,
            maskType: BarzMaskType.custom,
            initialValue: widget.formData.businessId,
            onUnmaskedChanged: (value) {
              widget.formData.businessId = value;
              _checkFormValidity();
            },
          ),
        ],
      ),
    );
  }

  String _getBusinessIdDescription() {
    switch (_countryConfig.code) {
      case CountryCode.br:
        return 'Cadastro Nacional de Pessoa Jurídica (14 dígitos)';
      case CountryCode.mx:
        return 'Registro Federal de Contribuyentes (12-13 caracteres)';
      case CountryCode.ar:
        return 'Clave Única de Identificación Tributaria (11 dígitos)';
      case CountryCode.us:
        return 'Employer Identification Number (9 digits)';
      case CountryCode.pt:
        return 'Número de Identificação Fiscal (9 dígitos)';
      case CountryCode.es:
        return 'Código de Identificación Fiscal (9 caracteres)';
      default:
        return 'Business tax identification number';
    }
  }

  Widget _buildBankAccountSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: surfaceDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bank_account_hint,
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          
          // Country-specific bank fields
          _buildCountrySpecificBankFields(l10n),
        ],
      ),
    );
  }

  Widget _buildCountrySpecificBankFields(AppLocalizations l10n) {
    switch (_countryConfig.code) {
      case CountryCode.br:
        return _buildBrazilBankFields(l10n);
      case CountryCode.mx:
        return _buildMexicoBankFields(l10n);
      case CountryCode.ar:
        return _buildArgentinaBankFields(l10n);
      case CountryCode.us:
        return _buildUSABankFields(l10n);
      default:
        return _buildGenericBankFields(l10n);
    }
  }

  Widget _buildBrazilBankFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PIX toggle for Brazil
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: barzGoldSoft,
            borderRadius: BorderRadius.circular(BarzRadii.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.pix_rounded, color: barzGold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.use_pix_key,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Switch(
                value: _usePixKey,
                onChanged: (value) {
                  setState(() => _usePixKey = value);
                  _checkFormValidity();
                },
                activeTrackColor: barzGoldLight,
                thumbColor: WidgetStatePropertyAll(_usePixKey ? barzGold : null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (_usePixKey) ...[
          // PIX Key fields
          _buildPixKeyFields(l10n),
        ] else ...[
          // Traditional bank account fields
          _buildBrazilTraditionalFields(l10n),
        ],
      ],
    );
  }

  Widget _buildPixKeyFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pix_key_type, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: widget.formData.bankAccount.pixKeyType.isEmpty 
              ? 'cnpj' 
              : widget.formData.bankAccount.pixKeyType,
          decoration: _inputDecoration(l10n.select_pix_type),
          items: [
            DropdownMenuItem(value: 'cnpj', child: Text('CNPJ')),
            DropdownMenuItem(value: 'cpf', child: Text('CPF')),
            DropdownMenuItem(value: 'email', child: Text('Email')),
            DropdownMenuItem(value: 'phone', child: Text(l10n.phone)),
            DropdownMenuItem(value: 'random', child: Text(l10n.random_key)),
          ],
          onChanged: (value) {
            setState(() {
              widget.formData.bankAccount.pixKeyType = value ?? 'cnpj';
              // Auto-fill with CNPJ if that type is selected
              if (value == 'cnpj' && widget.formData.businessId.isNotEmpty) {
                widget.formData.bankAccount.pixKey = widget.formData.businessId;
              }
            });
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.pix_key, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.pixKey,
          decoration: _inputDecoration(_getPixKeyHint()),
          onChanged: (value) {
            widget.formData.bankAccount.pixKey = value;
            _checkFormValidity();
          },
        ),
      ],
    );
  }

  String _getPixKeyHint() {
    switch (widget.formData.bankAccount.pixKeyType) {
      case 'cnpj':
        return '00.000.000/0000-00';
      case 'cpf':
        return '000.000.000-00';
      case 'email':
        return 'email@example.com';
      case 'phone':
        return '+55 11 99999-9999';
      case 'random':
        return 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
      default:
        return '';
    }
  }

  Widget _buildBrazilTraditionalFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.bank_code, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: widget.formData.bankAccount.bankCode,
                    decoration: _inputDecoration('001'),
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    onChanged: (value) {
                      widget.formData.bankAccount.bankCode = value;
                      _checkFormValidity();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.branch_code, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: widget.formData.bankAccount.branchCode,
                    decoration: _inputDecoration('1234'),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (value) {
                      widget.formData.bankAccount.branchCode = value;
                      _checkFormValidity();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.account_number, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.accountNumber,
          decoration: _inputDecoration('12345678-9'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            widget.formData.bankAccount.accountNumber = value;
            _checkFormValidity();
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.account_type, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: widget.formData.bankAccount.accountType.isEmpty 
              ? 'checking' 
              : widget.formData.bankAccount.accountType,
          decoration: _inputDecoration(l10n.select_account_type),
          items: [
            DropdownMenuItem(value: 'checking', child: Text(l10n.account_checking)),
            DropdownMenuItem(value: 'savings', child: Text(l10n.account_savings)),
          ],
          onChanged: (value) {
            widget.formData.bankAccount.accountType = value ?? 'checking';
          },
        ),
      ],
    );
  }

  Widget _buildMexicoBankFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLABE (Clave Bancaria Estandarizada)',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '18 dígitos - incluye banco, plaza y cuenta',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        BarzMaskedField(
          hintText: '000000000000000000',
          customMask: '### ### #### #### ##',
          maskType: BarzMaskType.custom,
          initialValue: widget.formData.bankAccount.clabe,
          onUnmaskedChanged: (value) {
            widget.formData.bankAccount.clabe = value;
            _checkFormValidity();
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.account_holder_name, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.accountHolderName,
          decoration: _inputDecoration('Restaurant Name S.A. de C.V.'),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            widget.formData.bankAccount.accountHolderName = value;
            _checkFormValidity();
          },
        ),
      ],
    );
  }

  Widget _buildArgentinaBankFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CBU (Clave Bancaria Uniforme)',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '22 dígitos - identificador único de cuenta',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        BarzMaskedField(
          hintText: '0000000000000000000000',
          customMask: '####### ############### #',
          maskType: BarzMaskType.custom,
          initialValue: widget.formData.bankAccount.cbu,
          onUnmaskedChanged: (value) {
            widget.formData.bankAccount.cbu = value;
            _checkFormValidity();
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.account_holder_name, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.accountHolderName,
          decoration: _inputDecoration('Restaurant Name S.R.L.'),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            widget.formData.bankAccount.accountHolderName = value;
            _checkFormValidity();
          },
        ),
      ],
    );
  }

  Widget _buildUSABankFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.routing_number, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          'ABA Routing Number (9 digits)',
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.routingNumber,
          decoration: _inputDecoration('110000000'),
          keyboardType: TextInputType.number,
          maxLength: 9,
          onChanged: (value) {
            widget.formData.bankAccount.routingNumber = value;
            _checkFormValidity();
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.account_number, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.accountNumber,
          decoration: _inputDecoration('000123456789'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            widget.formData.bankAccount.accountNumber = value;
            _checkFormValidity();
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.account_type, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: widget.formData.bankAccount.accountType.isEmpty 
              ? 'checking' 
              : widget.formData.bankAccount.accountType,
          decoration: _inputDecoration(l10n.select_account_type),
          items: [
            DropdownMenuItem(value: 'checking', child: Text(l10n.account_checking)),
            DropdownMenuItem(value: 'savings', child: Text(l10n.account_savings)),
          ],
          onChanged: (value) {
            widget.formData.bankAccount.accountType = value ?? 'checking';
          },
        ),
      ],
    );
  }

  Widget _buildGenericBankFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.account_number, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.accountNumber,
          decoration: _inputDecoration(l10n.account_number_hint),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            widget.formData.bankAccount.accountNumber = value;
            _checkFormValidity();
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.account_holder_name, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.formData.bankAccount.accountHolderName,
          decoration: _inputDecoration(l10n.account_holder_hint),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            widget.formData.bankAccount.accountHolderName = value;
            _checkFormValidity();
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: barzGoldMuted,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BarzRadii.md),
        borderSide: const BorderSide(color: barzGold, width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  void _validateAndProceed() {
    // Basic validation - at least business ID if required
    if (_countryConfig.requiresBusinessId && widget.formData.businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_countryConfig.businessIdLabel} is required'),
          backgroundColor: errorRed,
        ),
      );
      return;
    }

    // Validate bank account based on country
    final bank = widget.formData.bankAccount;
    bool hasBankInfo = false;

    switch (_countryConfig.code) {
      case CountryCode.br:
        hasBankInfo = _usePixKey 
            ? bank.pixKey.isNotEmpty 
            : (bank.bankCode.isNotEmpty && bank.branchCode.isNotEmpty && bank.accountNumber.isNotEmpty);
        break;
      case CountryCode.mx:
        hasBankInfo = bank.clabe.length == 18;
        break;
      case CountryCode.ar:
        hasBankInfo = bank.cbu.length == 22;
        break;
      case CountryCode.us:
        hasBankInfo = bank.routingNumber.length == 9 && bank.accountNumber.isNotEmpty;
        break;
      default:
        hasBankInfo = bank.accountNumber.isNotEmpty;
    }

    if (!hasBankInfo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.bank_account_required),
          backgroundColor: errorRed,
        ),
      );
      return;
    }

    widget.onNext();
  }
}
