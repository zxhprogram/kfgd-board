import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../data/business_order_models.dart';

class BusinessOrderTable extends StatefulWidget {
  const BusinessOrderTable({super.key, required this.items});

  final List<BusinessOrderItem> items;

  @override
  State<BusinessOrderTable> createState() => _BusinessOrderTableState();
}

class _BusinessOrderTableState extends State<BusinessOrderTable> {
  PlutoGridStateManager? _stateManager;

  static List<PlutoColumn> _buildColumns() {
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
      ),
      PlutoColumn(
        title: '创建时间',
        field: 'createTime',
        type: PlutoColumnType.text(),
        width: 180,
        readOnly: true,
      ),
      PlutoColumn(
        title: '更新时间',
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
      configuration: const PlutoGridConfiguration(
        columnSize: PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.none,
        ),
      ),
    );
  }
}
