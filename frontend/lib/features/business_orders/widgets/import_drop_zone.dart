import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

class ImportDropZone extends StatefulWidget {
  const ImportDropZone({super.key, required this.onFileBytes});

  final Future<void> Function(String fileName, List<int> bytes) onFileBytes;

  @override
  State<ImportDropZone> createState() => _ImportDropZoneState();
}

class _ImportDropZoneState extends State<ImportDropZone> {
  final dragging = signal(false);

  @override
  void dispose() {
    dragging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDragging = dragging.watch(context);
    return DropTarget(
      onDragEntered: (_) => dragging.value = true,
      onDragExited: (_) => dragging.value = false,
      onDragDone: (detail) async {
        dragging.value = false;
        if (detail.files.isEmpty) {
          return;
        }
        final file = detail.files.first;
        await widget.onFileBytes(file.name, await file.readAsBytes());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDragging
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.muted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.border),
        ),
        child: Column(
          children: [
            const Icon(RadixIcons.upload, size: 42),
            const Gap(12),
            const Text('拖入 Excel 文件读取 proId 列表'),
            const Gap(8),
            const Text('建议 proId 单元格设置为文本格式，避免长数字精度丢失。'),
            const Gap(16),
            Button.outline(
              onPressed: _pickFile,
              child: const Text('选择 Excel 文件'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      return;
    }
    await widget.onFileBytes(file.name, bytes);
  }
}
