import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class HighwayAnalysis {
  const HighwayAnalysis({
    required this.nationalHighways,
    required this.stateHighways,
    this.asianHighways = const <String>[],
    required this.status,
    this.message,
    this.identifiedHighways = const <IdentifiedHighway>[],
  });

  final List<String> nationalHighways;
  final List<String> stateHighways;
  final List<String> asianHighways;
  final String status;
  final String? message;
  final List<IdentifiedHighway> identifiedHighways;
}

class IdentifiedHighway {
  const IdentifiedHighway({
    required this.code,
    required this.name,
    required this.category,
    required this.number,
    this.suffix = '',
    this.tripRoutes = const <String>[],
    this.lastTraveledDate,
    this.tripCount = 1,
  });

  final String code; // e.g. "NH5", "NH55", "NH149", "SH10"
  final String name; // e.g. "National Highway 55"
  final String category; // 'national' or 'state'
  final int number; // 5, 55, 149
  final String suffix; // e.g. "A" for NH5A
  final List<String> tripRoutes;
  final DateTime? lastTraveledDate;
  final int tripCount;

  String get displayName {
    if (name.isNotEmpty && !name.startsWith(code)) {
      return '$code - $name';
    }
    return name.isNotEmpty ? name : code;
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'category': category,
    'number': number,
    'suffix': suffix,
    'trip_routes': tripRoutes,
    'last_traveled_date': lastTraveledDate?.toUtc().toIso8601String(),
    'trip_count': tripCount,
  };

