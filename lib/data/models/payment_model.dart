class XenditPaymentResultModel {
  final String orderId;
  final String invoiceNo;
  final String referenceId;
  final String paymentType; // 'QRIS' | 'VIRTUAL_ACCOUNT' | 'EWALLET'
  final String paymentMethod;
  final String? bankCode;
  final String? accountNumber;
  final String? accountName;
  final String? qrId;
  final String qrString;
  final String? checkoutUrl;
  final int amount;
  final DateTime? expiresAt;
  final String status;
  final String serviceName;

  final String? proofImage;

  const XenditPaymentResultModel({
    required this.orderId,
    required this.invoiceNo,
    required this.referenceId,
    this.paymentType = 'QRIS',
    this.paymentMethod = 'QRIS',
    this.bankCode,
    this.accountNumber,
    this.accountName,
    this.qrId,
    this.qrString = '',
    this.checkoutUrl,
    this.proofImage,
    required this.amount,
    this.expiresAt,
    this.status = 'PENDING',
    this.serviceName = '',
  });

  factory XenditPaymentResultModel.fromJson(Map<String, dynamic> json) {
    return XenditPaymentResultModel(
      orderId: json['order_id']?.toString() ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      paymentType: json['payment_type']?.toString() ?? (json['bank_code'] != null ? 'VIRTUAL_ACCOUNT' : 'QRIS'),
      paymentMethod: json['payment_method']?.toString() ?? 'QRIS',
      bankCode: json['bank_code']?.toString(),
      accountNumber: json['account_number']?.toString() ?? json['qr_string']?.toString(),
      accountName: json['account_name']?.toString(),
      qrId: json['qr_id']?.toString(),
      qrString: json['qr_string']?.toString() ?? '',
      checkoutUrl: json['checkout_url']?.toString(),
      proofImage: json['proof_image']?.toString(),
      amount: int.tryParse(json['amount']?.toString() ?? '') ?? 0,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      status: json['status']?.toString() ?? 'PENDING',
      serviceName: json['service_name']?.toString() ?? '',
    );
  }

  bool get isVa => paymentType == 'VIRTUAL_ACCOUNT' || bankCode != null;
  bool get isEwallet => paymentType == 'EWALLET';
  bool get isQris => !isVa && !isEwallet;
}

class PaymentProofResultModel {
  final String orderId;
  final String invoiceNo;
  final String proofImage;
  final int fileSizeKb;
  final String format;
  final String status;
  final String message;

  const PaymentProofResultModel({
    required this.orderId,
    required this.invoiceNo,
    required this.proofImage,
    required this.fileSizeKb,
    required this.format,
    required this.status,
    required this.message,
  });

  factory PaymentProofResultModel.fromJson(Map<String, dynamic> json) {
    return PaymentProofResultModel(
      orderId: json['order_id']?.toString() ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? '',
      proofImage: json['proof_image']?.toString() ?? '',
      fileSizeKb: (json['file_size_kb'] as num?)?.toInt() ?? 0,
      format: json['format']?.toString() ?? 'webp',
      status: json['status']?.toString() ?? 'WAITING_VERIFICATION',
      message: json['message']?.toString() ?? '',
    );
  }
}

typedef XenditQrisPaymentModel = XenditPaymentResultModel;

