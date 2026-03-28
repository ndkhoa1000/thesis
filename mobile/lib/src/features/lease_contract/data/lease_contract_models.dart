class LeaseContractSummary {
  const LeaseContractSummary({
    required this.contractId,
    required this.leaseId,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.managerId,
    required this.managerUserId,
    required this.operatorName,
    required this.operatorEmail,
    required this.ownerName,
    required this.ownerEmail,
    required this.leaseStatus,
    required this.contractStatus,
    required this.monthlyFee,
    required this.revenueSharePercentage,
    required this.termMonths,
    required this.contractNumber,
    required this.generatedAt,
    this.content,
    this.startDate,
    this.endDate,
  });

  final int contractId;
  final int leaseId;
  final int parkingLotId;
  final String parkingLotName;
  final int managerId;
  final int managerUserId;
  final String operatorName;
  final String operatorEmail;
  final String ownerName;
  final String ownerEmail;
  final String leaseStatus;
  final String contractStatus;
  final double monthlyFee;
  final double revenueSharePercentage;
  final int termMonths;
  final String contractNumber;
  final String? content;
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isPending => leaseStatus == 'PENDING' && contractStatus == 'DRAFT';

  factory LeaseContractSummary.fromJson(Map<String, dynamic> json) {
    return LeaseContractSummary(
      contractId: json['contract_id'] as int,
      leaseId: json['lease_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      managerId: json['manager_id'] as int,
      managerUserId: json['manager_user_id'] as int,
      operatorName: json['operator_name'] as String,
      operatorEmail: json['operator_email'] as String,
      ownerName: json['owner_name'] as String,
      ownerEmail: json['owner_email'] as String,
      leaseStatus: json['lease_status'] as String,
      contractStatus: json['contract_status'] as String,
      monthlyFee: (json['monthly_fee'] as num).toDouble(),
      revenueSharePercentage: (json['revenue_share_percentage'] as num)
          .toDouble(),
      termMonths: json['term_months'] as int,
      contractNumber: json['contract_number'] as String,
      content: json['content'] as String?,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      startDate: _parseDateTime(json['start_date']),
      endDate: _parseDateTime(json['end_date']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
