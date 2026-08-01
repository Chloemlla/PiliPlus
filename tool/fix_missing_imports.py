"""
Fix missing imports in PiliPlus view files after upstream merge.
The upstream added new scaffold/widget files; the conflict resolution
lost the imports for these files.
"""
import os
import re

ROOT = r'F:/Repositories/GitHub/PiliPlus'

# Files that need imports and which imports they need
# Key: file path (relative) -> list of (symbol, import_path) tuples
NEEDED_IMPORTS = {
    # SimpleScaffold and ScaffoldLayout
    'simple_scaffold': ('SimpleScaffold', 'package:pili_plus/common/widgets/scaffold/simple_scaffold.dart'),
    'mini_scaffold': ('MiniScaffold', 'package:pili_plus/common/widgets/scaffold/mini_scaffold.dart'),
    'bottom_sheet': ('BottomSheet_', 'package:pili_plus/common/widgets/scaffold/bottom_sheet.dart'),
    'animated_height': ('AnimatedHeight', 'package:pili_plus/common/widgets/animated_height.dart'),
    'custom_horizontal_drag': ('CustomHorizontalDragGestureRecognizer', 'package:pili_plus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart'),
    'dyn_draggable': ('DynDraggableScrollableSheet', 'package:pili_plus/common/widgets/scaffold/simple_scaffold.dart'),  # Not sure about this one, check later
}

# Check each file for missing symbols and add imports
files_to_check = []
for root, dirs, files in os.walk(os.path.join(ROOT, 'lib')):
    for f in files:
        if f.endswith('.dart') and f == 'view.dart':
            files_to_check.append(os.path.join(root, f))

# For each file, check if it uses SimpleScaffold, MiniScaffold, etc.
# If so, add the missing import
import_map = {
    'SimpleScaffold': ('package:pili_plus/common/widgets/scaffold/simple_scaffold.dart', False),
    'ScaffoldLayout': ('package:pili_plus/common/widgets/scaffold/simple_scaffold.dart', False),
    'MiniScaffold': ('package:pili_plus/common/widgets/scaffold/mini_scaffold.dart', False),
    'BottomSheet_': ('package:pili_plus/common/widgets/scaffold/bottom_sheet.dart', False),
    'AnimatedHeight': ('package:pili_plus/common/widgets/animated_height.dart', False),
    'CustomHorizontalDragGestureRecognizer': ('package:pili_plus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart', False),
    'DynDraggableScrollableSheet': ('package:pili_plus/common/widgets/scaffold/simple_scaffold.dart', True),
    'GalleryViewer': ('package:pili_plus/common/widgets/image_viewer/gallery_viewer.dart', False),
    'GlobalData': ('package:pili_plus/utils/global_data.dart', False),
}

# Also check common controller files
for root, dirs, files in os.walk(os.path.join(ROOT, 'lib')):
    for f in files:
        if f.endswith('.dart'):
            files_to_check.append(os.path.join(root, f))

files_to_check = list(set(files_to_check))

fixed_count = 0
for filepath in files_to_check:
    relpath = os.path.relpath(filepath, ROOT)
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    # Read existing imports
    import_lines = re.findall(r"^import\s+['\"]([^'\"]+)['\"]\s*;", content, re.MULTILINE)
    existing_imports = set(import_lines)

    new_imports_to_add = []
    for symbol, (import_path, is_uncertain) in import_map.items():
        if symbol in content and import_path not in existing_imports:
            if not is_uncertain:
                new_imports_to_add.append(import_path)

    if not new_imports_to_add:
        continue

    # Add imports after the last existing import
    # Find the import section
    import_section_end = 0
    for m in re.finditer(r"^import\s+['\"][^'\"]+['\"]\s*;", content, re.MULTILINE):
        import_section_end = m.end()

    if import_section_end > 0:
        # Find the end of line
        eol = content.find('\n', import_section_end)
        if eol == -1:
            eol = len(content)

        new_imports = '\n' + '\n'.join(f"import '{imp}';" for imp in sorted(new_imports_to_add))
        content = content[:eol] + new_imports + content[eol:]

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        fixed_count += 1
        print(f"FIXED: {relpath} -> added {len(new_imports_to_add)} imports: {', '.join(new_imports_to_add)}")

print(f"\nTotal files fixed: {fixed_count}")