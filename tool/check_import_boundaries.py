from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PACKAGE_IMPORT = re.compile(
    r"^\s*import\s+['\"]package:pili_plus/([^'\"]+)['\"]",
    re.MULTILINE,
)
RAW_PAGE_WRITE = re.compile(
    r"GStorage\.(?:setting|video|historyWord|localCache|userInfo|watchProgress|reply)"
    r"\s*\.{1,2}\s*(?:put|putAll|delete|deleteAll|clear)\s*\("
)
RAW_BOX_ALIAS = re.compile(
    r"\bBox(?:<[^>]+>)?\s+\w+\s*=\s*"
    r"GStorage\.(?:setting|video|historyWord|localCache|userInfo|watchProgress|reply)\b"
)

# Existing dependency debt is exact: new targets fail even in an allowed file.
PAGE_IMPORT_BASELINE = {
    "lib/models/common/fav_type.dart": {
        "pages/fav/article/view.dart",
        "pages/fav/cheese/view.dart",
        "pages/fav/note/view.dart",
        "pages/fav/pgc/view.dart",
        "pages/fav/topic/view.dart",
        "pages/fav/video/view.dart",
    },
    "lib/models/common/later_view_type.dart": {"pages/later/child_view.dart"},
    "lib/models/common/nav_bar_config.dart": {
        "pages/dynamics/view.dart",
        "pages/home/view.dart",
        "pages/mine/view.dart",
    },
    "lib/models/common/setting_type.dart": {
        "pages/setting/models/extra_settings.dart",
        "pages/setting/models/model.dart",
        "pages/setting/models/play_settings.dart",
        "pages/setting/models/privacy_settings.dart",
        "pages/setting/models/recommend_settings.dart",
        "pages/setting/models/style_settings.dart",
        "pages/setting/models/video_settings.dart",
    },
    "lib/models/common/sponsor_block/segment_model.dart": {
        "pages/sponsor_block/block_mixin.dart"
    },
    "lib/models/model_hot_video_item.dart": {
        "pages/common/multi_select/base.dart"
    },
    "lib/utils/app_scheme.dart": {
        "pages/audio/view.dart",
        "pages/dynamics/widgets/vote.dart",
        "pages/fan/view.dart",
        "pages/follow/view.dart",
        "pages/follow_type/followed/view.dart",
        "pages/live/view.dart",
        "pages/rank/view.dart",
        "pages/subscription_detail/view.dart",
        "pages/video/reply_reply/view.dart",
    },
    "lib/utils/extension/three_dot_ext.dart": {
        "pages/common/common_whisper_controller.dart",
        "pages/contact/view.dart",
        "pages/whisper_settings/view.dart",
    },
    "lib/utils/media_export_utils.dart": {
        "pages/video/controller.dart",
        "pages/video/introduction/pgc/controller.dart",
        "pages/video/introduction/ugc/controller.dart",
    },
    "lib/utils/page_utils.dart": {
        "pages/common/common_intro_controller.dart",
        "pages/common/publish/publish_route.dart",
        "pages/contact/view.dart",
        "pages/fav_panel/view.dart",
        "pages/share/view.dart",
    },
    "lib/utils/request_utils.dart": {
        "pages/common/multi_select/base.dart",
        "pages/dynamics_tab/controller.dart",
        "pages/fav_detail/controller.dart",
        "pages/group_panel/view.dart",
        "pages/login/geetest/geetest_webview_dialog.dart",
    },
    "lib/utils/storage_pref.dart": {
        "pages/setting/pages/fullscreen_sc_size.dart"
    },
}

# Counts are per file so historical raw writes may shrink but cannot grow.
RAW_PAGE_WRITE_BASELINE = {
    "lib/pages/about/view.dart": 2,
    "lib/pages/common/common_intro_controller.dart": 1,
    "lib/pages/common/dyn/common_dyn_page.dart": 1,
    "lib/pages/danmaku_block/view.dart": 1,
    "lib/pages/fav_detail/controller.dart": 1,
    "lib/pages/history/base_controller.dart": 1,
    "lib/pages/history/controller.dart": 1,
    "lib/pages/later/base_controller.dart": 1,
    "lib/pages/live_room/view.dart": 1,
    "lib/pages/live_room/widgets/bottom_control.dart": 1,
    "lib/pages/live_room/widgets/header_control.dart": 1,
    "lib/pages/member_profile/view.dart": 2,
    "lib/pages/mine/controller.dart": 2,
    "lib/pages/search/controller.dart": 3,
    "lib/pages/search/view.dart": 2,
    "lib/pages/setting/models/extra_settings.dart": 22,
    "lib/pages/setting/models/model.dart": 2,
    "lib/pages/setting/models/play_settings.dart": 8,
    "lib/pages/setting/models/style_settings.dart": 19,
    "lib/pages/setting/models/video_settings.dart": 16,
    "lib/pages/setting/pages/bar_set.dart": 2,
    "lib/pages/setting/pages/color_select.dart": 4,
    "lib/pages/setting/pages/fullscreen_sc_size.dart": 2,
    "lib/pages/setting/pages/logs.dart": 1,
    "lib/pages/setting/widgets/switch_item.dart": 2,
    "lib/pages/video/pay_coins/view.dart": 1,
    "lib/pages/video/view.dart": 1,
    "lib/pages/video/widgets/header_control.dart": 2,
    "lib/pages/video/widgets/player_focus.dart": 1,
    "lib/pages/webdav/view.dart": 3,
}
RAW_BOX_ALIAS_BASELINE = {
    "lib/pages/setting/pages/display_mode.dart": 1,
    "lib/pages/setting/pages/play_speed_set.dart": 1,
    "lib/pages/sponsor_block/view.dart": 1,
    "lib/pages/video/controller.dart": 1,
    "lib/pages/video/widgets/header_control.dart": 1,
}

