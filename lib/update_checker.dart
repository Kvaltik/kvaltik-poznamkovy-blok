import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// GitHub Releases updater. Requires a PUBLIC release feed.
class UpdateChecker {
  static const latestRelease = 'https://api.github.com/repos/Kvaltik/kvaltik-poznamkovy-blok/releases/latest';

  static List<int> parts(String version) => version.replaceFirst(RegExp(r'^v'), '').split('.').map((p) => int.tryParse(p.split(RegExp(r'[-+]')).first) ?? 0).toList();

  static bool newer(String remote, String local) {
    final a = parts(remote), b = parts(local);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<void> check(BuildContext context, {bool manual = false}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(latestRelease));
      request.headers.set(HttpHeaders.userAgentHeader, 'KvaltikNotepad/${info.version}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 10));
      final raw = await utf8.decoder.bind(response).join();
      client.close(force: true);
      if (response.statusCode != 200) {
        if (manual && context.mounted) {
          await _message(context, 'Aktualizace nelze ověřit', 'GitHub vrátil HTTP ${response.statusCode}. Soukromý repozitář nemá veřejný přístup k Releases. Pro aktualizace je potřeba veřejný distribuční kanál.');
        }
        return;
      }
      final release = jsonDecode(raw) as Map<String, dynamic>;
      final tag = (release['tag_name'] ?? '').toString();
      if (!newer(tag, info.version)) {
        if (manual && context.mounted) await _message(context, 'Aktuální verze', 'Používáš nejnovější verzi (${info.version}).');
        return;
      }
      final assets = (release['assets'] as List? ?? []).whereType<Map>().toList();
      final ext = Platform.isAndroid ? '.apk' : '.exe';
      final matching = assets.where((a) => (a['name'] ?? '').toString().toLowerCase().endsWith(ext)).toList();
      final download = matching.isEmpty ? null : Uri.tryParse((matching.first['browser_download_url'] ?? '').toString());
      if (!context.mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Nová aktualizace! 🚀'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kvaltík Notepad ${tag} je dostupný.'),
          const SizedBox(height: 12),
          Text((release['body'] ?? 'Nové funkce a opravy.').toString()),
          if (download == null) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Instalační soubor pro toto zařízení zatím není ve vydání dostupný.')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Později')),
          FilledButton(onPressed: download == null ? null : () async {
            Navigator.pop(dialogContext);
            // Open the trusted GitHub asset URL in the system browser.
            // Installation requires explicit user confirmation.
            await launchUrl(download, mode: LaunchMode.externalApplication);
          }, child: const Text('Aktualizovat')),
        ],
      ));
    } catch (_) {
      if (manual && context.mounted) await _message(context, 'Kontrola se nezdařila', 'Zkontroluj připojení k internetu a zkus to znovu.');
    }
  }

  static Future<void> _message(BuildContext context, String title, String message) =>
      showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(message), actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
      ]));
}
