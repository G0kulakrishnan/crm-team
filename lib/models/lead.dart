class Lead {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String source;
  final String stage;
  final String requirement;
  final String assign;
  final String followup;
  final String notes;
  final String companyName;
  final String productCat;
  final DateTime? createdDate;
  final Map<String, dynamic> custom;

  Lead({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.source,
    required this.stage,
    required this.requirement,
    required this.assign,
    required this.followup,
    required this.notes,
    required this.companyName,
    required this.productCat,
    this.createdDate,
    this.custom = const {},
  });

  /// Create from API response
  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      source: json['source'] ?? '',
      stage: json['stage'] ?? '',
      requirement: json['requirement'] ?? '',
      assign: json['assign'] ?? '',
      followup: json['followup'] ?? '',
      notes: json['notes'] ?? '',
      companyName: json['companyName'] ?? '',
      productCat: json['productCat'] ?? '',
      createdDate: json['createdDate'] != null
          ? DateTime.tryParse(json['createdDate'].toString())
          : null,
      custom: Map<String, dynamic>.from(json['custom'] ?? {}),
    );
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'source': source,
      'stage': stage,
      'requirement': requirement,
      'assign': assign,
      'followup': followup,
      'notes': notes,
      'companyName': companyName,
      'productCat': productCat,
      'custom': custom,
    };
  }

  /// Helper: check if has phone
  bool get hasPhone => phone.isNotEmpty;

  /// Helper: check if has email
  bool get hasEmail => email.isNotEmpty;

  /// Helper: WhatsApp phone format
  String get waPhone {
    // Remove +, spaces, dashes from phone
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    // If doesn't start with country code, assume 91 (India)
    if (!clean.startsWith('91') && clean.length == 10) {
      clean = '91$clean';
    }
    return clean;
  }

  /// Copy with new values
  Lead copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? source,
    String? stage,
    String? requirement,
    String? assign,
    String? followup,
    String? notes,
    String? companyName,
    String? productCat,
    DateTime? createdDate,
    Map<String, dynamic>? custom,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      source: source ?? this.source,
      stage: stage ?? this.stage,
      requirement: requirement ?? this.requirement,
      assign: assign ?? this.assign,
      followup: followup ?? this.followup,
      notes: notes ?? this.notes,
      companyName: companyName ?? this.companyName,
      productCat: productCat ?? this.productCat,
      createdDate: createdDate ?? this.createdDate,
      custom: custom ?? this.custom,
    );
  }
}
