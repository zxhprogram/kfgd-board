import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../features/business_orders/data/business_order_models.dart';
import 'pro_id_normalizer.dart';

class ProIdParseResult {
  const ProIdParseResult({
    required this.orders,
    required this.rawCount,
    required this.duplicateCount,
  });

  final List<BusinessOrderImportItem> orders;
  final int rawCount;
  final int duplicateCount;
}

ProIdParseResult parseExcelProIds(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = _firstNonEmptySheet(excel);
  if (sheet == null) {
    return const ProIdParseResult(orders: [], rawCount: 0, duplicateCount: 0);
  }

  final proIdColumn = _findHeaderColumn(sheet, const {
    'proid',
    '工单编号',
    '工单号',
    '问题单号',
  });
  final externalNoColumn = _findHeaderColumn(sheet, const {'外系统单号'});
  final values = <BusinessOrderImportItem>[];

  if (proIdColumn != null) {
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final proId = normalizeProId(_cellValue(sheet, proIdColumn, rowIndex));
      if (proId != null) {
        values.add(
          BusinessOrderImportItem(
            proId: proId,
            externalNo: _normalizeExternalNo(
              externalNoColumn == null
                  ? null
                  : _cellValue(sheet, externalNoColumn, rowIndex),
            ),
          ),
        );
      }
    }
  } else {
    for (final row in sheet.rows) {
      for (final cell in row) {
        final proId = normalizeProId(cell?.value);
        if (proId != null && RegExp(r'^\d{12,}$').hasMatch(proId)) {
          values.add(BusinessOrderImportItem(proId: proId, externalNo: ''));
        }
      }
    }
  }

  final seen = <String>{};
  final unique = <BusinessOrderImportItem>[];
  var duplicateCount = 0;
  for (final value in values) {
    if (seen.add(value.proId)) {
      unique.add(value);
    } else {
      duplicateCount++;
    }
  }

  return ProIdParseResult(
    orders: unique,
    rawCount: values.length,
    duplicateCount: duplicateCount,
  );
}

Object? _cellValue(Sheet sheet, int columnIndex, int rowIndex) {
  return sheet
      .cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      )
      .value;
}

String _normalizeExternalNo(Object? value) {
  return value?.toString().trim() ?? '';
}

Sheet? _firstNonEmptySheet(Excel excel) {
  for (final tableName in excel.tables.keys) {
    final table = excel.tables[tableName];
    if (table != null && table.maxRows > 0) {
      return table;
    }
  }
  return null;
}

int? _findHeaderColumn(Sheet sheet, Set<String> headers) {
  if (sheet.maxRows == 0) {
    return null;
  }
  final firstRow = sheet.rows.first;
  for (var index = 0; index < firstRow.length; index++) {
    final value = firstRow[index]?.value?.toString().trim();
    if (value == null) {
      continue;
    }
    if (headers.contains(value.toLowerCase())) {
      return index;
    }
  }
  return null;
}
