import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'router.dart';

class KfgdBoardApp extends StatelessWidget {
  const KfgdBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp.router(
      title: 'KFGD Board',
      routerConfig: router,
      theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.6,typography: Typography.geist(
        sans:const TextStyle(fontFamily: 'Microsoft YaHei' ),
      )),
    );
  }
}
