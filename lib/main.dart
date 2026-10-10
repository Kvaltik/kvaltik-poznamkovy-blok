import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync.dart';
import 'update_checker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudSync.initialize();
  runApp(const KvaltikApp());
}

class KvaltikApp extends StatefulWidget {
  const KvaltikApp({super.key});
  @override
  State<KvaltikApp> createState() => _KvaltikAppState();
}

class _KvaltikAppState extends State<KvaltikApp> {
  bool dark = true;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kvaltík Notepad',
        debugShowCheckedModeBanner: false,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: SplashPage(onTheme: () => setState(() => dark = !dark)),
      );
}

Widget loginHome(VoidCallback onTheme) => CloudSync.enabled
    ? CloudLoginPage(onTheme: onTheme)
    : LocalLoginPage(onTheme: onTheme);

class SplashPage extends StatefulWidget {
  final VoidCallback onTheme;
  const SplashPage({super.key, required this.onTheme});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    await Future.delayed(const Duration(milliseconds: 1300));
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final legacy = prefs.getString('session');
    final destination = CloudSync.user != null
        ? NotesPage(onTheme: widget.onTheme)
        : legacy != null
            ? NotesPage(user: legacy, onTheme: widget.onTheme)
            : loginHome(widget.onTheme);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_note, size: 100, color: Colors.tealAccent),
            SizedBox(height: 14),
            Text('KVALTÍK NOTEPAD',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ]),
        ),
      );
}

/// Shared email + password identity for both Windows and Android.
class CloudLoginPage extends StatefulWidget {
  final VoidCallback onTheme;
  final String? legacyUser;

  const CloudLoginPage({
    super.key,
    required this.onTheme,
    this.legacyUser,
  });

  @override
  State<CloudLoginPage> createState() => _CloudLoginPageState();
}

