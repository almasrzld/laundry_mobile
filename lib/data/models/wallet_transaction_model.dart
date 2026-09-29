class WalletTransactionModel {
  final String id;
  final String? orderId;
  final String type; // 'credit' or 'debit'
  final String category; // 'tip', 'topup', 'payment', 'withdrawal', 'refund'
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final String title;
  final String? description;
  final String? referenceNo;
  final String? invoiceNo;
  final String? customerName;
  final DateTime? createdAt;

  const WalletTransactionModel({
    required this.id,
    this.orderId,
    required this.type,
    required this.category,
    required this.amount,
    this.balanceBefore = 0,
    this.balanceAfter = 0,
    required this.title,
    this.description,
    this.referenceNo,
    this.invoiceNo,
    this.customerName,
    this.createdAt,
  });

  bool get isCredit => type.toLowerCase() == 'credit';

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id']?.toString() ?? json['id_wallet_transactions']?.toString() ?? '',
      orderId: json['orders_id']?.toString() ?? json['order_id']?.toString(),
      type: json['type']?.toString() ?? 'credit',
      category: json['category']?.toString() ?? 'tip',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balanceBefore: (json['balance_before'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Transaksi',
      description: json['description']?.toString(),
      referenceNo: json['reference_no']?.toString() ?? json['invoice_no']?.toString(),
      invoiceNo: json['invoice_no']?.toString() ?? json['reference_no']?.toString(),
      customerName: json['customer_name']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'type': type,
      'category': category,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'title': title,
      'description': description,
      'reference_no': referenceNo,
      'invoice_no': invoiceNo,
      'customer_name': customerName,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
