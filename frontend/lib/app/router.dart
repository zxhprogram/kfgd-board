import 'package:go_router/go_router.dart';

import '../features/business_orders/pages/import_page.dart';
import '../features/business_orders/pages/orders_page.dart';
import '../layout/app_shell.dart';

final router = GoRouter(
  initialLocation: '/orders',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/orders'),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrdersPage(),
        ),
        GoRoute(
          path: '/import',
          builder: (context, state) => const ImportPage(),
        ),
      ],
    ),
  ],
);
