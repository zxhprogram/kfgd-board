import 'package:go_router/go_router.dart';

import '../features/business_orders/pages/import_page.dart';
import '../features/business_orders/pages/orders_page.dart';
import '../features/business_orders/pages/overview_page.dart';
import '../layout/app_shell.dart';

final router = GoRouter(
  initialLocation: '/overview',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/overview'),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/overview',
          builder: (context, state) => const OverviewPage(),
        ),
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
