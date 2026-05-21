import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'expandable_sidebar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Row(
        children: [
          const ExpandableSidebar(),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.background,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
