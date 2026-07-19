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

  /// Whether this entry adds money to the wallet (shown as `+`) vs. removes
  /// it (shown as `-`). The backend doesn't expose a signed amount or an
  /// explicit direction field, so this infers it from `type` — kept broad
  /// on purpose since we don't have a confirmed enum of every value the
  /// backend can send (e.g. "topup", "wallet_topup", "deposit" all plausibly
  /// mean the same thing).
  bool get isCredit {
    final t = type.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    const creditKeywords = ['deposit', 'topup', 'payout', 'refund', 'credit', 'received', 'reversal'];
    const debitKeywords = ['withdraw', 'contribution', 'debit', 'payment'];

    if (debitKeywords.any(t.contains)) return false;
    return creditKeywords.any(t.contains);
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

/// From `GET /users/me/wallet/transactions/{id}` — a single transaction
/// rendered as a receipt (amounts, names, dates, references).
class TransactionReceipt {
  final String transactionId;
  final String type;
  final double amount;
  final String status;
  final DateTime date;
  final String? senderName;
  final String? recipientName;
  final String? narration;
  final String? reference;

  const TransactionReceipt({
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.status,
    required this.date,
    this.senderName,
    this.recipientName,
    this.narration,
    this.reference,
  });

  factory TransactionReceipt.fromJson(Map<String, dynamic> json) {
    return TransactionReceipt(
      transactionId: json['transaction_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      senderName: json['sender_name']?.toString(),
      recipientName: json['recipient_name']?.toString(),
      narration: json['narration']?.toString(),
      reference: json['reference']?.toString(),
    );
  }
}

/// From `GET /users/me/wallet/lookup` — used to confirm who owns a wallet
/// before sending them a transfer.
class UserByAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String personalReservedAccountNumber;
  final String? personalReservedAccountName;

  const UserByAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.personalReservedAccountNumber,
    this.personalReservedAccountName,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserByAccount.fromJson(Map<String, dynamic> json) {
    return UserByAccount(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      personalReservedAccountNumber: json['personal_reserved_account_number']?.toString() ?? '',
      personalReservedAccountName: json['personal_reserved_account_name']?.toString(),
    );
  }
}
