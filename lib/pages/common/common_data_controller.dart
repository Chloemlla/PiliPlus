import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/pages/common/common_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

abstract class CommonDataController<R, T> extends CommonController<R, T> {
  @override
  Rx<LoadingState<T>> loadingState = LoadingState<T>.loading().obs;

  @override
  Future<void> queryData([bool isRefresh = true]) async {
    if (isLoading) return;
    isLoading = true;
    try {
      final LoadingState<R> res = await customGetData();
      if (res is Success<R>) {
        if (!customHandleResponse(isRefresh, res)) {
          loadingState.value = res as LoadingState<T>;
        }
      } else {
        if (isRefresh && !handleError(res is Error ? res.errMsg : null)) {
          loadingState.value = res as Error;
        }
      }
    } catch (error, stackTrace) {
      debugPrintStack(
        label: 'CommonDataController query failed: $error',
        stackTrace: stackTrace,
      );
      if (isRefresh && !handleError(error.toString())) {
        loadingState.value = Error(error.toString());
      }
    } finally {
      isLoading = false;
    }
  }

  @override
  Future<void> onReload() {
    loadingState.value = LoadingState<T>.loading();
    return super.onReload();
  }
}
