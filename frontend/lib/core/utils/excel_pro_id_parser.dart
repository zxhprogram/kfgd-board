import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'pro_id_normalizer.dart';

class ProIdParseResult {
  const ProIdParseResult({
    required this.proIds,
    required this.rawCount,
    required this.duplicateCount,
  });

  final List<String> proIds;
  final int rawCount;
  final int duplicateCount;
}

ProIdParseResult parseExcelProIds(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = _firstNonEmptySheet(excel);
  if (sheet == null) {
    return const ProIdParseResult(proIds: [], rawCount: 0, duplicateCount: 0);
  }

  final headerColumn = _findProIdHeaderColumn(sheet);
  final values = <String>[];
  if (headerColumn != null) {
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final cell = sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: headerColumn,
              rowIndex: rowIndex,
            ),
          )
          .value;
      final proId = normalizeProId(cell);
      if (proId != null) {
        values.add(proId);
      }
    }
  } else {
    for (final row in sheet.rows) {
      for (final cell in row) {
        final proId = normalizeProId(cell?.value);
        if (proId != null && RegExp(r'^\d{12,}$').hasMatch(proId)) {
          values.add(proId);
        }
      }
    }
  }

  final seen = <String>{};
  final unique = <String>[];
  var duplicateCount = 0;
  for (final value in values) {
    if (seen.add(value)) {
      unique.add(value);
    } else {
      duplicateCount++;
    }
  }

  return ProIdParseResult(
    proIds: unique,
    rawCount: values.length,
    duplicateCount: duplicateCount,
  );
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

int? _findProIdHeaderColumn(Sheet sheet) {
  if (sheet.maxRows == 0) {
    return null;
  }
  const headers = {'proid', '工单号', '问题单号'};
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
