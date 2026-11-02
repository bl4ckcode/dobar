import 'package:flutter/material.dart';
import 'package:barz/core/design/design_system.dart';
import 'venue_registration_view.dart';

class CreateBarPage extends StatelessWidget {
  final bool fromOnboarding;
  const CreateBarPage({super.key, this.fromOnboarding = false});

  @override
  Widget build(BuildContext context) =>
      VenueRegistrationView(fromOnboarding: fromOnboarding);
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
      name.isNotEmpty &&
      address.isNotEmpty &&
      phone.isNotEmpty &&
      email.isNotEmpty;

  bool get isLocationValid => latitude != null && longitude != null;

  CountryFormConfig get countryConfig =>
      CountryFormConfig.forCountry(countryCode);
}

/// Bank account data for payouts - varies by country
class BankAccountData {
  // Brazil-specific
  String bankCode = ''; // 3 digits (e.g., 001 = Banco do Brasil)
  String branchCode = ''; // 4 digits (agência)
  String pixKey = ''; // CPF/CNPJ/email/phone/random
  String pixKeyType = ''; // cpf | cnpj | email | phone | random

  // Mexico
  String clabe = ''; // 18 digits - Clave Bancaria Estandarizada

  // Argentina
  String cbu = ''; // 22 digits - Clave Bancaria Uniforme

  // USA
  String routingNumber = ''; // 9 digits (ABA routing)

  // Common fields
  String accountNumber = '';
  String accountType = ''; // checking | savings
  String accountHolderName = '';

  Map<String, dynamic> toJson(String countryCode) {
    final base = {'country_code': countryCode.toUpperCase()};

    switch (countryCode.toUpperCase()) {
      case 'BR':
        if (pixKey.isNotEmpty) {
          return {
            ...base,
            'pix_key': pixKey,
            if (pixKeyType.isNotEmpty) 'pix_key_type': pixKeyType,
          };
        }
        return {
          ...base,
          'bank_code': bankCode,
          'branch_code': branchCode,
          'account_number': accountNumber,
          if (accountType.isNotEmpty) 'account_type': accountType,
        };
      case 'MX':
        return {
          ...base,
          'clabe': clabe,
          if (accountHolderName.isNotEmpty)
            'account_holder_name': accountHolderName,
        };
      case 'AR':
        return {
          ...base,
          'cbu': cbu,
          if (accountHolderName.isNotEmpty)
            'account_holder_name': accountHolderName,
        };
      case 'US':
        return {
          ...base,
          'routing_number': routingNumber,
          'account_number': accountNumber,
          if (accountType.isNotEmpty) 'account_type': accountType,
        };
      default:
        return {
          ...base,
          'account_number': accountNumber,
          if (accountHolderName.isNotEmpty)
            'account_holder_name': accountHolderName,
        };
    }
  }
}

class OperatingHours {
  final bool isOpen;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;

  OperatingHours({this.isOpen = false, this.openTime, this.closeTime});
}
