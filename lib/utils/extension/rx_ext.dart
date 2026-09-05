import 'package:get/get_rx/src/rx_types/rx_types.dart' show RxList;

extension RxListExt<E> on RxList<E> {
  void fillRangeOnly(int start, int end, [E? fill]) {
    E value = fill as E;
    // ignore: invalid_use_of_protected_member
    for (int i = start; i < end; i++) {
      // ignore: invalid_use_of_protected_member
      _value[i] = value;
    }
  }
}
