"""
Fix remaining conflict markers in all files.
Keeps the HEAD (ours) version for each conflict.
"""
import os
import re
import sys

ROOT = r'F:/Repositories/GitHub/PiliPlus'

# Files that still have conflict markers
files = [
    "android/app/build.gradle.kts",
    "lib/common/widgets/draggable_sheet/dyn.dart",
    "lib/common/widgets/flutter/refresh_indicator.dart",
    "lib/common/widgets/flutter/text/text.dart",
    "lib/common/widgets/image_grid/image_grid_view.dart",
    "lib/common/widgets/image_viewer/gallery_viewer.dart",
    "lib/common/widgets/scroll_physics.dart",
    "lib/pages/about/view.dart",
    "lib/pages/article/view.dart",
    "lib/pages/audio/view.dart",
    "lib/pages/blacklist/view.dart",
    "lib/pages/bubble/view.dart",
    "lib/pages/common/dyn/common_dyn_page.dart",
    "lib/pages/contact/view.dart",
    "lib/pages/danmaku_block/view.dart",
    "lib/pages/dlna/view.dart",
    "lib/pages/download/detail/view.dart",
    "lib/pages/download/downloading/view.dart",
    "lib/pages/download/view.dart",
    "lib/pages/dynamics/view.dart",
    "lib/pages/dynamics_create/view.dart",
    "lib/pages/dynamics_create_reserve/view.dart",
    "lib/pages/dynamics_create_vote/view.dart",
    "lib/pages/dynamics_detail/view.dart",
    "lib/pages/dynamics_mention/view.dart",
    "lib/pages/dynamics_repost/view.dart",
    "lib/pages/dynamics_select_topic/view.dart",
    "lib/pages/dynamics_topic/view.dart",
    "lib/pages/dynamics_topic_rcmd/view.dart",
    "lib/pages/episode_panel/view.dart",
    "lib/pages/fav/view.dart",
    "lib/pages/fav_detail/view.dart",
    "lib/pages/fav_folder_sort/view.dart",
    "lib/pages/fav_sort/view.dart",
    "lib/pages/follow/child/child_view.dart",
    "lib/pages/follow/view.dart",
    "lib/pages/follow_tag_sort/view.dart",
    "lib/pages/follow_type/view.dart",
    "lib/pages/history/view.dart",
    "lib/pages/home/view.dart",
    "lib/pages/hot/view.dart",
    "lib/pages/later/view.dart",
    "lib/pages/live_area/view.dart",
    "lib/pages/live_area_detail/view.dart",
    "lib/pages/live_dm_block/view.dart",
    "lib/pages/live_follow/view.dart",
    "lib/pages/live_room/contribution_rank/view.dart",
    "lib/pages/live_room/view.dart",
    "lib/pages/live_room/widgets/header_control.dart",
    "lib/pages/live_search/view.dart",
    "lib/pages/log_table/view.dart",
    "lib/pages/login/view.dart",
    "lib/pages/login_devices/view.dart",
    "lib/pages/main/view.dart",
    "lib/pages/main_reply/view.dart",
    "lib/pages/match_info/view.dart",
    "lib/pages/member/view.dart",
    "lib/pages/member/widget/user_info_card.dart",
    "lib/pages/member_coin_arc/view.dart",
    "lib/pages/member_dynamics/view.dart",
    "lib/pages/member_guard/view.dart",
    "lib/pages/member_like_arc/view.dart",
    "lib/pages/member_opus/view.dart",
    "lib/pages/member_profile/view.dart",
    "lib/pages/member_search/view.dart",
    "lib/pages/member_season_series/view.dart",
    "lib/pages/member_upower_rank/view.dart",
    "lib/pages/member_video/controller.dart",
    "lib/pages/member_video/view.dart",
    "lib/pages/member_video_web/base/view.dart",
    "lib/pages/msg_feed_top/at_me/view.dart",
    "lib/pages/msg_feed_top/like_detail/view.dart",
    "lib/pages/msg_feed_top/like_me/view.dart",
    "lib/pages/msg_feed_top/reply_me/view.dart",
    "lib/pages/msg_feed_top/sys_msg/view.dart",
    "lib/pages/music/view.dart",
    "lib/pages/my_reply/view.dart",
    "lib/pages/pgc/view.dart",
    "lib/pages/pgc_index/view.dart",
    "lib/pages/pgc_review/view.dart",
    "lib/pages/popular_precious/view.dart",
    "lib/pages/popular_series/view.dart",
    "lib/pages/search_result/view.dart",
    "lib/pages/search_trending/view.dart",
    "lib/pages/setting/common_setting.dart",
    "lib/pages/setting/models/style_settings.dart",
    "lib/pages/setting/pages/bar_set.dart",
    "lib/pages/setting/pages/color_select.dart",
    "lib/pages/setting/pages/display_mode.dart",
    "lib/pages/setting/pages/font_size_select.dart",
    "lib/pages/setting/pages/fullscreen_sc_size.dart",
    "lib/pages/setting/pages/logs.dart",
    "lib/pages/setting/pages/play_speed_set.dart",
    "lib/pages/setting/view.dart",
    "lib/pages/space_setting/view.dart",
    "lib/pages/sponsor_block/view.dart",
    "lib/pages/subscription/view.dart",
    "lib/pages/video/ai_conclusion/view.dart",
    "lib/pages/video/controller.dart",
    "lib/pages/video/introduction/pgc/widgets/intro_detail.dart",
    "lib/pages/video/introduction/ugc/controller.dart",
    "lib/pages/video/note/view.dart",
    "lib/pages/video/pay_coins/view.dart",
    "lib/pages/video/post_panel/view.dart",
    "lib/pages/video/reply/view.dart",
    "lib/pages/video/reply_reply/view.dart",
    "lib/pages/video/reply_search_item/view.dart",
    "lib/pages/video/view.dart",
    "lib/pages/video/view_point/view.dart",
    "lib/pages/webdav/view.dart",
    "lib/pages/webview/view.dart",
    "lib/pages/whisper/view.dart",
    "lib/pages/whisper_block/view.dart",
    "lib/pages/whisper_detail/view.dart",
    "lib/pages/whisper_link_setting/view.dart",
    "lib/pages/whisper_secondary/view.dart",
    "lib/pages/whisper_settings/view.dart",
    "pubspec.lock",
    "pubspec.yaml",
]

