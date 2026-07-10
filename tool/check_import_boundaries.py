from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
IMPORT = re.compile(r"package:pili_plus/pages/")

# Existing debt is explicit so the set can only shrink.
ALLOWED = {
    "lib/models/common/fav_type.dart",
    "lib/models/common/later_view_type.dart",
    "lib/models/common/nav_bar_config.dart",
    "lib/models/common/setting_type.dart",
    "lib/models/common/sponsor_block/segment_model.dart",
    "lib/models/model_hot_video_item.dart",
    "lib/utils/app_scheme.dart",
    "lib/utils/extension/three_dot_ext.dart",
    "lib/utils/media_export_utils.dart",
    "lib/utils/page_utils.dart",
    "lib/utils/request_utils.dart",
    "lib/utils/storage_pref.dart",
}

violations = []
for base in (ROOT / "lib/models", ROOT / "lib/utils"):
    for source in base.rglob("*.dart"):
        relative = source.relative_to(ROOT).as_posix()
        if IMPORT.search(source.read_text(encoding="utf-8")) and relative not in ALLOWED:
            violations.append(relative)

if violations:
    print("New forbidden model/utils -> pages imports:", file=sys.stderr)
    print("\n".join(f"- {path}" for path in sorted(violations)), file=sys.stderr)
    sys.exit(1)

print("Import boundaries passed; no new model/utils -> pages dependencies.")
