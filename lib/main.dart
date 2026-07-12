import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite sur Windows/Linux passe par FFI.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('fr_FR');
  await AuthService.initialiser();

  runApp(const WaterStockApp());

  // Sauvegarde quotidienne en arrière-plan, sans bloquer le démarrage.
  BackupService.sauvegardeAutomatique();
}

class WaterStockApp extends StatelessWidget {
  const WaterStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Dépôt Eau',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoginScreen(),
    );
  }
}
