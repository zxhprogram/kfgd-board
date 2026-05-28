import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../data/business_order_models.dart';

class BusinessOrderTable extends StatefulWidget {
  const BusinessOrderTable({
    super.key,
    required this.items,
    this.onRowTap,
  });

  final List<BusinessOrderItem> items;
  final void Function(BusinessOrderItem item)? onRowTap;

  @override
  State<BusinessOrderTable> createState() => _BusinessOrderTableState();
}

class _BusinessOrderTableState extends State<BusinessOrderTable> {
  PlutoGridStateManager? _stateManager;

  static bool _isDurationOverdue(String duration) {
    if (duration.isEmpty) return false;
    final match = RegExp(r'(\d+)d').firstMatch(duration);
    if (match == null) return false;
    final days = int.tryParse(match.group(1) ?? '0') ?? 0;
    return days >= 5;
  }

  List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(
        title: '工单编号',
        field: 'proId',
        type: PlutoColumnType.text(),
        frozen: PlutoColumnFrozen.start,
        enableFilterMenuItem: true,
        enableContextMenu: true,
        width: 200,
        readOnly: true,
        renderer: (context) {
          final value = context.cell.value?.toString() ?? '';
          return InkWell(
            onTap: () {
              final rowIdx = context.rowIdx;
              if (widget.onRowTap != null && rowIdx < widget.items.length) {
                widget.onRowTap!(widget.items[rowIdx]);
              }
            },
            child: Center(
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          );
        },
      ),
      PlutoColumn(
        title: '外系统单号',
        field: 'externalNo',
        type: PlutoColumnType.text(),
        enableFilterMenuItem: true,
        enableContextMenu: true,
        width: 170,
        readOnly: true,
      ),
      PlutoColumn(
        title: '标题',
        field: 'proTitle',
        type: PlutoColumnType.text(),
        width: 300,
        readOnly: true,
      ),
      PlutoColumn(
        title: '客户',
        field: 'customerName',
        type: PlutoColumnType.text(),
        width: 130,
        readOnly: true,
      ),
      PlutoColumn(
        title: '电话',
        field: 'customerPhone',
        type: PlutoColumnType.text(),
        width: 140,
        readOnly: true,
      ),
      PlutoColumn(
        title: '状态',
        field: 'proState',
        type: PlutoColumnType.text(),
        width: 80,
        readOnly: true,
        renderer: (context) {
          final value = context.cell.value?.toString() ?? '';
          const stateLabels = {'1': '待处理', '7': '已关闭', '61': '已处理待确认'};
          return Text(stateLabels[value] ?? value);
        },
      ),
      PlutoColumn(
        title: '处理时长',
        field: 'processDuration',
        type: PlutoColumnType.text(),
        width: 120,
        readOnly: true,
        renderer: (context) {
          final value = context.cell.value?.toString() ?? '';
          final overdue = _isDurationOverdue(value);
          return Text(
            value,
            style: TextStyle(
              color: overdue ? Colors.red : null,
              fontWeight: overdue ? FontWeight.bold : null,
            ),
          );
        },
      ),
      PlutoColumn(
        title: '开始时间',
        field: 'createTime',
        type: PlutoColumnType.text(),
        width: 180,
        readOnly: true,
      ),
      PlutoColumn(
        title: '解决时间',
        field: 'updateTime',
        type: PlutoColumnType.text(),
        width: 180,
        readOnly: true,
      ),
      PlutoColumn(
        title: '保存时间',
        field: 'savedAt',
        type: PlutoColumnType.text(),
        width: 180,
        readOnly: true,
      ),
    ];
  }

  static List<PlutoRow> _buildRows(List<BusinessOrderItem> items) {
    return items
        .map(
          (item) => PlutoRow(
            cells: {
              'proId': PlutoCell(value: item.proId),
              'externalNo': PlutoCell(value: item.externalNo),
              'proTitle': PlutoCell(value: item.proTitle),
              'customerName': PlutoCell(value: item.customerName),
              'customerPhone': PlutoCell(value: item.customerPhone),
              'proState': PlutoCell(value: item.proState.toString()),
              'processDuration': PlutoCell(value: item.processDuration),
              'createTime': PlutoCell(value: item.createTime),
              'updateTime': PlutoCell(value: item.updateTime),
              'savedAt': PlutoCell(value: item.savedAt),
            },
          ),
        )
        .toList();
  }

  @override
  void didUpdateWidget(covariant BusinessOrderTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_stateManager != null && widget.items != oldWidget.items) {
      final newRows = _buildRows(widget.items);
      _stateManager!.removeRows(_stateManager!.rows);
      _stateManager!.insertRows(0, newRows);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlutoGrid(
      columns: _buildColumns(),
      rows: _buildRows(widget.items),
      mode: PlutoGridMode.readOnly,
      onLoaded: (event) {
        _stateManager = event.stateManager;
      },
      noRowsWidget: const Center(child: Text('暂无已导入数据')),
      rowColorCallback: (rowColorContext) {
        final duration =
            rowColorContext.row.cells['processDuration']?.value?.toString() ??
                '';
        if (_isDurationOverdue(duration)) {
          return Colors.red.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      },
      configuration: const PlutoGridConfiguration(
        columnSize: PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.none,
        ),
      ),
    );
  }
}
