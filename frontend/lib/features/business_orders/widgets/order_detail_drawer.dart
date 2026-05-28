import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../data/business_order_models.dart';

class OrderDetailDrawer extends StatelessWidget {
  const OrderDetailDrawer({
    super.key,
    required this.order,
    required this.childOrders,
  });

  final BusinessOrderItem order;
  final List<BusinessOrderItem> childOrders;

  static const _stateLabels = {1: '待处理', 7: '已关闭', 61: '已处理待确认'};

  String _stateName(int proState) => _stateLabels[proState] ?? proState.toString();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '工单详情',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Gap(16),
          _buildField('工单编号', order.proId),
          _buildField('外系统单号', order.externalNo),
          _buildField('标题', order.proTitle),
          _buildField('客户', order.customerName),
          _buildField('电话', order.customerPhone),
          _buildField('状态', _stateName(order.proState)),
          _buildField('开始时间', order.createTime),
          _buildField('解决时间', order.updateTime),
          _buildField('处理时长', order.processDuration),
          _buildField('保存时间', order.savedAt),
          const Gap(24),
          Text(
            '子工单 (${childOrders.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          if (childOrders.isEmpty)
            const Text('暂无子工单'),
          if (childOrders.isNotEmpty)
            Accordion(
              items: childOrders
                  .map(
                    (child) => AccordionItem(
                      trigger: AccordionTrigger(
                        child: Row(
                          children: [
                            Text(
                              child.proId,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                child.proTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      content: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildField('工单编号', child.proId),
                            _buildField('外系统单号', child.externalNo),
                            _buildField('标题', child.proTitle),
                            _buildField('客户', child.customerName),
                            _buildField('电话', child.customerPhone),
                            _buildField('状态', _stateName(child.proState)),
                            _buildField('开始时间', child.createTime),
                            _buildField('解决时间', child.updateTime),
                            _buildField('处理时长', child.processDuration),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: SelectableText(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }
}

Future<void> showOrderDetailDrawer(
  BuildContext context, {
  required BusinessOrderItem order,
  required List<BusinessOrderItem> childOrders,
}) {
  return openDrawer(
    context: context,
    position: OverlayPosition.right,
    builder: (_) => OrderDetailDrawer(order: order, childOrders: childOrders),
  );
}
