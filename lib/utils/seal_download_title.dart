/// Pure title resolution for Seal download session meta.
///
/// Order: route `title` → route `favTitle` → [watchLaterTitle] → [bvid].
String resolveSealMediaTitle({
  Map? args,
  String watchLaterTitle = '',
  required String bvid,
}) {
  if (args != null) {
    final t = args['title']?.toString().trim();
    if (t != null && t.isNotEmpty) return t;
    final fav = args['favTitle']?.toString().trim();
    if (fav != null && fav.isNotEmpty) return fav;
  }
  final later = watchLaterTitle.trim();
  if (later.isNotEmpty) return later;
  return bvid;
}
