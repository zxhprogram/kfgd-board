import '../../core/http/dio_client.dart';
import '../features/business_orders/data/business_order_api.dart';
import '../features/business_orders/stores/business_order_store.dart';
import '../features/business_orders/stores/import_store.dart';

final dio = createDio();
final businessOrderApi = BusinessOrderApi(dio);
final businessOrderStore = BusinessOrderStore(businessOrderApi);
final importStore = ImportStore(businessOrderApi, businessOrderStore);
