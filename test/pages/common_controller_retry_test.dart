import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/pages/common/common_data_controller.dart';
import 'package:pili_plus/pages/common/common_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'common data controller releases loading lock after exception',
    () async {
      final controller = _RetryDataController();

      await controller.queryData();
      expect(controller.isLoading, isFalse);
      expect(controller.loadingState.value, isA<Error>());

      await controller.queryData();
      expect(controller.calls, 2);
      expect(controller.loadingState.value.data, 42);
    },
  );

  test(
    'common list controller releases loading lock after exception',
    () async {
      final controller = _RetryListController();

      await controller.queryData();
      expect(controller.isLoading, isFalse);

      await controller.queryData();
      expect(controller.calls, 2);
      expect(controller.loadingState.value.data, [1, 2]);
    },
  );
}

final class _RetryDataController extends CommonDataController<int, int> {
  int calls = 0;

  @override
  Future<LoadingState<int>> customGetData() async {
    calls++;
    if (calls == 1) throw const FormatException('bad data');
    return const Success(42);
  }
}

final class _RetryListController extends CommonListController<List<int>, int> {
  int calls = 0;

  @override
  Future<LoadingState<List<int>>> customGetData() async {
    calls++;
    if (calls == 1) throw const FormatException('bad list');
    return const Success([1, 2]);
  }
}
