import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud configuration is injected by CI using public publishable/anon credentials.
/// Never inject a Supabase service_role or secret API key into a client build.
class CloudSync {
  static const projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get enabled => projectUrl.startsWith('https://') && publishableKey.isNotEmpty;
  static bool _busy = false;

  static SupabaseClient get client => Supabase.instance.client;
  static User? get user => enabled ? client.auth.currentUser : null;
  static String get _uid {
    final value = user?.id;
    if (value == null) throw StateError('Cloud account is not signed in');
    return value;
  }

  static Future<void> initialize() async {
    if (enabled) {
      await Supabase.initialize(url: projectUrl, anonKey: publishableKey);
    }
  }

  static String cacheKey(String uid) => 'cloud-notes:$uid';
  static String queueKey(String uid) => 'cloud-pending:$uid';

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> cached() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(cacheKey(_uid)));
  }

  static String newId() {
    final values = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    values[6] = (values[6] & 15) | 64;
    values[8] = (values[8] & 63) | 128;
    final h = values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static Map<String, dynamic> makeNote({
    String? id, required String title, required String body, bool deleted = false,
    bool pinned = false, bool archived = false,
    List<String> tags = const [], String folderPath = '',
  }) {
    final stamp = DateTime.now().toUtc().toIso8601String();
    return <String, dynamic>{
      'id': id ?? newId(),
      'title': title,
      'body': body,
      'updated_at': stamp,
      'deleted_at': deleted ? stamp : null,
      'pinned': pinned,
      'archived': archived,
      'tags': tags,
      'folder_path': folderPath,
    };
  }

  /// Save cache + a persistent outbox. Failure to reach Supabase does not lose edits.
  static Future<void> change(Map<String, dynamic> note) async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();
    final existing = _decode(prefs.getString(cacheKey(uid)));
    existing.removeWhere((row) => row['id'] == note['id']);
    existing.insert(0, Map<String, dynamic>.from(note));
    final pending = _decode(prefs.getString(queueKey(uid)));
    pending.removeWhere((row) => row['id'] == note['id']);
    pending.add(Map<String, dynamic>.from(note));
    // Queue first; re-applying the same row is safe if the process exits midway.
    await prefs.setString(queueKey(uid), jsonEncode(pending));
    await prefs.setString(cacheKey(uid), jsonEncode(existing));
  }

  /// User must first prove access to the LOCAL account via the old login screen.
  /// The original notes:username data are never deleted.
  static Future<int> importLegacy(String legacyUsername) async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();
    final marker = 'cloud-import:$uid:$legacyUsername';
    if (prefs.getBool(marker) ?? false) return 0;
    final notes = _decode(prefs.getString('notes:$legacyUsername'));
    final existing = await cached();
    final queued = _decode(prefs.getString(queueKey(uid)));
    final ids = existing.map((e) => e['id']).toSet();
    var imported = 0;
    for (final original in notes) {
      // Import rows have durable ids (written to cache+queue), original remains intact.
      final note = makeNote(
        title: (original['title'] ?? 'Bez názvu').toString(),
        body: (original['body'] ?? '').toString(),
      );
      if (ids.add(note['id'])) {
        existing.add(note);
        queued.add(note);
        imported++;
      }
    }
    // A crash before marker is written may import duplicates; marker is set
    // only after both local writes complete so data is not silently skipped.
    await prefs.setString(queueKey(uid), jsonEncode(queued));
    await prefs.setString(cacheKey(uid), jsonEncode(existing));
    await prefs.setBool(marker, true);
    return imported;
  }

  static Map<String, dynamic> _forServer(Map<String, dynamic> local, String uid) => {
        'id': local['id'],
        'owner_id': uid,
        'title': local['title'],
        'body': local['body'],
        'updated_at': local['updated_at'],
        'deleted_at': local['deleted_at'],
        'pinned': local['pinned'] == true,
        'archived': local['archived'] == true,
        'tags': (local['tags'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
        'folder_path': (local['folder_path'] ?? '').toString(),
      };

  /// Foreground sync: push queued changes, then pull all server rows.
  /// The queue survives network failures. RLS filters rows by owner_id.
  static Future<void> synchronize() async {
    if (!enabled || user == null || _busy) return;
    _busy = true;
    try {
      final uid = _uid;
      final prefs = await SharedPreferences.getInstance();
      final queued = _decode(prefs.getString(queueKey(uid)));
      for (final note in queued) {
        if (_uid != uid) return; // account switched while awaiting network
        await client.from('notes').upsert(_forServer(note, uid), onConflict: 'id');
        final current = _decode(prefs.getString(queueKey(uid)));
        // Don't discard a newer edit made during this network request.
        current.removeWhere((row) => row['id'] == note['id'] && jsonEncode(row) == jsonEncode(note));
        await prefs.setString(queueKey(uid), jsonEncode(current));
      }

      final remote = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        if (_uid != uid) return;
        final page = await client
            .from('notes')
            .select('id,title,body,updated_at,deleted_at,pinned,archived,tags,folder_path')
            .eq('owner_id', uid)
            .range(offset, offset + 999);
        remote.addAll(page.map((e) => Map<String, dynamic>.from(e)));
        if (page.length < 1000) break;
        offset += 1000;
      }
      // Preserve edits made while downloading, including unsent deletions.
      final mostRecentPending = _decode(prefs.getString(queueKey(uid)));
      final merged = {for (final row in remote) row['id'] as String: row};
      for (final row in mostRecentPending) {
        merged[row['id'] as String] = row;
      }
      if (_uid == uid) {
        await prefs.setString(cacheKey(uid), jsonEncode(merged.values.toList()));
      }
    } finally {
      _busy = false;
    }
  }
}
