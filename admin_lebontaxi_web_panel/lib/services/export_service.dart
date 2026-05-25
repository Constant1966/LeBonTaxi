import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service d'exportation CSV pour le panel admin
class ExportService {
  static final _supabase = Supabase.instance.client;

  /// Télécharger un fichier CSV dans le navigateur
  static void _downloadCsv(String csvContent, String filename) {
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Échapper les valeurs pour CSV
  static String _escapeCsv(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Exporter les courses en CSV
  static Future<void> exportTrips() async {
    final data = await _supabase.from('trip_requests').select().order('created_at', ascending: false);
    
    final buffer = StringBuffer();
    buffer.writeln('ID,Statut,Client,Téléphone Client,Chauffeur,Téléphone Chauffeur,Adresse Départ,Adresse Arrivée,Montant (HTG),Distance,Durée,Date');
    
    for (final t in data) {
      buffer.writeln([
        _escapeCsv(t['trip_id']),
        _escapeCsv(t['status']),
        _escapeCsv(t['user_name']),
        _escapeCsv(t['user_phone']),
        _escapeCsv(t['driver_name']),
        _escapeCsv(t['driver_phone']),
        _escapeCsv(t['pickup_address']),
        _escapeCsv(t['dropoff_address']),
        _escapeCsv(t['fare_amount']),
        _escapeCsv(t['distance']),
        _escapeCsv(t['duration']),
        _escapeCsv(t['created_at']?.toString().substring(0, 19)),
      ].join(','));
    }

    final now = DateTime.now();
    _downloadCsv(buffer.toString(), 'courses_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv');
  }

  /// Exporter les chauffeurs en CSV
  static Future<void> exportDrivers() async {
    final data = await _supabase.from('drivers').select().order('name');
    
    final buffer = StringBuffer();
    buffer.writeln('ID,Nom,Téléphone,Email,Véhicule,Plaque,En Ligne,Bloqué,Date Inscription');
    
    for (final d in data) {
      buffer.writeln([
        _escapeCsv(d['id']),
        _escapeCsv(d['name']),
        _escapeCsv(d['phone']),
        _escapeCsv(d['email']),
        _escapeCsv('${d['car_model'] ?? ''} ${d['car_color'] ?? ''}'.trim()),
        _escapeCsv(d['car_number']),
        _escapeCsv(d['is_online'] == true ? 'Oui' : 'Non'),
        _escapeCsv(d['block_status'] == 'yes' ? 'Oui' : 'Non'),
        _escapeCsv(d['created_at']?.toString().substring(0, 19)),
      ].join(','));
    }

    final now = DateTime.now();
    _downloadCsv(buffer.toString(), 'chauffeurs_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv');
  }

  /// Exporter les utilisateurs en CSV
  static Future<void> exportUsers() async {
    final data = await _supabase.from('users').select().order('name');
    
    final buffer = StringBuffer();
    buffer.writeln('ID,Nom,Téléphone,Email,Bloqué,Date Inscription');
    
    for (final u in data) {
      buffer.writeln([
        _escapeCsv(u['id']),
        _escapeCsv(u['name']),
        _escapeCsv(u['phone']),
        _escapeCsv(u['email']),
        _escapeCsv(u['block_status'] == 'yes' ? 'Oui' : 'Non'),
        _escapeCsv(u['created_at']?.toString().substring(0, 19)),
      ].join(','));
    }

    final now = DateTime.now();
    _downloadCsv(buffer.toString(), 'utilisateurs_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv');
  }

  /// Exporter les revenus en CSV
  static Future<void> exportEarnings() async {
    List data;
    try {
      data = await _supabase.from('earnings').select().order('created_at', ascending: false);
    } catch (_) {
      data = [];
    }
    
    final buffer = StringBuffer();
    buffer.writeln('ID,Chauffeur ID,Montant (HTG),Type,Date');
    
    for (final e in data) {
      buffer.writeln([
        _escapeCsv(e['id']),
        _escapeCsv(e['driver_id']),
        _escapeCsv(e['amount']),
        _escapeCsv(e['type']),
        _escapeCsv(e['created_at']?.toString().substring(0, 19)),
      ].join(','));
    }

    final now = DateTime.now();
    _downloadCsv(buffer.toString(), 'revenus_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv');
  }
}
