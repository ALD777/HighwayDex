import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:highwaydex/services/google_maps_highway_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelHistoryEntry {
  const TravelHistoryEntry({
    required this.date,
    required this.highwayName,
    required this.category,
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.routePoints,
    this.fromPlace = 'Unknown start',
    this.toPlace = 'Unknown destination',
    this.nationalHighways = const <String>[],
    this.stateHighways = const <String>[],
    this.asianHighways = const <String>[],
    this.highwayAnalysisStatus = 'not_requested',
    this.analysisMessage,
  });

  final DateTime date;
  final String highwayName;
  final String category;
  final double distanceKm;
  final double averageSpeedKmh;
  final List<LatLng> routePoints;
  final String fromPlace;
  final String toPlace;
  final List<String> nationalHighways;
  final List<String> stateHighways;
  final List<String> asianHighways;
  final String highwayAnalysisStatus;
  final String? analysisMessage;

  TravelHistoryEntry copyWith({
    List<String>? nationalHighways,
    List<String>? stateHighways,
    List<String>? asianHighways,
    String? highwayAnalysisStatus,
    String? analysisMessage,
  }) => TravelHistoryEntry(
    date: date,
    highwayName: highwayName,
    category: category,
    distanceKm: distanceKm,
    averageSpeedKmh: averageSpeedKmh,
    routePoints: routePoints,
    fromPlace: fromPlace,
    toPlace: toPlace,
    nationalHighways: nationalHighways ?? this.nationalHighways,
    stateHighways: stateHighways ?? this.stateHighways,
    asianHighways: asianHighways ?? this.asianHighways,
    highwayAnalysisStatus: highwayAnalysisStatus ?? this.highwayAnalysisStatus,
    analysisMessage: analysisMessage ?? this.analysisMessage,
  );

  Map<String, dynamic> toJson() => {
    'date': date.toUtc().toIso8601String(),
    'highway_name': highwayName,
    'category': category,
    'distance_km': distanceKm,
    'average_speed_kmh': averageSpeedKmh,
    'route_points': routePoints
        .map((point) => {'lat': point.latitude, 'lng': point.longitude})
        .toList(),
    'from_place': fromPlace,
    'to_place': toPlace,
    'national_highways': nationalHighways,
    'state_highways': stateHighways,
    'asian_highways': asianHighways,
    'highway_analysis_status': highwayAnalysisStatus,
    'analysis_message': analysisMessage,
  };

  factory TravelHistoryEntry.fromJson(Map<String, dynamic> json) {
    final distance = _finiteDouble(json['distance_km']);
    final averageSpeed = _finiteDouble(json['average_speed_kmh']);
    return TravelHistoryEntry(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      highwayName: json['highway_name'] as String? ?? 'Unknown route',
      category: json['category'] as String? ?? 'Rural',
      distanceKm: distance,
      averageSpeedKmh: averageSpeed,
      routePoints: _safeRoutePoints(json['route_points']),
      fromPlace: json['from_place'] as String? ?? 'Unknown start',
      toPlace: json['to_place'] as String? ?? 'Unknown destination',
      nationalHighways: _safeStrings(json['national_highways']),
      stateHighways: _safeStrings(json['state_highways']),
      asianHighways: _safeStrings(json['asian_highways']),
      highwayAnalysisStatus:
          json['highway_analysis_status'] as String? ?? 'not_requested',
      analysisMessage: json['analysis_message'] as String?,
    );
  }

  static double _finiteDouble(Object? value) {
    final number = value is num ? value.toDouble() : 0.0;
    return number.isFinite ? number : 0.0;
  }

  static double? _finiteCoordinate(Object? value) {
    final number = value is num ? value.toDouble() : double.nan;
    return number.isFinite ? number : null;
  }

  static List<LatLng> _safeRoutePoints(Object? value) {
    if (value is! List) return <LatLng>[];
    return value
        .whereType<Map>()
        .map((point) {
          final latitude = _finiteCoordinate(point['lat']);
          final longitude = _finiteCoordinate(point['lng']);
          if (latitude == null ||
              longitude == null ||
              latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180) {
            return null;
          }
          return LatLng(latitude, longitude);
        })
        .whereType<LatLng>()
        .toList();
  }

  static List<String> _safeStrings(Object? value) {
    if (value is! List) return <String>[];
    return value.whereType<String>().toList();
  }
}

