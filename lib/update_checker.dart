import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public GitHub Releases updater. The source repository remains private.
class UpdateChecker {
  static const latestRelease = 'https://api.github.com/repos/Kvaltik/kvaltik-notepad-updates/releases/latest';

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
          await _message(context, 'Aktualizace nelze ověřit', 'Nepodařilo se načíst veřejná vydání (HTTP ${response.statusCode}). Ověř, že existuje veřejný repozitář Kvaltik/kvaltik-notepad-updates a obsahuje vydanou verzi.');
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
      if (!Platform.isAndroid && !Platform.isWindows) {
        if (manual && context.mounted) await _message(context, 'Nepodporovaná platforma', 'Automatické aktualizace jsou dostupné pro Windows a Android.');
        return;
      }
      final expectedName = Platform.isAndroid ? 'KvaltikNotepad-Android.apk' : 'KvaltikNotepad-Setup.exe';
      final matching = assets.where((a) => (a['name'] ?? '').toString() == expectedName).toList();
      final candidate = matching.isEmpty ? null : Uri.tryParse((matching.first['browser_download_url'] ?? '').toString());
      final download = candidate != null && candidate.scheme == 'https' && candidate.host == 'github.com' &&
          candidate.path.startsWith('/Kvaltik/kvaltik-notepad-updates/releases/download/') ? candidate : null;
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Připomenout při dalším spuštění')),
          FilledButton(onPressed: download == null ? null : () async {
            Navigator.pop(dialogContext);
            await _installUpdate(context, download);

          }, child: const Text('Aktualizovat')),
        ],
      ));
    } catch (_) {
      if (manual && context.mounted) await _message(context, 'Kontrola se nezdařila', 'Zkontroluj připojení k internetu a zkus to znovu.');
    }
  }

  /// Download installer to temporary storage and launch the OS installation UI.
  /// Android still requires the user to approve installation.
  static Future<void> _installUpdate(BuildContext context, Uri download) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final directory = await Directory.systemTemp.createTemp('kvaltik-update-');
      final path = '${directory.path}${Platform.pathSeparator}KvaltikNotepad-${info.version}-update.${Platform.isAndroid ? 'apk' : 'exe'}';
      final file = File(path);
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client.getUrl(download);
        request.headers.set(HttpHeaders.userAgentHeader, 'KvaltikNotepad-Updater');
        final response = await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('Download HTTP ${response.statusCode}');
        }
        final sink = file.openWrite();
        await sink.addStream(response);
        await sink.flush();
        await sink.close();
        if (await file.length() == 0) throw const FormatException('Empty installer');
      } finally {
        client.close(force: true);
      }
      if (Platform.isWindows) {
        await Process.start(file.path, const [], mode: ProcessStartMode.detached);
      } else {
        // Android cannot execute APK files. Use the system browser to start
        // the platform's download / package installation flow instead.
        final opened = await launchUrl(download, mode: LaunchMode.externalApplication);
        if (!opened) throw const FormatException('Cannot open Android installer');
      }
    } catch (_) {
      if (context.mounted) {
        await _message(context, 'Aktualizace se nezdařila', 'Instalátor se nepodařilo spustit. Zkus aktualizaci stáhnout z GitHub Releases.');
      }
    }
  }

  static Future<void> _message(BuildContext context, String title, String message) =>
      showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(message), actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
      ]));
}
