class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final String? relatedGroupId;
  final String? narration;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.relatedGroupId,
    this.narration,
    required this.createdAt,
  });

  bool get isCredit {
    final t = type.toLowerCase();
    return t.contains('deposit') || t.contains('payout') || t.contains('refund') || t.contains('credit');
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      relatedGroupId: json['related_group_id']?.toString(),
      narration: json['narration']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
