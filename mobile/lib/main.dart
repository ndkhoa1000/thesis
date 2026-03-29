import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'src/app/app.dart';
import 'src/core/auth/token_store.dart';
import 'src/core/network/api_client.dart';
import 'src/features/auth/data/auth_service.dart';

export 'src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final mapboxToken =
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['ACCESS_TOKEN'];

  if (mapboxToken != null && mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }

  runApp(
    MyApp(
      authService: BackendAuthService(
        apiClient: ApiClient(),
        tokenStore: SecureTokenStore(),
      ),
    ),
  );
}
