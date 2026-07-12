import 'package:intl/intl.dart';

/// Formatage centralisé des montants et dates.
final NumberFormat _fcfa = NumberFormat('#,##0', 'fr_FR');

String fmtFcfa(num montant) => '${_fcfa.format(montant)} F';

String fmtFcfaLong(num montant) => '${_fcfa.format(montant)} FCFA';

/// Date ISO complète pour le stockage (triable en SQL).
String nowIso() => DateTime.now().toIso8601String();

/// 'AAAA-MM-JJ' du jour, pour filtres SQL.
String todayKey() => DateTime.now().toIso8601String().substring(0, 10);

/// Affichage humain d'une date stockée en ISO.
String fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('dd/MM/yyyy HH:mm').format(d);
}

String fmtDateCourte(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('dd/MM/yyyy').format(d);
}
