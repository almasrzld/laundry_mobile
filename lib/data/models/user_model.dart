class AddressModel {
  final String id;
  final String label;
  final String fullAddress;
  final String note;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.note = '',
    this.isDefault = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? json['id_addresses']?.toString() ?? json['id_user_addresses']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name_user_addresses']?.toString() ?? '',
      fullAddress: json['full_address']?.toString() ?? json['address']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'full_address': fullAddress,
      'note': note,
      'is_default': isDefault,
    };
  }

  AddressModel copyWith({
    String? id,
    String? label,
    String? fullAddress,
    String? note,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      note: note ?? this.note,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? userCode;
  final String roleCode;
  final String memberTier;
  final int laundryPayBalance;
  final int rewardPoints;
  final List<AddressModel> addresses;
  final List<String> permissions;
  final int failedLoginAttempts;
  final int lockoutStage;
  final String? lockedUntil;
  final bool isPermanentlyLocked;
  final bool hasSecurityQuestions;
  final String? question1;
  final String? question2;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.userCode,
    this.roleCode = 'customer',
    this.memberTier = '',
    this.laundryPayBalance = 0,
    this.rewardPoints = 0,
    required this.addresses,
    this.permissions = const [],
    this.failedLoginAttempts = 0,
    this.lockoutStage = 0,
    this.lockedUntil,
    this.isPermanentlyLocked = false,
    this.hasSecurityQuestions = false,
    this.question1,
    this.question2,
  });

  AddressModel? get defaultAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
  }

  bool get isCourier =>
      roleCode.toLowerCase().contains('kurir') ||
      roleCode.toLowerCase().contains('courier');

  bool get isCustomer =>
      roleCode.isEmpty ||
      roleCode.toLowerCase().contains('customer') ||
      roleCode.toLowerCase().contains('pelanggan');

  String get displayName => name.isNotEmpty ? name : 'Pengguna';

  /// Memeriksa apakah user memiliki hak akses tertentu (secara dinamis dari database)
  bool hasPermission(String code) {
    if (permissions.contains('*')) return true;
    final target = code.toLowerCase().trim().replaceAll('-', '_');
    return permissions.any((p) {
      final norm = p.toLowerCase().trim().replaceAll('-', '_');
      return norm == target;
    });
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    var rawAddresses = json['addresses'];
    List<AddressModel> addressList = [];
    if (rawAddresses is List) {
      addressList = rawAddresses.map((a) => AddressModel.fromJson(a as Map<String, dynamic>)).toList();
    } else if (json['address'] != null && json['address'].toString().trim().isNotEmpty) {
      addressList.add(AddressModel(
        id: json['id_user_addresses']?.toString() ?? '1',
        label: 'Alamat',
        fullAddress: json['address'].toString(),
        isDefault: true,
      ));
    }

    final sq = json['security_questions'];
    String? q1;
    String? q2;
    if (sq is Map<String, dynamic>) {
      q1 = sq['question_1']?.toString();
      q2 = sq['question_2']?.toString();
    } else if (json['question_1'] != null || json['question_2'] != null) {
      q1 = json['question_1']?.toString();
      q2 = json['question_2']?.toString();
    }

    final hasSq = json['has_security_questions'] == true ||
        json['has_security_questions'] == 1 ||
        (q1 != null && q1.isNotEmpty);

    final rawPerms = json['permissions'];
    List<String> permList = [];
    if (rawPerms is List) {
      permList = rawPerms.map((p) => p.toString().trim()).toList();
    }

    return UserModel(
      id: json['id']?.toString() ?? json['id_users']?.toString() ?? '',
      name: json['name']?.toString() ?? json['name_users']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? json['code']?.toString(),
      roleCode: json['role_code']?.toString() ?? json['role']?.toString() ?? 'customer',
      memberTier: json['member_tier']?.toString() ?? '',
      laundryPayBalance: (json['laundry_pay_balance'] as num?)?.toInt() ?? 0,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      addresses: addressList,
      permissions: permList,
      failedLoginAttempts: (json['failed_login_attempts'] as num?)?.toInt() ?? 0,
      lockoutStage: (json['lockout_stage'] as num?)?.toInt() ?? 0,
      lockedUntil: json['locked_until']?.toString(),
      isPermanentlyLocked: json['is_permanently_locked'] == true || json['is_permanently_locked'] == 1,
      hasSecurityQuestions: hasSq,
      question1: q1,
      question2: q2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'user_code': userCode,
      'role_code': roleCode,
      'member_tier': memberTier,
      'laundry_pay_balance': laundryPayBalance,
      'reward_points': rewardPoints,
      'addresses': addresses.map((a) => a.toJson()).toList(),
      'permissions': permissions,
      'failed_login_attempts': failedLoginAttempts,
      'lockout_stage': lockoutStage,
      'locked_until': lockedUntil,
      'is_permanently_locked': isPermanentlyLocked,
      'has_security_questions': hasSecurityQuestions,
      if (question1 != null || question2 != null)
        'security_questions': {
          'question_1': question1,
          'question_2': question2,
        },
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? userCode,
    String? roleCode,
    String? memberTier,
    int? laundryPayBalance,
    int? rewardPoints,
    List<AddressModel>? addresses,
    List<String>? permissions,
    int? failedLoginAttempts,
    int? lockoutStage,
    String? lockedUntil,
    bool? isPermanentlyLocked,
    bool? hasSecurityQuestions,
    String? question1,
    String? question2,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userCode: userCode ?? this.userCode,
      roleCode: roleCode ?? this.roleCode,
      memberTier: memberTier ?? this.memberTier,
      laundryPayBalance: laundryPayBalance ?? this.laundryPayBalance,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      addresses: addresses ?? this.addresses,
      permissions: permissions ?? this.permissions,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      lockoutStage: lockoutStage ?? this.lockoutStage,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      isPermanentlyLocked: isPermanentlyLocked ?? this.isPermanentlyLocked,
      hasSecurityQuestions: hasSecurityQuestions ?? this.hasSecurityQuestions,
      question1: question1 ?? this.question1,
      question2: question2 ?? this.question2,
    );
  }

  static UserModel get empty => const UserModel(
        id: '',
        name: '',
        email: '',
        phone: '',
        memberTier: '',
        laundryPayBalance: 0,
        rewardPoints: 0,
        addresses: [],
        permissions: [],
        hasSecurityQuestions: false,
      );
}
