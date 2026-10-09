import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const KvaltikApp()); }
class KvaltikApp extends StatefulWidget {
  const KvaltikApp({super.key});
  @override State<KvaltikApp> createState() => _KvaltikAppState();
}
class _KvaltikAppState extends State<KvaltikApp> {
  bool dark = true;
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Kvaltík Notepad', debugShowCheckedModeBanner: false,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark, useMaterial3: true),
    home: SplashPage(onTheme: () => setState(() => dark = !dark)),
  );
}
class SplashPage extends StatefulWidget {
  final VoidCallback onTheme;
  const SplashPage({super.key, required this.onTheme});
  @override State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> {
  @override void initState() { super.initState(); start(); }
  Future<void> start() async {
    await Future.delayed(const Duration(milliseconds: 1300));
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final user = p.getString('session');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => user == null ? LoginPage(onTheme: widget.onTheme) : NotesPage(user: user, onTheme: widget.onTheme)));
  }
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.edit_note, size: 100, color: Colors.tealAccent), SizedBox(height: 14),
    Text('KVALTÍK NOTEPAD', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
    SizedBox(height: 24), CircularProgressIndicator()
  ])));
}
class LoginPage extends StatefulWidget {
  final VoidCallback onTheme;
  const LoginPage({super.key, required this.onTheme});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController(), pass = TextEditingController();
  bool register = false, remember = true, hidden = true;
  String error = '';
  String hash(String password, String salt) => sha256.convert(utf8.encode('$salt:$password')).toString();
  Future<void> submit() async {
    final p = await SharedPreferences.getInstance();
    final u = name.text.trim().toLowerCase();
    if (u.isEmpty || pass.text.length < 6) { setState(() => error = 'Zadej jméno a heslo alespoň 6 znaků.'); return; }
    final key = 'account:$u';
    if (register) {
      if (p.containsKey(key)) { setState(() => error = 'Účet již existuje.'); return; }
      final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
      final s = base64Encode(salt);
      await p.setString(key, jsonEncode({'salt': s, 'hash': hash(pass.text, s)}));
    } else {
      final raw = p.getString(key);
      if (raw == null) { setState(() => error = 'Účet neexistuje.'); return; }
      final a = jsonDecode(raw) as Map<String, dynamic>;
      if (a['hash'] != hash(pass.text, a['salt'] as String)) { setState(() => error = 'Nesprávné heslo.'); return; }
    }
    if (remember) { await p.setString('session', u); } else { await p.remove('session'); }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NotesPage(user: u, onTheme: widget.onTheme)));
  }
  @override void dispose() { name.dispose(); pass.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.edit_note, size: 80, color: Colors.tealAccent),
      const Text('KVALTÍK NOTEPAD', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 28),
      Text(register ? 'Vytvořit účet' : 'Přihlásit se', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Uživatelské jméno', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: pass, obscureText: hidden, decoration: InputDecoration(labelText: 'Heslo', border: const OutlineInputBorder(),
        suffixIcon: IconButton(icon: Icon(hidden ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hidden = !hidden)))),
      CheckboxListTile(value: remember, onChanged: (v) => setState(() => remember = v ?? true), title: const Text('Zapamatovat přihlášení'), contentPadding: EdgeInsets.zero),
      if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.redAccent)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: submit, child: Text(register ? 'Registrovat' : 'Přihlásit'))),
      TextButton(onPressed: () => setState(() { register = !register; error = ''; }), child: Text(register ? 'Už mám účet' : 'Vytvořit nový účet'))
    ])),
  ))));
}
class NotesPage extends StatefulWidget {
  final String user;
  final VoidCallback onTheme;
  const NotesPage({super.key, required this.user, required this.onTheme});
  @override State<NotesPage> createState() => _NotesPageState();
}
class _NotesPageState extends State<NotesPage> {
  List<Map<String, dynamic>> notes = [];
  String search = '';
  @override void initState() { super.initState(); load(); }
  String get key => 'notes:${widget.user}';
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw != null && mounted) {
      setState(() => notes = (jsonDecode(raw) as List).map((v) => Map<String, dynamic>.from(v as Map)).toList());
    }
  }
  Future<void> save() async { final p = await SharedPreferences.getInstance(); await p.setString(key, jsonEncode(notes)); }
  Future<void> edit([int? index]) async {
    final title = TextEditingController(text: index == null ? '' : notes[index]['title'] as String);
    final body = TextEditingController(text: index == null ? '' : notes[index]['body'] as String);
    await Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      appBar: AppBar(title: Text(index == null ? 'Nová poznámka' : 'Upravit poznámku'), actions: [
        IconButton(tooltip: 'Uložit', icon: const Icon(Icons.check), onPressed: () async {
          final item = {'title': title.text.trim().isEmpty ? 'Bez názvu' : title.text.trim(), 'body': body.text, 'updated': DateTime.now().toIso8601String()};
          if (index == null) { notes.insert(0, item); } else { notes[index] = item; }
          await save();
          if (context.mounted) Navigator.pop(context);
        })
      ]),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: title, style: Theme.of(context).textTheme.headlineSmall, decoration: const InputDecoration(hintText: 'Název poznámky', border: InputBorder.none)),
        const Divider(),
        Expanded(child: TextField(controller: body, expands: true, maxLines: null, minLines: null,
          decoration: const InputDecoration(hintText: 'Piš svoji poznámku…', border: InputBorder.none)))
      ])),
    )));
    title.dispose(); body.dispose();
    if (mounted) setState(() {});
  }
  Future<void> remove(int index) async {
    setState(() => notes.removeAt(index));
    await save();
  }
  Future<void> logout() async {
    final p = await SharedPreferences.getInstance(); await p.remove('session');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage(onTheme: widget.onTheme)));
  }
  @override Widget build(BuildContext context) {
    final shown = notes.asMap().entries.where((e) => ('${e.value['title']} ${e.value['body']}').toLowerCase().contains(search)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Kvaltík Notepad'), actions: [
      IconButton(tooltip: 'Motiv', onPressed: widget.onTheme, icon: const Icon(Icons.dark_mode_outlined)),
      IconButton(tooltip: 'Odhlásit', onPressed: logout, icon: const Icon(Icons.logout))
    ]), body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => search = v.toLowerCase()),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Hledat poznámky', border: OutlineInputBorder()))),
      Expanded(child: shown.isEmpty ? const Center(child: Text('Žádné poznámky. Přidej první!')) : ListView.builder(
        itemCount: shown.length, itemBuilder: (context, i) {
          final e = shown[i]; final n = e.value;
          return ListTile(title: Text(n['title'] as String), subtitle: Text(n['body'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => edit(e.key), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => remove(e.key)));
        }))
    ]), floatingActionButton: FloatingActionButton.extended(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Poznámka')));
  }
}