ALLOWED_HTTP_TRANSPORT_IMPORTS = {
    "http/adapter_lifecycle.dart",
    "http/api.dart",
    "http/connection_failover_interceptor.dart",
    "http/constants.dart",
    "http/network_security_policy.dart",
    "http/retry_interceptor.dart",
}


def source_imports(source: Path) -> set[str]:
    return set(PACKAGE_IMPORT.findall(source.read_text(encoding="utf-8")))


IMPORT_GRAPH = {
    source.relative_to(ROOT / "lib").as_posix(): source_imports(source)
    for source in (ROOT / "lib").rglob("*.dart")
}


def find_import_path(start: str, target: str) -> list[str] | None:
    pending = [(start, [start])]
    visited = {start}
    while pending:
        current, path = pending.pop(0)
        if current == target:
            return path
        for dependency in sorted(IMPORT_GRAPH.get(current, set())):
            if dependency not in visited:
                visited.add(dependency)
                pending.append((dependency, [*path, dependency]))
    return None


violations: list[str] = []

for base in (ROOT / "lib/models", ROOT / "lib/utils"):
    for source in base.rglob("*.dart"):
        relative = source.relative_to(ROOT).as_posix()
        page_imports = {
            target for target in source_imports(source) if target.startswith("pages/")
        }
        new_imports = page_imports - PAGE_IMPORT_BASELINE.get(relative, set())
        for target in sorted(new_imports):
            violations.append(f"new forbidden import: {relative} -> lib/{target}")

accounts_imports = source_imports(ROOT / "lib/utils/accounts.dart")
for target in sorted(accounts_imports):
    if (
        target.startswith("http/")
        or target.startswith("pages/")
        or target == "utils/login_utils.dart"
    ):
        violations.append(f"Accounts boundary violation: {target}")

transport_imports = source_imports(ROOT / "lib/http/init.dart")
for target in sorted(transport_imports):
    if target.startswith("http/") and target not in ALLOWED_HTTP_TRANSPORT_IMPORTS:
        violations.append(f"HTTP transport imports concrete endpoint: {target}")
    if target in {"utils/accounts.dart", "utils/login_utils.dart"}:
        violations.append(f"HTTP transport/session cycle: {target}")

storage_imports = source_imports(ROOT / "lib/utils/storage.dart")
if "utils/storage_pref.dart" in storage_imports:
    violations.append("storage initialization must not import storage_pref.dart")
storage_pref_path = find_import_path(
    "utils/storage.dart",
    "utils/storage_pref.dart",
)
if storage_pref_path is not None:
    violations.append(
        "storage initialization transitively depends on storage_pref.dart: "
        + " -> ".join(storage_pref_path)
    )

for source in (ROOT / "lib/pages").rglob("*.dart"):
    relative = source.relative_to(ROOT).as_posix()
    text = source.read_text(encoding="utf-8")
    raw_write_count = len(RAW_PAGE_WRITE.findall(text))
    raw_write_limit = RAW_PAGE_WRITE_BASELINE.get(relative, 0)
    if raw_write_count > raw_write_limit:
        violations.append(
            f"new raw page GStorage write(s): {relative} "
            f"({raw_write_count} > {raw_write_limit})"
        )
    raw_alias_count = len(RAW_BOX_ALIAS.findall(text))
    raw_alias_limit = RAW_BOX_ALIAS_BASELINE.get(relative, 0)
    if raw_alias_count > raw_alias_limit:
        violations.append(
            f"new raw page Box alias(es): {relative} "
            f"({raw_alias_count} > {raw_alias_limit})"
        )

if violations:
    print("Import/storage boundaries failed:", file=sys.stderr)
    print("\n".join(f"- {item}" for item in sorted(violations)), file=sys.stderr)
    sys.exit(1)

print(
    "Import/storage boundaries passed; no new core cycles, page imports, "
    "or raw page writes."
)
