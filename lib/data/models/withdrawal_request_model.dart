class WithdrawalRequestModel {
  final String id;
  final int usersId;
  final int amount;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String status;
  final String? adminNotes;
  final String? proofImage;
  final DateTime? createdAt;
  final DateTime? processedAt;

  WithdrawalRequestModel({
    required this.id,
    required this.usersId,
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.status,
    this.adminNotes,
    this.proofImage,
    this.createdAt,
    this.processedAt,
  });

  factory WithdrawalRequestModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequestModel(
      id: json['id_withdrawal_requests']?.toString() ?? json['id']?.toString() ?? '',
      usersId: int.tryParse(json['users_id']?.toString() ?? '0') ?? 0,
      amount: (num.tryParse(json['amount']?.toString() ?? '0') ?? 0).toInt(),
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      adminNotes: json['admin_notes']?.toString(),
      proofImage: json['proof_image']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      processedAt: json['processed_at'] != null ? DateTime.tryParse(json['processed_at'].toString()) : null,
    );
  }

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isRejected => status.toLowerCase() == 'rejected';

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Selesai Ditransfer';
      case 'rejected':
        return 'Ditolak (Saldo Dikembalikan)';
      case 'pending':
      default:
        return 'Menunggu Verifikasi Admin';
    }
  }
}
