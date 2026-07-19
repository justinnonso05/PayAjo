import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/core/network/api_client.dart';
import 'src/core/storage/secure_storage_service.dart';
import 'src/features/auth/data/user_repository.dart';
import 'src/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Dotenv init note: $e");
  }

  // An explicit container (instead of the implicit one ProviderScope would
  // create) so the 401 handler below — which runs outside any widget's
  // build method — can still read/write providers and bounce to login.
  final container = ProviderContainer();

  ApiClient.onUnauthorized = () async {
    await SecureStorageService().clear();
    container.read(currentUserProvider.notifier).state = null;
    container.read(sessionExpiredProvider.notifier).state = true;
    goRouter.go('/login');
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}
