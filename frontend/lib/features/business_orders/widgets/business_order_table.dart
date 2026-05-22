import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../data/business_order_models.dart';

class BusinessOrderTable extends StatelessWidget {
  const BusinessOrderTable({super.key, required this.items});

  final List<BusinessOrderItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('暂无已导入数据'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        columnWidths: const {
          0: FixedTableSize(190),
          1: FixedTableSize(160),
          2: FixedTableSize(280),
          3: FixedTableSize(120),
          4: FixedTableSize(130),
          5: FixedTableSize(80),
          6: FixedTableSize(170),
          7: FixedTableSize(170),
          8: FixedTableSize(170),
        },
        rows: [
          TableHeader(
            cells: const [
              TableCell(child: Text('工单编号')),
              TableCell(child: Text('外系统单号')),
              TableCell(child: Text('标题')),
              TableCell(child: Text('客户')),
              TableCell(child: Text('电话')),
              TableCell(child: Text('状态')),
              TableCell(child: Text('创建时间')),
              TableCell(child: Text('更新时间')),
              TableCell(child: Text('保存时间')),
            ],
          ),
          ...items.map(
            (item) => TableRow(
              cells: [
                TableCell(child: Text(item.proId)),
                TableCell(child: Text(item.externalNo)),
                TableCell(
                  child: Text(item.proTitle, overflow: TextOverflow.ellipsis),
                ),
                TableCell(child: Text(item.customerName)),
                TableCell(child: Text(item.customerPhone)),
                TableCell(child: Text(item.proState.toString())),
                TableCell(child: Text(item.createTime)),
                TableCell(child: Text(item.updateTime)),
                TableCell(child: Text(item.savedAt)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
