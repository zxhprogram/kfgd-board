import 'package:shadcn_flutter/shadcn_flutter.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.pageNo,
    required this.totalPages,
    required this.total,
    required this.hasPreviousPage,
    required this.hasNextPage,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageNo;
  final int totalPages;
  final int total;
  final bool hasPreviousPage;
  final bool hasNextPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('共 $total 条，第 $pageNo / $totalPages 页'),
        const Spacer(),
        Button.outline(
          onPressed: hasPreviousPage ? onPrevious : null,
          child: const Text('上一页'),
        ),
        const Gap(8),
        Button.outline(
          onPressed: hasNextPage ? onNext : null,
          child: const Text('下一页'),
        ),
      ],
    );
  }
}
