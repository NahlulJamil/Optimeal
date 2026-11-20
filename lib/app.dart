import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

/// Root widget Optimeal.
///
/// Tema masih berupa scaffold. Token warna, tipografi, dan spacing final
/// diambil dari Figma page "HiFi Optimeal" sebelum scene pertama dikerjakan.
class OptimealApp extends StatelessWidget {
  const OptimealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Optimeal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
      ),
      home: const SetupCheckScreen(),
    );
  }
}

/// Layar sementara untuk memastikan Firebase sudah terpasang benar.
/// Akan diganti oleh scene Login / Home.
class SetupCheckScreen extends StatelessWidget {
  const SetupCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final projectId = Firebase.app().options.projectId;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, size: 64, color: Color(0xFF1B5E20)),
              const SizedBox(height: 16),
              Text(
                'Optimeal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Firebase connected',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                projectId,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
