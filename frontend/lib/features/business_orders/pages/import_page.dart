import 'dart:typed_data';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../app/dependencies.dart';
import '../../../core/utils/excel_pro_id_parser.dart';
import '../widgets/import_drop_zone.dart';

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = importStore;
    final pending = store.pendingImportProIds.watch(context);
    final error = store.errorMessage.watch(context);
    final result = store.lastResult.watch(context);
    final isParsing = store.isParsing.watch(context);
    final isImporting = store.isImporting.watch(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据导入',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const Gap(8),
          const Text('拖入包含 proId 的 Excel 文件，系统会自动跳过已导入的数据。'),
          const Gap(24),
          ImportDropZone(
            onFileBytes: (fileName, bytes) async {
              if (!fileName.toLowerCase().endsWith('.xlsx')) {
                store.errorMessage.value = '仅支持 .xlsx 文件';
                return;
              }
              final parsed = parseExcelProIds(Uint8List.fromList(bytes));
              await store.setParsedProIds(
                fileName: fileName,
                proIds: parsed.proIds,
                duplicateCount: parsed.duplicateCount,
              );
            },
          ),
          const Gap(24),
          _SummaryCard(),
          if (pending.isNotEmpty) ...[
            const Gap(16),
            _PendingPreview(proIds: pending),
          ],
          const Gap(16),
          Row(
            children: [
              Button.primary(
                onPressed: pending.isEmpty || isImporting
                    ? null
                    : store.importPending,
                child: Text(isImporting ? '导入中...' : '开始导入'),
              ),
              const Gap(8),
              Button.outline(onPressed: store.reset, child: const Text('清空')),
              if (isParsing) ...[const Gap(12), const Text('解析中...')],
            ],
          ),
          if (result != null) ...[
            const Gap(16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '导入完成：请求 ${result.requested} 条，实际导入 ${result.imported} 条',
                ),
              ),
            ),
          ],
          if (error != null) ...[
            const Gap(16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.destructive,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = importStore;
    final fileName = store.selectedFileName.watch(context);
    final parsed = store.parsedProIds.watch(context).length;
    final duplicates = store.duplicateInFileCount.watch(context);
    final skipped = store.alreadyImportedCount.watch(context);
    final pending = store.pendingImportProIds.watch(context).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '解析结果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Gap(12),
            Text('文件：${fileName ?? '-'}'),
            Text('唯一 proId：$parsed'),
            Text('文件内重复跳过：$duplicates'),
            Text('已导入跳过：$skipped'),
            Text('待导入：$pending'),
          ],
        ),
      ),
    );
  }
}

class _PendingPreview extends StatelessWidget {
  const _PendingPreview({required this.proIds});

  final List<String> proIds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '待导入预览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            ...proIds.take(30).map((proId) => Text(proId)),
            if (proIds.length > 30) Text('... 还有 ${proIds.length - 30} 条'),
          ],
        ),
      ),
    );
  }
}
