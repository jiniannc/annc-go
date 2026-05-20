import 'package:hive/hive.dart';

import '../models/sync_sheet_links.dart';

class SyncConfigRepository {
  static const _boxName = 'sync_config';
  static const _linksKey = 'sheet_links';

  Future<SyncSheetLinks> readSheetLinks() async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(_linksKey);
    return SyncSheetLinks.fromMap(raw as Map<dynamic, dynamic>?);
  }

  Future<void> saveSheetLinks(SyncSheetLinks links) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_linksKey, links.toMap());
  }
}
