import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'debug_wrapper.dart';
import 'language_service.dart';
import 'splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yywhqnuwynaozgitrdvw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5d2hxbnV3eW5hb3pnaXRyZHZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDA3NzIsImV4cCI6MjA4NzI3Njc3Mn0.sCyQx6Sze7cSh6sn8kc1-tnlLIRzwfU11xnyHQIMeHY',
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUri: false,
    ),
  );
  await LanguageService.initialize();
  runApp(const AuxiliaryAdminApp());
}

class AuxiliaryAdminApp extends StatelessWidget {
  const AuxiliaryAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DebugWrapper(
      child: ValueListenableBuilder<String>(
        valueListenable: LanguageService.currentLanguage,
        builder: (context, language, _) {
          return MaterialApp(
            key: ValueKey('app_lang_$language'),
            title: 'Auxiliary Office Admin',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              // Eto yung Sky Blue at White combination natin
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00BFFF), // Deep Sky Blue
                primary: const Color(0xFF00BFFF),
                surface: Colors.white,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(), // Premium font style
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