  factory IdentifiedHighway.fromJson(Map<String, dynamic> json) {
    return IdentifiedHighway(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'national',
      number: (json['number'] as num?)?.toInt() ?? 0,
      suffix: json['suffix'] as String? ?? '',
      tripRoutes:
          (json['trip_routes'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          <String>[],
      lastTraveledDate: DateTime.tryParse(
        json['last_traveled_date'] as String? ?? '',
      ),
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 1,
    );
  }

  IdentifiedHighway copyWith({
    String? code,
    String? name,
    String? category,
    int? number,
    String? suffix,
    List<String>? tripRoutes,
    DateTime? lastTraveledDate,
    int? tripCount,
  }) {
    return IdentifiedHighway(
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      number: number ?? this.number,
      suffix: suffix ?? this.suffix,
      tripRoutes: tripRoutes ?? this.tripRoutes,
      lastTraveledDate: lastTraveledDate ?? this.lastTraveledDate,
      tripCount: tripCount ?? this.tripCount,
    );
  }

  static int compareAscending(IdentifiedHighway a, IdentifiedHighway b) {
    if (a.number != b.number) {
      return a.number.compareTo(b.number);
    }
    if (a.suffix != b.suffix) {
      return a.suffix.compareTo(b.suffix);
    }
    return a.code.compareTo(b.code);
  }
}

class HighwayParser {
  static final _nhRegex = RegExp(
    r'(?:(?:National\s+H(?:igh)?way(?:\s+No\.?)?)|(?:\bNH))\s*[-–]?\s*(\d+)\s*([A-Za-z])?\b',
    caseSensitive: false,
  );

  static final _shRegex = RegExp(
    r'(?:([A-Za-z]{2})\s*[-–]?\s*)?(?:(?:State\s+H(?:igh)?way(?:\s+No\.?)?)|(?:\bSH))\s*[-–]?\s*(\d+)\s*([A-Za-z])?\b',
    caseSensitive: false,
  );

  static final _ahRegex = RegExp(
    r'(?:(?:Asian\s+H(?:igh)?way(?:\s+No\.?)?)|(?:\bAH))\s*[-–]?\s*(\d+)\s*([A-Za-z])?\b',
    caseSensitive: false,
  );

  static IdentifiedHighway? parse({
    required String primary,
    String? secondary,
    String? context,
    String? tripRoute,
    DateTime? date,
  }) {
    final candidates = [primary, secondary ?? '', context ?? ''];
    for (final text in candidates) {
      if (text.trim().isEmpty) continue;

      // 1. Check National Highway (NH)
      final nhMatch = _nhRegex.firstMatch(text);
      if (nhMatch != null) {
        final numberStr = nhMatch.group(1)!;
        final number = int.tryParse(numberStr) ?? 0;
        final suffix = nhMatch.group(2)?.toUpperCase() ?? '';
        final code = 'NH$number$suffix';

        final descriptive = _extractDescriptiveName(primary, secondary, code);
        final name = descriptive.isNotEmpty
            ? 'National Highway $number$suffix ($descriptive)'
            : 'National Highway $number$suffix';

        return IdentifiedHighway(
          code: code,
          name: name,
          category: 'national',
          number: number,
          suffix: suffix,
          tripRoutes: tripRoute != null ? [tripRoute] : const [],
          lastTraveledDate: date,
          tripCount: 1,
        );
      }

      // 2. Check State Highway (SH)
      final shMatch = _shRegex.firstMatch(text);
      if (shMatch != null) {
        final statePrefix = shMatch.group(1)?.toUpperCase();
        final numberStr = shMatch.group(2)!;
        final number = int.tryParse(numberStr) ?? 0;
        final suffix = shMatch.group(3)?.toUpperCase() ?? '';
        final code = statePrefix != null && statePrefix.isNotEmpty
            ? '$statePrefix SH$number$suffix'
            : 'SH$number$suffix';

        final descriptive = _extractDescriptiveName(primary, secondary, code);
        final name = descriptive.isNotEmpty
            ? 'State Highway $number$suffix ($descriptive)'
            : 'State Highway $number$suffix';

        return IdentifiedHighway(
          code: code,
          name: name,
          category: 'state',
          number: number,
          suffix: suffix,
          tripRoutes: tripRoute != null ? [tripRoute] : const [],
          lastTraveledDate: date,
          tripCount: 1,
        );
      }

      // 3. Check Asian Highway (AH)
      final ahMatch = _ahRegex.firstMatch(text);
      if (ahMatch != null) {
        final numberStr = ahMatch.group(1)!;
        final number = int.tryParse(numberStr) ?? 0;
        final suffix = ahMatch.group(2)?.toUpperCase() ?? '';
        final code = 'AH$number$suffix';

        final descriptive = _extractDescriptiveName(primary, secondary, code);
        final name = descriptive.isNotEmpty
            ? 'Asian Highway $number$suffix ($descriptive)'
            : 'Asian Highway $number$suffix';

        return IdentifiedHighway(
          code: code,
          name: name,
          category: 'asian',
          number: number,
          suffix: suffix,
          tripRoutes: tripRoute != null ? [tripRoute] : const [],
          lastTraveledDate: date,
          tripCount: 1,
        );
      }
    }

    return null;
  }

  static String _extractDescriptiveName(
    String primary,
    String? secondary,
    String code,
  ) {
    for (final candidate in [secondary, primary]) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final trimmed = candidate.trim();
      final normalizedCode = code.replaceAll(' ', '').toLowerCase();
      final normalizedTrimmed = trimmed.replaceAll(' ', '').toLowerCase();

      if (!normalizedTrimmed.contains(normalizedCode) && trimmed.length > 3) {
        return trimmed;
      }
      if (trimmed.contains('-') || trimmed.contains('–')) {
        final parts = trimmed.split(RegExp(r'[-–]'));
        if (parts.length > 1) {
          final desc = parts.sublist(1).join('-').trim();
          if (desc.isNotEmpty && !desc.toLowerCase().contains(normalizedCode)) {
            return desc;
          }
        }
      }
    }
    return '';
  }
}

class GoogleMapsHighwayService {
  static const String apiKey = 'AIzaSyD5lySZodpn496vaShY292ofpKV5Q4evTU';
  static const _requestTimeout = Duration(seconds: 60);
  static final _roadsEndpoint = Uri.parse(
    'https://roads.googleapis.com/v1/snapToRoads',
  );
  static final _geocodeEndpoint = Uri.parse(
    'https://maps.googleapis.com/maps/api/geocode/json',
  );

  static bool get isConfigured => apiKey.isNotEmpty;