class _CloudLoginPageState extends State<CloudLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool hidden = true;
  bool busy = false;
  String message = '';

  Future<void> submit() async {
    if (busy) return;
    final address = email.text.trim();
    if (!address.contains('@') || password.text.length < 6) {
      setState(() => message = 'Zadej platný e-mail a heslo alespoň 6 znaků.');
      return;
    }
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final auth = CloudSync.client.auth;
      if (register) {
        final result = await auth.signUp(email: address, password: password.text);
        if (result.session == null) {
          if (mounted) {
            setState(() => message =
                'Zkontroluj e-mail a potvrď účet. Pak se zde přihlas.');
          }
          return;
        }
      } else {
        await auth.signInWithPassword(email: address, password: password.text);
      }
      if (CloudSync.user == null) {
        if (mounted) setState(() => message = 'Přihlášení ještě nebylo potvrzeno.');
        return;
      }

      var imported = 0;
      if (widget.legacyUser != null) {
        imported = await CloudSync.importLegacy(widget.legacyUser!);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session'); // Cloud auth is now the preferred session.
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => NotesPage(
            onTheme: widget.onTheme,
            importCount: imported,
          ),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Nelze se přihlásit: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_done_outlined,
                      color: Colors.tealAccent, size: 82),
                  const Text('KVALTÍK NOTEPAD',
                      style:
                          TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.legacyUser == null
                      ? 'Stejné poznámky na PC i mobilu'
                      : 'Připojit místní poznámky ke cloudu'),
                  const SizedBox(height: 24),
                  Text(register ? 'Cloudová registrace' : 'Cloudové přihlášení',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 14),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                        labelText: 'E-mail', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: 'Heslo',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(hidden
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() => hidden = !hidden),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (message.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SelectableText(message)),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(busy
                          ? 'Připojuji…'
                          : register
                              ? 'Vytvořit cloudový účet'
                              : 'Přihlásit a synchronizovat'),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              register = !register;
                              message = '';
                            }),
                    child: Text(register
                        ? 'Už mám cloudový účet'
                        : 'Vytvořit cloudový účet'),
                  ),
                  if (widget.legacyUser != null)
                    TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('Zpět k místním poznámkám'),
                    )
                  else
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LocalLoginPage(
                                      onTheme: widget.onTheme),
                                ),
                              ),
                      child: const Text('Mám starý místní účet – převést poznámky'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Old local authentication remains available for proven ownership of notes.
/// Local account data are not uploaded without the local password.
class LocalLoginPage extends StatefulWidget {
  final VoidCallback onTheme;
  const LocalLoginPage({super.key, required this.onTheme});

  @override
  State<LocalLoginPage> createState() => _LocalLoginPageState();
}

class _LocalLoginPageState extends State<LocalLoginPage> {
  final name = TextEditingController();
  final pass = TextEditingController();
  bool register = false;
  bool remember = true;
  bool hidden = true;
  String error = '';

  String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<void> submit() async {
    final prefs = await SharedPreferences.getInstance();
    final username = name.text.trim().toLowerCase();
    if (username.isEmpty || pass.text.length < 6) {
      setState(() => error = 'Zadej jméno a heslo alespoň 6 znaků.');
      return;
    }
    final key = 'account:$username';
    if (register) {
      if (prefs.containsKey(key)) {
        setState(() => error = 'Účet již existuje.');
        return;
      }
      final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
      final saltString = base64Encode(salt);
      await prefs.setString(
          key, jsonEncode({'salt': saltString, 'hash': hash(pass.text, saltString)}));
    } else {
      final raw = prefs.getString(key);
      if (raw == null) {
        setState(() => error = 'Místní účet v tomto zařízení neexistuje.');
        return;
      }
      final account = jsonDecode(raw) as Map<String, dynamic>;
      if (account['hash'] != hash(pass.text, account['salt'] as String)) {
        setState(() => error = 'Nesprávné heslo.');
        return;
      }
    }
    if (remember) {
      await prefs.setString('session', username);
    } else {
      await prefs.remove('session');
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NotesPage(user: username, onTheme: widget.onTheme),
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.edit_note,
                      size: 80, color: Colors.tealAccent),
                  const Text('KVALTÍK NOTEPAD',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(register ? 'Vytvořit místní účet' : 'Místní přihlášení',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(
                          labelText: 'Uživatelské jméno',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: 'Heslo',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(hidden
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() => hidden = !hidden),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: remember,
                    onChanged: (value) =>
                        setState(() => remember = value ?? true),
                    title: const Text('Zapamatovat přihlášení'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.redAccent)),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submit,
                      child: Text(register ? 'Registrovat' : 'Přihlásit'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      register = !register;
                      error = '';
                    }),
                    child: Text(register
                        ? 'Už mám místní účet'
                        : 'Vytvořit místní účet'),
                  ),
                  if (CloudSync.enabled)
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CloudLoginPage(onTheme: widget.onTheme),
                        ),
                      ),
                      child: const Text('Přihlásit se cloudovým účtem'),
                    )
                  else
                    const Text(
                      'Cloud zatím není nakonfigurován. Poznámky se ukládají jen sem.',
                      textAlign: TextAlign.center,
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class NotesPage extends StatefulWidget {
  /// Non-null = legacy local account. Null = cloud account.
  final String? user;
  final VoidCallback onTheme;
  final int importCount;
  const NotesPage({
    super.key,
    this.user,
    required this.onTheme,
    this.importCount = 0,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> notes = [];
  Timer? refreshTimer;
  String search = '';
  String syncStatus = '';
  bool syncing = false;
  bool get cloud => widget.user == null;
  String get legacyKey => 'notes:${widget.user}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    if (cloud) {
      refreshTimer = Timer.periodic(
          const Duration(seconds: 20), (_) => syncNow());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      UpdateChecker.check(context);
      if (widget.importCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Připraveno k synchronizaci: ${widget.importCount} místních poznámek.'),
        ));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && cloud) syncNow();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = cloud
        ? await CloudSync.cached()
        : (prefs.getString(legacyKey) == null
            ? <Map<String, dynamic>>[]
            : (jsonDecode(prefs.getString(legacyKey)!) as List)
                .map((value) => Map<String, dynamic>.from(value as Map))
                .toList());
    if (mounted) setState(() => notes = raw);
    if (cloud) await syncNow();
  }

  Future<void> syncNow() async {
    if (!cloud || syncing || !mounted) return;
    setState(() {
      syncing = true;
      syncStatus = 'Synchronizuji…';
    });
    try {
      await CloudSync.synchronize();
      final fresh = await CloudSync.cached();
      if (!mounted) return;
      setState(() {
        notes = fresh;
        syncStatus = 'Synchronizováno';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => syncStatus =
          'Offline / chyba spojení: změny jsou uložené na zařízení.');
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> localSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(legacyKey, jsonEncode(notes));
  }

  Future<void> edit([int? index]) async {
    final original = index == null ? null : notes[index];
    final title = TextEditingController(
        text: original == null ? '' : (original['title'] ?? '').toString());
    final body = TextEditingController(
        text: original == null ? '' : (original['body'] ?? '').toString());
    var editingIndex = index;
    String? noteId = cloud ? original?['id'] as String? : null;
    Timer? autoSaveTimer;
    var dirty = false;

    Future<void> persist() async {
      if (!dirty) return;
      dirty = false;
      if (cloud) {
        final note = CloudSync.makeNote(
            id: noteId,
            title: title.text.trim().isEmpty ? 'Bez názvu' : title.text.trim(),
            body: body.text);
        noteId = note['id'] as String;
        await CloudSync.change(note);
        notes.removeWhere((entry) => entry['id'] == noteId);
        notes.insert(0, note);
      } else {
        final item = <String, dynamic>{
          'title':
              title.text.trim().isEmpty ? 'Bez názvu' : title.text.trim(),
          'body': body.text,
          'updated': DateTime.now().toIso8601String(),
        };
        if (editingIndex == null) {
          notes.insert(0, item);
          editingIndex = 0;
        } else {
          notes[editingIndex!] = item;
        }
        await localSave();
      }
    }

    void scheduleSave() {
      dirty = true;
      autoSaveTimer?.cancel();
      autoSaveTimer = Timer(
        const Duration(milliseconds: 650),
        () { persist(); },
      );
    }

    title.addListener(scheduleSave);
    body.addListener(scheduleSave);

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (editorContext) => Scaffold(
          appBar: AppBar(
            title: Text(index == null ? 'Nová poznámka' : 'Upravit poznámku'),
            actions: [
              IconButton(
                tooltip: 'Uložit',
                icon: const Icon(Icons.check),
                onPressed: () async {
                  autoSaveTimer?.cancel();
                  if (editingIndex == null && noteId == null && !dirty) {
                    dirty = true;
                  }
                  await persist();
                  if (editorContext.mounted) Navigator.pop(editorContext);
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                controller: title,
                style: Theme.of(editorContext).textTheme.headlineSmall,
                decoration: const InputDecoration(
                    hintText: 'Název poznámky', border: InputBorder.none),
              ),
              const Divider(),
              Expanded(
                child: TextField(
                  controller: body,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  decoration: const InputDecoration(
                      hintText: 'Piš svoji poznámku…',
                      border: InputBorder.none),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    autoSaveTimer?.cancel();
    await persist(); // Flush last keystrokes, also when Android Back was pressed.
    title.removeListener(scheduleSave);
    body.removeListener(scheduleSave);
    title.dispose();
    body.dispose();
    if (mounted) setState(() {});
    if (cloud) syncNow();
  }

  Future<void> remove(int index) async {
    final target = notes[index];
    if (cloud) {
      final tombstone = CloudSync.makeNote(
        id: target['id'] as String,
        title: (target['title'] ?? '').toString(),
        body: (target['body'] ?? '').toString(),
        deleted: true,
      );
      await CloudSync.change(tombstone);
      notes.removeWhere((entry) => entry['id'] == tombstone['id']);
      notes.add(tombstone);
      if (mounted) setState(() {});
      syncNow();
    } else {
      setState(() => notes.removeAt(index));
      await localSave();
    }
  }

  Future<void> connectCloud() async {
    if (!CloudSync.enabled || widget.user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CloudLoginPage(
          onTheme: widget.onTheme,
          legacyUser: widget.user,
        ),
      ),
    );
  }

  Future<void> logout() async {
    if (cloud && CloudSync.enabled) {
      await CloudSync.client.auth.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => loginHome(widget.onTheme)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = notes.asMap().entries.where((entry) {
      final item = entry.value;
      if (cloud && item['deleted_at'] != null) return false;
      return ('${item['title']} ${item['body']}')
          .toLowerCase()
          .contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvaltík Notepad'),
        actions: [
          if (cloud)
            IconButton(
              tooltip: 'Synchronizovat',
              onPressed: syncing ? null : syncNow,
              icon: const Icon(Icons.cloud_sync),
            )
          else if (CloudSync.enabled)
            IconButton(
              tooltip: 'Převést místní poznámky do cloudu',
              onPressed: connectCloud,
              icon: const Icon(Icons.cloud_upload_outlined),
            ),
          IconButton(
              tooltip: 'Aktualizace',
              onPressed: () => UpdateChecker.check(context, manual: true),
              icon: const Icon(Icons.system_update_alt)),
          IconButton(
              tooltip: 'Motiv',
              onPressed: widget.onTheme,
              icon: const Icon(Icons.dark_mode_outlined)),
          IconButton(
              tooltip: 'Odhlásit',
              onPressed: logout,
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(children: [
        if (cloud)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(children: [
              Icon(
                syncStatus == 'Synchronizováno'
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  syncStatus.isEmpty ? 'Cloudové poznámky' : syncStatus,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ]),
          )
        else if (CloudSync.enabled)
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Poznámky jsou zatím jen v tomto zařízení'),
            subtitle: const Text('Klepni sem a propojíš je s mobilem.'),
            onTap: connectCloud,
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => search = value.toLowerCase()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Hledat poznámky',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('Žádné poznámky. Přidej první!'))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final entry = shown[index];
                    final note = entry.value;
                    return ListTile(
                      title: Text((note['title'] ?? '').toString()),
                      subtitle: Text(
                        (note['body'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => edit(entry.key),
                      trailing: IconButton(
                        tooltip: 'Smazat',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => remove(entry.key),
                      ),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Poznámka'),
      ),
    );
  }
}
