import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_model.dart';

/// Persists user name + photo metadata, and resolves the on-disk photo
/// directory. Raw bytes live on the filesystem; the index is JSON in prefs.
class StorageService {
  static const _kUserName = 'yajertex.userName';
  static const _kPhotoIndex = 'yajertex.photoIndex';
  static const _photoDir = 'captures';

  // ---------- user name ----------

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kUserName);
    return (v == null || v.trim().isEmpty) ? null : v;
  }

  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserName, name.trim());
  }

  Future<void> clearUserName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserName);
  }

  // ---------- photo directory ----------

  Future<Directory> photoDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _photoDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> newPhotoPath() async {
    final dir = await photoDirectory();
    final name = 'yajertex_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return p.join(dir.path, name);
  }

  // ---------- photo index ----------

  Future<List<PhotoModel>> loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPhotoIndex) ?? '';
    final list = PhotoModel.decodeList(raw);
    // Drop entries whose files were deleted outside the app.
    final alive = <PhotoModel>[];
    for (final p in list) {
      if (await File(p.path).exists()) alive.add(p);
    }
    if (alive.length != list.length) {
      await prefs.setString(_kPhotoIndex, PhotoModel.encodeList(alive));
    }
    // Newest first.
    alive.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alive;
  }

  Future<void> addPhoto(PhotoModel photo) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPhotoIndex) ?? '';
    final list = PhotoModel.decodeList(raw)..add(photo);
    await prefs.setString(_kPhotoIndex, PhotoModel.encodeList(list));
  }

  Future<void> deletePhoto(PhotoModel photo) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPhotoIndex) ?? '';
    final list = PhotoModel.decodeList(raw)
      ..removeWhere((e) => e.id == photo.id);
    await prefs.setString(_kPhotoIndex, PhotoModel.encodeList(list));
    final f = File(photo.path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