  static Future<HighwayAnalysis> analyzeRoute({
    required List<LatLng> routePoints,
    required String start,
    required String end,
    DateTime? tripDate,
  }) async {
    if (!isConfigured) {
      return const HighwayAnalysis(
        nationalHighways: <String>[],
        stateHighways: <String>[],
        asianHighways: <String>[],
        status: 'not_configured',
        message: 'Launch with GOOGLE_MAPS_API_KEY configured.',
      );
    }
    if (routePoints.isEmpty) {
      return const HighwayAnalysis(
        nationalHighways: <String>[],
        stateHighways: <String>[],
        asianHighways: <String>[],
        status: 'no_route',
        message: 'This trip has no saved GPS points to analyze.',
      );
    }

    final tripRoute = '$start to $end';
    final date = tripDate ?? DateTime.now();

    try {
      final sampledPoints = _sampleRoute(routePoints, 100);
      final path = sampledPoints
          .map(
            (point) =>
                '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
          )
          .join('|');

      final roadsResponse = await http
          .get(
            _roadsEndpoint.replace(
              queryParameters: {'path': path, 'key': apiKey},
            ),
          )
          .timeout(_requestTimeout);

      final matches = <IdentifiedHighway>[];

      if (roadsResponse.statusCode >= 200 && roadsResponse.statusCode < 300) {
        final roadsJson = jsonDecode(roadsResponse.body);
        final placeIds = _placeIdsInRouteOrder(roadsJson);
        if (placeIds.isNotEmpty) {
          final placeResults = await Future.wait(
            placeIds.map(
              (placeId) =>
                  _geocodePlace(placeId, tripRoute: tripRoute, tripDate: date),
            ),
          );
          for (final list in placeResults) {
            matches.addAll(list);
          }
        }
      }

      // Fallback: reverse-geocode sampled coordinates directly if roads API yielded no highways
      if (matches.isEmpty) {
        final coordSamples = _sampleRoute(routePoints, 8);
        for (final pt in coordSamples) {
          final coordMatches = await _geocodeCoordinates(
            pt,
            tripRoute: tripRoute,
            tripDate: date,
          );
          matches.addAll(coordMatches);
        }
      }

      if (matches.isEmpty &&
          roadsResponse.statusCode != 200 &&
          (roadsResponse.statusCode < 200 || roadsResponse.statusCode >= 300)) {
        return _httpFailure(roadsResponse.statusCode, 'Snap to Roads');
      }

      // Deduplicate highways by normalized code
      final uniqueHighways = <String, IdentifiedHighway>{};
      for (final highway in matches) {
        final key = highway.code.replaceAll(' ', '').toUpperCase();
        if (uniqueHighways.containsKey(key)) {
          final existing = uniqueHighways[key]!;
          final updatedRoutes = List<String>.from(existing.tripRoutes);
          if (!updatedRoutes.contains(tripRoute)) {
            updatedRoutes.add(tripRoute);
          }
          uniqueHighways[key] = existing.copyWith(
            tripCount: existing.tripCount + 1,
            tripRoutes: updatedRoutes,
            lastTraveledDate: date,
          );
        } else {
          uniqueHighways[key] = highway;
        }
      }

      final allIdentified = uniqueHighways.values.toList()
        ..sort(IdentifiedHighway.compareAscending);

      final nationalHighways = <String>[];
      final stateHighways = <String>[];
      final asianHighways = <String>[];

      for (final h in allIdentified) {
        final display = h.displayName;
        if (h.category == 'national') {
          _addUnique(nationalHighways, display);
        } else if (h.category == 'state') {
          _addUnique(stateHighways, display);
        } else if (h.category == 'asian') {
          _addUnique(asianHighways, display);
        }
      }

      return HighwayAnalysis(
        nationalHighways: nationalHighways,
        stateHighways: stateHighways,
        asianHighways: asianHighways,
        status: 'completed',
        message: allIdentified.isEmpty
            ? 'No state, national, or asian highways confidently identified.'
            : 'Found ${allIdentified.length} state/national/asian highway(s).',
        identifiedHighways: allIdentified,
      );
    } on TimeoutException {
      return const HighwayAnalysis(
        nationalHighways: <String>[],
        stateHighways: <String>[],
        asianHighways: <String>[],
        status: 'timeout',
        message: 'Google Maps took too long to analyze the full route.',
      );
    } on FormatException {
      return const HighwayAnalysis(
        nationalHighways: <String>[],
        stateHighways: <String>[],
        asianHighways: <String>[],
        status: 'invalid_response',
        message: 'Google Maps returned an unreadable highway result.',
      );
    } catch (_) {
      return const HighwayAnalysis(
        nationalHighways: <String>[],
        stateHighways: <String>[],
        asianHighways: <String>[],
        status: 'network_error',
        message: 'Google Maps could not be reached. Check your connection.',
      );
    }
  }

