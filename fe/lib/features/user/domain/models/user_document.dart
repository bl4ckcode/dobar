enum DocumentType { cpf, rg, passport, other }

class UserDocument {
  final int? id;
  final DocumentType type;
  final String number;
  final String? issuingAuthority;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final bool verified;

  UserDocument({
    this.id,
    required this.type,
    required this.number,
    this.issuingAuthority,
    this.issueDate,
    this.expiryDate,
    this.verified = false,
  });

  factory UserDocument.fromJson(Map<String, dynamic> json) {
    return UserDocument(
      id: json['id'],
      type: DocumentType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DocumentType.other),
      number: json['number'],
      issuingAuthority: json['issuing_authority'],
      issueDate: json['issue_date'] != null
          ? DateTime.parse(json['issue_date'])
          : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
      verified: json['verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'number': number,
      'issuing_authority': issuingAuthority,
      'issue_date': issueDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'verified': verified,
    };
  }
}
