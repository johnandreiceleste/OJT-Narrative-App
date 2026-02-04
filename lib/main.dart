import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace with your Supabase credentials
  await Supabase.initialize(
    url: 'https://xnmuwzphgfdeehpwtpxs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhubXV3enBoZ2ZkZWVocHd0cHhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxODQxNTMsImV4cCI6MjA4NTc2MDE1M30.HianwKnitkSSQXhe5CXt4uSqsA5pLjL3Dcmo_PEjQXA',
  );

  runApp(const OJTNarrativeApp());
}

final supabase = Supabase.instance.client;

class OJTNarrativeApp extends StatelessWidget {
  const OJTNarrativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OJT Narrative Report',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.session != null) {
          return const CalendarScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