  static List<LatLng> _sampleRoute(List<LatLng> points, int limit) {
    if (points.length <= limit) return List<LatLng>.from(points);
    final step = (points.length - 1) / (limit - 1);
    return List<LatLng>.generate(
      limit,
      (index) => points[(index * step).round()],
    );
  }

  static List<String> _placeIdsInRouteOrder(Object? response) {
    if (response is! Map || response['snappedPoints'] is! List) {
      return <String>[];
    }
    final placeIds = <String>[];
    final seen = <String>{};
    for (final point in response['snappedPoints'] as List) {
      if (point is! Map || point['placeId'] is! String) continue;
      final placeId = (point['placeId'] as String).trim();
      if (placeId.isNotEmpty && seen.add(placeId)) placeIds.add(placeId);
    }
    return placeIds;
  }

  static Future<List<IdentifiedHighway>> _geocodePlace(
    String placeId, {
    String? tripRoute,
    DateTime? tripDate,
  }) async {
    try {
      final response = await http
          .get(
            _geocodeEndpoint.replace(
              queryParameters: {'place_id': placeId, 'key': apiKey},
            ),
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <IdentifiedHighway>[];
      }
      final decoded = jsonDecode(response.body);
      return _extractHighwaysFromGeocode(
        decoded,
        tripRoute: tripRoute,
        tripDate: tripDate,
      );
    } catch (_) {
      return const <IdentifiedHighway>[];
    }
  }

  static Future<List<IdentifiedHighway>> _geocodeCoordinates(
    LatLng point, {
    String? tripRoute,
    DateTime? tripDate,
  }) async {
    try {
      final response = await http
          .get(
            _geocodeEndpoint.replace(
              queryParameters: {
                'latlng': '${point.latitude},${point.longitude}',
                'result_type': 'route',
                'key': apiKey,
              },
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <IdentifiedHighway>[];
      }
      final decoded = jsonDecode(response.body);
      return _extractHighwaysFromGeocode(
        decoded,
        tripRoute: tripRoute,
        tripDate: tripDate,
      );
    } catch (_) {
      return const <IdentifiedHighway>[];
    }
  }

  static List<IdentifiedHighway> _extractHighwaysFromGeocode(
    Object? decoded, {
    String? tripRoute,
    DateTime? tripDate,
  }) {
    if (decoded is! Map || decoded['results'] is! List) {
      return const <IdentifiedHighway>[];
    }
    final results = decoded['results'] as List;
    final highways = <IdentifiedHighway>[];

    for (final result in results) {
      if (result is! Map) continue;
      final formattedAddress = result['formatted_address'] as String? ?? '';
      final components = result['address_components'] as List? ?? [];

      for (final component in components) {
        if (component is! Map) continue;
        final types = (component['types'] as List? ?? []).whereType<String>();
        final longName = component['long_name'] as String? ?? '';
        final shortName = component['short_name'] as String? ?? '';

        final highway = HighwayParser.parse(
          primary: shortName,
          secondary: longName,
          context: formattedAddress,
          tripRoute: tripRoute,
          date: tripDate,
        );
        if (highway != null) {
          highways.add(highway);
        } else if (types.contains('route')) {
          // If route type but not matched by short/long alone, try formattedAddress
          final routeHighway = HighwayParser.parse(
            primary: formattedAddress,
            secondary: longName.isNotEmpty ? longName : shortName,
            tripRoute: tripRoute,
            date: tripDate,
          );
          if (routeHighway != null) {
            highways.add(routeHighway);
          }
        }
      }
    }
    return highways;
  }

  static void _addUnique(List<String> values, String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isNotEmpty &&
        !values.any((item) => item.trim().toLowerCase() == normalized)) {
      values.add(value.trim());
    }
  }

  static HighwayAnalysis _httpFailure(int statusCode, String service) {
    final status = switch (statusCode) {
      401 || 403 => 'unauthorized',
      429 => 'rate_limited',
      >= 500 => 'service_error',
      _ => 'request_error',
    };
    return HighwayAnalysis(
      nationalHighways: const <String>[],
      stateHighways: const <String>[],
      asianHighways: const <String>[],
      status: status,
      message: '$service request failed (HTTP $statusCode).',
    );
  }
}
