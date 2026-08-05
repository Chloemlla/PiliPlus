import 'package:pili_plus/models/common/home_tab_type.dart';
import 'package:pili_plus/pages/common/common_controller.dart';
import 'package:pili_plus/pages/hot/controller.dart';
import 'package:pili_plus/pages/hot/view.dart';
import 'package:pili_plus/pages/live/controller.dart';
import 'package:pili_plus/pages/live/view.dart';
import 'package:pili_plus/pages/pgc/controller.dart';
import 'package:pili_plus/pages/pgc/view.dart';
import 'package:pili_plus/pages/rank/controller.dart';
import 'package:pili_plus/pages/rank/view.dart';
import 'package:pili_plus/pages/rcmd/controller.dart';
import 'package:pili_plus/pages/rcmd/view.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

extension HomeTabFactory on HomeTabType {
  ScrollOrRefreshMixin controller() => switch (this) {
    HomeTabType.live => Get.find<LiveController>(),
    HomeTabType.rcmd => Get.find<RcmdController>(),
    HomeTabType.hot => Get.find<HotController>(),
    HomeTabType.rank => Get.find<RankController>(),
    HomeTabType.bangumi ||
    HomeTabType.cinema => Get.find<PgcController>(tag: name),
  };

  Widget buildPage() => switch (this) {
    HomeTabType.live => const LivePage(),
    HomeTabType.rcmd => const RcmdPage(),
    HomeTabType.hot => const HotPage(),
    HomeTabType.rank => const RankPage(),
    HomeTabType.bangumi => const PgcPage(tabType: HomeTabType.bangumi),
    HomeTabType.cinema => const PgcPage(tabType: HomeTabType.cinema),
  };
}
