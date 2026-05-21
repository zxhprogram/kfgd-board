import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

class ExpandableSidebar extends StatefulWidget {
  const ExpandableSidebar({super.key});

  @override
  State<ExpandableSidebar> createState() => _ExpandableSidebarState();
}

class _ExpandableSidebarState extends State<ExpandableSidebar> {
  final expanded = signal(true);

  @override
  void dispose() {
    expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = expanded.watch(context);
    final location = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: isExpanded ? 220 : 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        border: Border(
          right: BorderSide(color: Theme.of(context).colorScheme.border),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(RadixIcons.dashboard),
                  if (isExpanded) ...[
                    const Gap(8),
                    const Expanded(
                      child: Text(
                        'KFGD Board',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  IconButton.ghost(
                    icon: Icon(
                      isExpanded
                          ? RadixIcons.chevronLeft
                          : RadixIcons.chevronRight,
                    ),
                    onPressed: () => expanded.value = !expanded.value,
                  ),
                ],
              ),
              const Gap(24),
              _SidebarItem(
                icon: RadixIcons.table,
                label: '数据列表',
                expanded: isExpanded,
                selected: location == '/orders',
                onPressed: () => context.go('/orders'),
              ),
              const Gap(8),
              _SidebarItem(
                icon: RadixIcons.upload,
                label: '数据导入',
                expanded: isExpanded,
                selected: location == '/import',
                onPressed: () => context.go('/import'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Button(
      style: selected ? ButtonStyle.primary() : ButtonStyle.ghost(),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(icon),
          if (expanded) ...[const Gap(10), Text(label)],
        ],
      ),
    );
  }
}
