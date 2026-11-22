import 'package:flutter/material.dart';
import 'db/db.dart';
import 'engine/game_service.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KickoffApp());
}

class KickoffApp extends StatefulWidget {
  const KickoffApp({super.key});
  @override
  State<KickoffApp> createState() => _KickoffAppState();
}

class _KickoffAppState extends State<KickoffApp> {
  GameService? service;
  String? error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final db = await Db.instance;
      setState(() => service = GameService(World(db)));
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kickoff Manager',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Builder(builder: (context) {
        if (error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal membuka database:\n$error',
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          );
        }
        if (service == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return WelcomeScreen(service: service!);
      }),
    );
  }
}
