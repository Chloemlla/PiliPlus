import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pili_plus_video_bookmarks_',
    );
    Hive.init(hiveDirectory.path);
    expect(await VideoBookmarkService.init(), isTrue);
  });

  setUp(VideoBookmarkService.clearAllBookmarks);

  tearDownAll(() async {
    await VideoBookmarkService.box.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('VideoBookmarkService', () {
    test('stores only typed bookmarks and generates unique IDs', () async {
      final first = await _addBookmark(timestampSeconds: 5);
      final second = await _addBookmark(timestampSeconds: 5);

      expect(first.id, isNot(second.id));
      expect(first.id, startsWith('bm_'));
      expect(
        VideoBookmarkService.box.values,
        everyElement(isA<VideoBookmark>()),
      );
      expect(
        VideoBookmarkService.box.keys,
        everyElement(isA<String>()),
      );
      expect(
        VideoBookmarkService.box.containsKey('bookmarkIdCounter'),
        isFalse,
      );
    });

    test('normalizes default names, notes, and timestamps', () async {
      final bookmark = await VideoBookmarkService.addBookmark(
        bvid: 'BV1MM4y1s7NZ',
        videoTitle: 'Test Video',
        timestampSeconds: -5,
        name: '  ',
        note: '  ',
      );

      expect(bookmark, isNotNull);
      expect(bookmark!.timestampSeconds, 0);
      expect(bookmark.name, '标记 @ 00:00');
      expect(bookmark.note, isNull);
    });

    test('rejects invalid metadata before writing a bookmark', () async {
      await expectLater(
        VideoBookmarkService.addBookmark(
          bvid: 'not-a-bvid',
          videoTitle: 'Test Video',
          timestampSeconds: 1,
        ),
        throwsFormatException,
      );
      await expectLater(
        VideoBookmarkService.addBookmark(
          bvid: 'BV1MM4y1s7NZ',
          videoTitle: '   ',
          timestampSeconds: 1,
        ),
        throwsFormatException,
      );
      await expectLater(
        VideoBookmarkService.addBookmark(
          bvid: 'BV1MM4y1s7NZ',
          videoTitle: 'Test Video',
          authorMid: 0,
          timestampSeconds: 1,
        ),
        throwsFormatException,
      );
      expect(VideoBookmarkService.getAllBookmarks(), isEmpty);
    });

    test('enforces the per-video limit', () async {
      final bookmarks = <String, VideoBookmark>{
        for (
          var index = 0;
          index < VideoBookmarkService.maxBookmarksPerVideo;
          index++
        )
          'limit_$index': _bookmark(
            id: 'limit_$index',
            bvid: 'BV1MM4y1s7NZ',
            timestampSeconds: index,
          ),
      };
      await VideoBookmarkService.box.putAll(bookmarks);

      expect(
        VideoBookmarkService.canAddBookmark('BV1MM4y1s7NZ'),
        isFalse,
      );
      expect(
        await VideoBookmarkService.addBookmark(
          bvid: 'BV1MM4y1s7NZ',
          videoTitle: 'Limited Video',
          timestampSeconds: 201,
        ),
        isNull,
      );
    });

    test('lists, updates, and deletes bookmarks', () async {
      final later = await _addBookmark(timestampSeconds: 90);
      final earlier = await _addBookmark(timestampSeconds: 10);

      expect(
        VideoBookmarkService.getBookmarksForVideo('BV1MM4y1s7NZ').map(
          (bookmark) => bookmark.id,
        ),
        [earlier.id, later.id],
      );

      await VideoBookmarkService.updateBookmark(
        later.copyWith(
          bvid: 'BV13t411n7ex',
          timestampSeconds: 999,
          name: 'Updated',
          note: 'Updated note',
        ),
      );
      final updated = VideoBookmarkService.box.get(later.id)!;
      expect(updated.name, 'Updated');
      expect(updated.note, 'Updated note');
      expect(updated.bvid, later.bvid);
      expect(updated.timestampSeconds, later.timestampSeconds);

      await VideoBookmarkService.deleteBookmark(earlier.id);
      expect(VideoBookmarkService.box.containsKey(earlier.id), isFalse);
    });

    test('combines search, filters, and sorting', () async {
      await VideoBookmarkService.box.putAll({
        'a': _bookmark(
          id: 'a',
          bvid: 'BV1A',
          videoTitle: 'Zulu',
          authorMid: 1,
          timestampSeconds: 30,
          name: 'Opening',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        'b': _bookmark(
          id: 'b',
          bvid: 'BV1B',
          videoTitle: 'Alpha',
          authorMid: 2,
          timestampSeconds: 20,
          name: 'Middle',
          note: 'Important concept',
          createdAt: DateTime.utc(2026, 1, 3),
        ),
        'c': _bookmark(
          id: 'c',
          bvid: 'BV1A',
          videoTitle: 'Zulu',
          authorMid: 1,
          timestampSeconds: 10,
          name: 'Ending',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      });

      expect(
        VideoBookmarkService.searchBookmarks('CONCEPT').single.id,
        'b',
      );
      expect(
        VideoBookmarkService.getBookmarksSorted(
          sortType: SortType.timestamp,
          bvidFilter: 'BV1A',
        ).map((bookmark) => bookmark.id),
        ['c', 'a'],
      );
      expect(
        VideoBookmarkService.getBookmarksSorted(
          sortType: SortType.videoName,
          authorMidFilter: 2,
          searchQuery: 'middle',
        ).single.id,
        'b',
      );
      expect(VideoBookmarkService.getAuthorMids(), [1, 2]);
    });

    test('exports, clears, and imports bookmarks without duplicates', () async {
      await _addBookmark(
        bvid: 'BV1MM4y1s7NZ',
        timestampSeconds: 5,
      );
      await _addBookmark(
        bvid: 'BV13t411n7ex',
        timestampSeconds: 10,
      );

      final exported = VideoBookmarkService.exportAllBookmarks();
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      expect(decoded['count'], 2);

      await VideoBookmarkService.clearAllBookmarks();
      expect(VideoBookmarkService.getAllBookmarks(), isEmpty);
      expect(await VideoBookmarkService.importBookmarks(exported), 2);
      expect(await VideoBookmarkService.importBookmarks(exported), 0);
      expect(VideoBookmarkService.getAllBookmarks(), hasLength(2));
    });

    test('caps imported bookmarks at 200 per video', () async {
      final bookmarks = List.generate(
        VideoBookmarkService.maxBookmarksPerVideo + 1,
        (index) => _bookmark(
          id: 'import_$index',
          bvid: 'BV1MM4y1s7NZ',
          timestampSeconds: index,
        ).toJson(),
      );

      final imported = await VideoBookmarkService.importBookmarks(
        _bookmarkExportJson(bookmarks),
      );

      expect(imported, VideoBookmarkService.maxBookmarksPerVideo);
      expect(
        VideoBookmarkService.getBookmarkCountForVideo('BV1MM4y1s7NZ'),
        VideoBookmarkService.maxBookmarksPerVideo,
      );
    });

    test(
      'rejects an invalid entry without partially importing earlier rows',
      () async {
        final json = _bookmarkExportJson([
          _bookmark(
            id: 'valid',
            bvid: 'BV1MM4y1s7NZ',
            timestampSeconds: 1,
          ).toJson(),
          {
            'id': 'invalid',
            'bvid': 'not-a-bvid',
            'videoTitle': 'Invalid',
            'timestampSeconds': 2,
            'name': 'Invalid',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          },
        ]);

        await expectLater(
          VideoBookmarkService.importBookmarks(json),
          throwsFormatException,
        );
        expect(VideoBookmarkService.getAllBookmarks(), isEmpty);
      },
    );

    test('requires a complete bookmark export envelope', () async {
      await expectLater(
        VideoBookmarkService.importBookmarks(
          jsonEncode({'bookmarks': <Object?>[]}),
        ),
        throwsFormatException,
      );
    });
  });
}

String _bookmarkExportJson(List<Object?> bookmarks) {
  return jsonEncode({
    'version': VideoBookmarkService.exportVersion,
    'app': VideoBookmarkService.exportApp,
    'exportedAt': DateTime.utc(2026).toIso8601String(),
    'count': bookmarks.length,
    'bookmarks': bookmarks,
  });
}

Future<VideoBookmark> _addBookmark({
  String bvid = 'BV1MM4y1s7NZ',
  int timestampSeconds = 0,
}) async {
  return (await VideoBookmarkService.addBookmark(
    bvid: bvid,
    videoTitle: 'Test Video',
    authorMid: 1,
    timestampSeconds: timestampSeconds,
  ))!;
}

VideoBookmark _bookmark({
  required String id,
  required String bvid,
  String videoTitle = 'Test Video',
  int? authorMid,
  required int timestampSeconds,
  String name = 'Bookmark',
  String? note,
  DateTime? createdAt,
}) {
  return VideoBookmark(
    id: id,
    bvid: bvid,
    videoTitle: videoTitle,
    authorMid: authorMid,
    timestampSeconds: timestampSeconds,
    name: name,
    note: note,
    createdAt: createdAt ?? DateTime.utc(2026),
  );
}
