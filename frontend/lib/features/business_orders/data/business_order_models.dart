class ImportBusinessOrdersResponse {
  const ImportBusinessOrdersResponse({
    required this.requested,
    required this.imported,
  });

  final int requested;
  final int imported;

  factory ImportBusinessOrdersResponse.fromJson(Map<String, dynamic> json) {
    return ImportBusinessOrdersResponse(
      requested: (json['requested'] as num?)?.toInt() ?? 0,
      imported: (json['imported'] as num?)?.toInt() ?? 0,
    );
  }
}

class BusinessOrderPage {
  const BusinessOrderPage({
    required this.items,
    required this.pageNo,
    required this.pageSize,
    required this.total,
  });

  final List<BusinessOrderItem> items;
  final int pageNo;
  final int pageSize;
  final int total;

  factory BusinessOrderPage.fromJson(Map<String, dynamic> json) {
    return BusinessOrderPage(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => BusinessOrderItem.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
      pageNo: (json['pageNo'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class BusinessOrderItem {
  const BusinessOrderItem({
    required this.proId,
    required this.proTitle,
    required this.customerName,
    required this.customerPhone,
    required this.proState,
    required this.createTime,
    required this.updateTime,
    required this.savedAt,
    required this.raw,
  });

  final String proId;
  final String proTitle;
  final String customerName;
  final String customerPhone;
  final int proState;
  final String createTime;
  final String updateTime;
  final String savedAt;
  final Map<String, dynamic> raw;

  factory BusinessOrderItem.fromJson(Map<String, dynamic> json) {
    return BusinessOrderItem(
      proId: json['proId']?.toString() ?? '',
      proTitle: json['proTitle']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      proState: (json['proState'] as num?)?.toInt() ?? 0,
      createTime: json['createTime']?.toString() ?? '',
      updateTime: json['updateTime']?.toString() ?? '',
      savedAt: json['savedAt']?.toString() ?? '',
      raw: (json['raw'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