class LocalStorageService {
  static const String _routePointsKey = 'highwaydex_route_points';
  static const String _driveSummaryKey = 'highwaydex_drive_summary';
  static const String _collectedCardsKey = 'highwaydex_collected_cards';
  static const String _travelHistoryKey = 'highwaydex_travel_history';
  static const String _collectedKilometersKey =
      'highwaydex_collected_kilometers';
  static const String _customHighwaysKey = 'highwaydex_custom_highways';
  static const String _identifiedHighwaysKey = 'highwaydex_identified_highways';
  static const String _tutorialCompletedKeyPrefix = 'highwaydex_tutorial_';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<String> exportData() async {
    await init();
    final Map<String, dynamic> data = {};
    for (final key in _prefs!.getKeys()) {
      data[key] = _prefs!.get(key);
    }
    return jsonEncode(data);
  }

  static Future<void> importData(String jsonString) async {
    await init();
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      for (final key in data.keys) {
        final value = data[key];
        if (value is String) {
          await _prefs!.setString(key, value);
        } else if (value is int) {
          await _prefs!.setInt(key, value);
        } else if (value is double) {
          await _prefs!.setDouble(key, value);
        } else if (value is bool) {
          await _prefs!.setBool(key, value);
        } else if (value is List) {
          final stringList = value.map((e) => e.toString()).toList();
          await _prefs!.setStringList(key, stringList);
        }
      }
    } catch (e) {
      debugPrint('Failed to import data: $e');
    }
  }

  static Future<bool> isFirstLaunch() async {
    await init();
    return !_prefs!.getKeys().contains(_travelHistoryKey);
  }

  // --- Tutorial Tracking ---
  static const String _tutorialGlobalDisableKey =
      'highwaydex_tutorials_disabled';

  static Future<bool> areTutorialsGloballyDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialGlobalDisableKey) ?? false;
  }

  static Future<void> setTutorialsGloballyDisabled(bool disabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialGlobalDisableKey, disabled);
  }

  static Future<bool> isTutorialCompleted(String tutorialName) async {
    await init();
    return _prefs!.getBool('$_tutorialCompletedKeyPrefix$tutorialName') ??
        false;
  }

  static Future<void> markTutorialCompleted(String tutorialName) async {
    await init();
    await _prefs!.setBool('$_tutorialCompletedKeyPrefix$tutorialName', true);
  }

  static Future<DateTime?> getLastBackupDate() async {
    await init();
    final str = _prefs!.getString('last_backup_date');
    if (str != null) return DateTime.tryParse(str);
    return null;
  }

  static Future<void> setLastBackupDate(DateTime date) async {
    await init();
    await _prefs!.setString('last_backup_date', date.toIso8601String());
  }

  static Future<void> saveRoutePoints(List<LatLng> points) async {
    await init();
    final payload = points
        .map((point) => {'lat': point.latitude, 'lng': point.longitude})
        .toList();
    await _prefs!.setString(_routePointsKey, jsonEncode(payload));
  }

  static Future<List<LatLng>> loadRoutePoints() async {
    await init();
    final raw = _prefs!.getString(_routePointsKey);
    if (raw == null || raw.isEmpty) {
      return <LatLng>[];
    }

    try {
      final decoded = jsonDecode(raw);
      return TravelHistoryEntry._safeRoutePoints(decoded);
    } catch (_) {
      return <LatLng>[];
    }
  }

  static Future<void> saveDriveSummary({
    required double distanceKm,
    required String highwayName,
    required String locationName,
    required double speedKmh,
    required double lifetimeAverageSpeedKmh,
    required double lifetimeSpeedTotal,
    required int lifetimeSpeedSamples,
  }) async {
    await init();
    final payload = {
      'distance_km': distanceKm,
      'highway_name': highwayName,
      'location_name': locationName,
      'speed_kmh': speedKmh,
      'lifetime_average_speed_kmh': lifetimeAverageSpeedKmh,
      'lifetime_speed_total': lifetimeSpeedTotal,
      'lifetime_speed_samples': lifetimeSpeedSamples,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _prefs!.setString(_driveSummaryKey, jsonEncode(payload));
  }

  static Future<Map<String, dynamic>> loadDriveSummary() async {
    await init();
    final raw = _prefs!.getString(_driveSummaryKey);
    if (raw == null || raw.isEmpty) {
      return {
        'distance_km': 0.0,
        'highway_name': 'No route yet',
        'location_name': 'No location yet',
        'speed_kmh': 0.0,
        'lifetime_average_speed_kmh': 0.0,
        'lifetime_speed_total': 0.0,
        'lifetime_speed_samples': 0,
      };
    }

    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : _defaultDriveSummary();
    } catch (_) {
      return _defaultDriveSummary();
    }
  }

  static Future<void> saveCollectedCards(List<String> cardNames) async {
    await init();
    await _prefs!.setStringList(_collectedCardsKey, cardNames);
  }

  static Future<List<String>> loadCollectedCards() async {
    await init();
    return _prefs!.getStringList(_collectedCardsKey) ?? <String>[];
  }

  static Future<void> saveCollectedKilometers(
    Map<String, double> kilometers,
  ) async {
    await init();
    await _prefs!.setString(_collectedKilometersKey, jsonEncode(kilometers));
  }

  static Future<Map<String, double>> loadCollectedKilometers() async {
    await init();
    final raw = _prefs!.getString(_collectedKilometersKey);
    if (raw == null || raw.isEmpty) return <String, double>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, double>{};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value is num && value.isFinite ? value.toDouble() : 0.0,
        ),
      );
    } catch (_) {
      return <String, double>{};
    }
  }

  static Future<void> saveCustomHighways(
    List<Map<String, dynamic>> highways,
  ) async {
    await init();
    await _prefs!.setString(_customHighwaysKey, jsonEncode(highways));
  }

  static Future<List<Map<String, dynamic>>> loadCustomHighways() async {
    await init();
    final raw = _prefs!.getString(_customHighwaysKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveTravelHistory(
    List<TravelHistoryEntry> entries,
  ) async {
    await init();
    final payload = entries.map((entry) => entry.toJson()).toList();
    await _prefs!.setString(_travelHistoryKey, jsonEncode(payload));
    await syncIdentifiedHighwaysFromHistory();
  }

  static Future<void> updateTravelHistoryEntry(
    TravelHistoryEntry original,
    TravelHistoryEntry updated,
  ) async {
    final entries = await loadTravelHistory();
    final index = entries.indexWhere(
      (entry) =>
          entry.date.toUtc().toIso8601String() ==
              original.date.toUtc().toIso8601String() &&
          _sameRoute(entry.routePoints, original.routePoints) &&
          entry.fromPlace == original.fromPlace &&
          entry.toPlace == original.toPlace,
    );
    if (index == -1) return;
    entries[index] = updated;
    await saveTravelHistory(entries);
  }

  static Future<void> deleteTravelHistoryEntry(TravelHistoryEntry entry) async {
    final entries = await loadTravelHistory();
    entries.removeWhere(
      (e) =>
          e.date.toUtc().toIso8601String() ==
              entry.date.toUtc().toIso8601String() &&
          e.fromPlace == entry.fromPlace &&
          e.toPlace == entry.toPlace,
    );
    await saveTravelHistory(entries);
  }

  static bool _sameRoute(List<LatLng> first, List<LatLng> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].latitude != second[index].latitude ||
          first[index].longitude != second[index].longitude) {
        return false;
      }
    }
    return true;
  }

  static Future<List<TravelHistoryEntry>> loadTravelHistory() async {
    await init();
    final raw = _prefs!.getString(_travelHistoryKey);
    if (raw == null || raw.isEmpty) {
      return <TravelHistoryEntry>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                TravelHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return <TravelHistoryEntry>[];
    }
  }

  static Future<void> saveIdentifiedHighways(
    List<IdentifiedHighway> highways,
  ) async {
    await init();
    final payload = highways.map((h) => h.toJson()).toList();
    await _prefs!.setString(_identifiedHighwaysKey, jsonEncode(payload));
  }

  static Future<List<IdentifiedHighway>> loadIdentifiedHighways() async {
    await init();
    final raw = _prefs!.getString(_identifiedHighwaysKey);
    if (raw == null || raw.isEmpty) {
      return syncIdentifiedHighwaysFromHistory();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return syncIdentifiedHighwaysFromHistory();
      final list = decoded
          .whereType<Map>()
          .map(
            (item) =>
                IdentifiedHighway.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      list.sort(IdentifiedHighway.compareAscending);
      return list;
    } catch (_) {
      return syncIdentifiedHighwaysFromHistory();
    }
  }

  static Future<List<IdentifiedHighway>>
  syncIdentifiedHighwaysFromHistory() async {
    final history = await loadTravelHistory();
    final uniqueMap = <String, IdentifiedHighway>{};

    for (final entry in history) {
      final tripRoute = '${entry.fromPlace} to ${entry.toPlace}';
      final tripDate = entry.date;

      final allCandidates = [
        ...entry.nationalHighways,
        ...entry.stateHighways,
        if (entry.highwayName.isNotEmpty &&
            entry.highwayName != 'Journey' &&
            entry.highwayName != 'Unknown route')
          entry.highwayName,
      ];

      final tripHighways = <String, IdentifiedHighway>{};
      for (final candidate in allCandidates) {
        final parsed = HighwayParser.parse(
          primary: candidate,
          tripRoute: tripRoute,
          date: tripDate,
        );
        if (parsed == null) continue;
        final key = parsed.code.replaceAll(' ', '').toUpperCase();
        tripHighways.putIfAbsent(key, () => parsed);
      }

      for (final entryPair in tripHighways.entries) {
        final key = entryPair.key;
        final parsed = entryPair.value;
        if (uniqueMap.containsKey(key)) {
          final existing = uniqueMap[key]!;
          final updatedRoutes = List<String>.from(existing.tripRoutes);
          if (!updatedRoutes.contains(tripRoute)) {
            updatedRoutes.add(tripRoute);
          }
          final latestDate =
              existing.lastTraveledDate == null ||
                  tripDate.isAfter(existing.lastTraveledDate!)
              ? tripDate
              : existing.lastTraveledDate;

          uniqueMap[key] = existing.copyWith(
            tripCount: existing.tripCount + 1,
            tripRoutes: updatedRoutes,
            lastTraveledDate: latestDate,
          );
        } else {
          uniqueMap[key] = parsed;
        }
      }
    }

    final sortedList = uniqueMap.values.toList()
      ..sort(IdentifiedHighway.compareAscending);

    await saveIdentifiedHighways(sortedList);
    return sortedList;
  }

  static Map<String, dynamic> _defaultDriveSummary() => {
    'distance_km': 0.0,
    'highway_name': 'No route yet',
    'location_name': 'No location yet',
    'speed_kmh': 0.0,
    'lifetime_average_speed_kmh': 0.0,
    'lifetime_speed_total': 0.0,
    'lifetime_speed_samples': 0,
  };
}
