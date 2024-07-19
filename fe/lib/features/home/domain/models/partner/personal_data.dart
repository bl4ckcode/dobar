import 'partner_document.dart';

interface class PersonalData {
  final String completeAddress;
  final PartnerDocument nationalId;
  final String email;
  final String name;

  PersonalData(this.completeAddress, this.nationalId, this.email, this.name);

  void getAddress() {}
}