# Pattern to match conflict markers
# We keep the HEAD version for each conflict
conflict_pattern = re.compile(
    r'<<<<<<< HEAD[^\n]*\n(.*?)=======\n.*?>>>>>>> [^\n]*\n',
    re.DOTALL
)

conflict_pattern_simple = re.compile(
    r'<<<<<<< .*?\n(.*?)=======\n.*?>>>>>>> .*?\n',
    re.DOTALL
)

fixed_count = 0
for rel_path in files:
    full_path = os.path.join(ROOT, rel_path)
    if not os.path.exists(full_path):
        print(f"SKIP (not found): {rel_path}")
        continue
    with open(full_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    if '<<<<<<<' not in content:
        continue
    # Fix: keep HEAD version, remove markers
    new_content = conflict_pattern_simple.sub(r'\1', content)
    if '<<<<<<<' in new_content:
        # Try again - some files might have nested or different format
        new_content = conflict_pattern_simple.sub(r'\1', new_content)
    if '<<<<<<<' in new_content:
        print(f"WARN: still has markers after fix: {rel_path}")
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    fixed_count += 1
    print(f"FIXED: {rel_path}")

print(f"\nTotal fixed: {fixed_count}")

# Verify
remaining = []
for rel_path in files:
    full_path = os.path.join(ROOT, rel_path)
    if not os.path.exists(full_path):
        continue
    with open(full_path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    if '<<<<<<<' in content:
        remaining.append(rel_path)

if remaining:
    print(f"\nREMAINING ({len(remaining)}):")
    for r in remaining:
        print(f"  - {r}")
else:
    print("\nAll conflict markers resolved!")