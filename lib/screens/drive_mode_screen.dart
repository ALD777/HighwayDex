import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:highwaydex/services/google_maps_highway_service.dart';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:highwaydex/services/tutorial_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class DriveModeScreen extends StatefulWidget {
  const DriveModeScreen({super.key});

  @override
  State<DriveModeScreen> createState() => _DriveModeScreenState();
}

class _DriveModeScreenState extends State<DriveModeScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = <LatLng>[];
  final List<LatLng> _sessionRoutePoints = <LatLng>[];

  Position? _currentPosition;
  String _currentLocationName = 'No location yet';
  String _startLocationName = 'Unknown start';
  bool _isDriving = false;
  double _currentSpeedKmh = 0;
  double _lifetimeAverageSpeedKmh = 0;
  double _lifetimeSpeedTotal = 0;
  int _lifetimeSpeedSamples = 0;
  double _distanceKm = 0;
  double _sessionStartDistanceKm = 0;
  double _sessionSpeedTotal = 0;
  int _sessionSpeedSamples = 0;
  DateTime? _tripStartedAt;
  LatLng? _lastPoint;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _loadPersistedData();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPersistedData() async {
    final savedPoints = await LocalStorageService.loadRoutePoints();
    final summary = await LocalStorageService.loadDriveSummary();

    if (!mounted) {
      return;
    }

    setState(() {
      _routePoints.clear();
      _routePoints.addAll(savedPoints);
      _distanceKm = (summary['distance_km'] as num?)?.toDouble() ?? 0;
      _currentLocationName =
          summary['location_name'] as String? ?? 'No location yet';
      _currentSpeedKmh = (summary['speed_kmh'] as num?)?.toDouble() ?? 0;
      _lifetimeAverageSpeedKmh =
          (summary['lifetime_average_speed_kmh'] as num?)?.toDouble() ?? 0;
      _lifetimeSpeedTotal =
          (summary['lifetime_speed_total'] as num?)?.toDouble() ?? 0;
      _lifetimeSpeedSamples =
          (summary['lifetime_speed_samples'] as num?)?.toInt() ?? 0;
      if (_routePoints.isNotEmpty) {
        _lastPoint = _routePoints.last;
      }
    });
  }

  Future<void> _toggleDriveMode() async {
    if (_isDriving) {
      final tripDistance = _distanceKm - _sessionStartDistanceKm;
      final shouldSaveTrip = tripDistance >= 2;

      setState(() => _isDriving = false);
      _positionSubscription?.cancel();

      if (shouldSaveTrip) {
        final history = await LocalStorageService.loadTravelHistory();
        final averageSpeed = _sessionSpeedSamples == 0
            ? 0.0
            : _sessionSpeedTotal / _sessionSpeedSamples;
        final entry = TravelHistoryEntry(
          date: _tripStartedAt ?? DateTime.now(),
          highwayName: 'Journey',
          category: 'Trip',
          distanceKm: tripDistance,
          averageSpeedKmh: averageSpeed,
          routePoints: List<LatLng>.from(_sessionRoutePoints),
          fromPlace: _startLocationName,
          toPlace: _currentLocationName,
          highwayAnalysisStatus: 'pending',
        );
        history.add(entry);
        await LocalStorageService.saveTravelHistory(history);
        unawaited(_analyzeAndUpdateTrip(entry));
      }

      _showMessage(
        shouldSaveTrip
            ? 'Trip saved to history (${tripDistance.toStringAsFixed(1)} km)'
            : 'Trip could not be saved.',
      );

      await LocalStorageService.saveDriveSummary(
        distanceKm: _distanceKm,
        highwayName: 'Journey',
        locationName: _currentLocationName,
        speedKmh: _currentSpeedKmh,
        lifetimeAverageSpeedKmh: _lifetimeAverageSpeedKmh,
        lifetimeSpeedTotal: _lifetimeSpeedTotal,
        lifetimeSpeedSamples: _lifetimeSpeedSamples,
      );
      await LocalStorageService.saveRoutePoints(_routePoints);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Please enable location access before starting drive mode.');
      return;
    }

    // Forcefully request location permissions using permission_handler
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied && defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, sometimes requesting location doesn't prompt for Always.
        // We can request locationAlways as a fallback to trigger the system dialog.
        status = await Permission.locationAlways.request();
      }
    }

    if (status.isPermanentlyDenied) {
      _showMessage('Location permanently denied. Opening settings...');
      await Future.delayed(const Duration(milliseconds: 1500));
      await openAppSettings();
      return;
    }

    if (!status.isGranted && !status.isLimited) {
      _showMessage('Location permission required to track highways.');
      return;
    }

    setState(() {
      _isDriving = true;
      _sessionStartDistanceKm = _distanceKm;
      _tripStartedAt = DateTime.now();
      _sessionSpeedTotal = 0;
      _sessionSpeedSamples = 0;
      _lastPoint = null;
      _sessionRoutePoints.clear();
      _startLocationName = _currentLocationName;
    });
    await _subscribeToLocationStream();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
    await _handleLocationUpdate(position, isInitial: true);
    _startLocationName = _currentLocationName;
    _showMessage('Drive mode activated. Route logging started.');
  }

  Future<void> _analyzeAndUpdateTrip(TravelHistoryEntry entry) async {
    try {
      final analysis = await GoogleMapsHighwayService.analyzeRoute(
        routePoints: entry.routePoints,
        start: entry.fromPlace,
        end: entry.toPlace,
        tripDate: entry.date,
      );
      final history = await LocalStorageService.loadTravelHistory();
      final index = history.lastIndexWhere(
        (item) =>
            item.date.toUtc().toIso8601String() ==
            entry.date.toUtc().toIso8601String(),
      );
      if (index == -1) return;
      history[index] = entry.copyWith(
        nationalHighways: analysis.nationalHighways,
        stateHighways: analysis.stateHighways,
        asianHighways: analysis.asianHighways,
        highwayAnalysisStatus: analysis.status,
        analysisMessage: analysis.message,
      );
      await LocalStorageService.saveTravelHistory(history);
    } catch (e) {
      try {
        final history = await LocalStorageService.loadTravelHistory();
        final index = history.lastIndexWhere(
          (item) =>
              item.date.toUtc().toIso8601String() ==
              entry.date.toUtc().toIso8601String(),
        );
        if (index == -1) return;
        history[index] = entry.copyWith(
          highwayAnalysisStatus: 'failed',
          analysisMessage: 'Highway analysis could not be saved: $e',
        );
        await LocalStorageService.saveTravelHistory(history);
      } catch (_) {
        // The completed trip remains saved even if its analysis status cannot.
      }
    }
  }

  Future<void> _subscribeToLocationStream() async {
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              'Highwaydex is running in the background to record your trip.',
          notificationTitle: 'Drive Mode Active',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) async {
            await _handleLocationUpdate(position);
          },
        );
  }

  Future<void> _showCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
      await _handleLocationUpdate(position);
      _mapController.move(LatLng(position.latitude, position.longitude), 16);
    } catch (_) {
      _showMessage('Current location is unavailable right now.');
    }
  }

  Future<void> _handleLocationUpdate(
    Position position, {
    bool isInitial = false,
  }) async {
    final latLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentPosition = position;
      _currentSpeedKmh = position.speed >= 0 ? position.speed * 3.6 : 0;
      if (_isDriving && position.speed >= 0) {
        _lifetimeSpeedTotal += _currentSpeedKmh;
        _lifetimeSpeedSamples++;
        _lifetimeAverageSpeedKmh = _lifetimeSpeedTotal / _lifetimeSpeedSamples;
      }
      if (_isDriving) {
        _sessionSpeedTotal += _currentSpeedKmh;
        _sessionSpeedSamples++;
      }
    });

    var distanceKmSinceLastPoint = 0.0;
    if (_isDriving && _lastPoint != null) {
      final distanceMeters = const Distance().distance(_lastPoint!, latLng);
      if (distanceMeters > 0) {
        distanceKmSinceLastPoint = distanceMeters / 1000;
        _distanceKm += distanceKmSinceLastPoint;
      }
    }
    _lastPoint = latLng;

    if (_isDriving &&
        (isInitial || _routePoints.isEmpty || _routePoints.last != latLng)) {
      setState(() => _routePoints.add(latLng));
    }
    if (_isDriving &&
        (isInitial ||
            _sessionRoutePoints.isEmpty ||
            _sessionRoutePoints.last != latLng)) {
      setState(() => _sessionRoutePoints.add(latLng));
    }

    _mapController.move(latLng, 15);
    await _reverseGeocode(position.latitude, position.longitude);
    await LocalStorageService.saveRoutePoints(_routePoints);
    await LocalStorageService.saveDriveSummary(
      distanceKm: _distanceKm,
      highwayName: 'Journey',
      locationName: _currentLocationName,
      speedKmh: _currentSpeedKmh,
      lifetimeAverageSpeedKmh: _lifetimeAverageSpeedKmh,
      lifetimeSpeedTotal: _lifetimeSpeedTotal,
      lifetimeSpeedSamples: _lifetimeSpeedSamples,
    );
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty) {
        return;
      }
      final place = placemarks.first;
      final locationName = _localityName(place);
      if (mounted) {
        setState(() => _currentLocationName = locationName);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentLocationName = 'Unknown location');
      }
    }
  }

  String _localityName(Placemark place) {
    final localityCandidates = <String?>[
      place.locality,
      place.subLocality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.name,
    ];
    return localityCandidates
        .whereType<String>()
        .map((value) => value.trim())
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => 'Unknown locality',
        );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _currentPosition == null
        ? const LatLng(28.6139, 77.2090)
        : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 13,
              keepAlive: true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.highwaydex',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: const Color(0xFF41D3A8), // Neon Mint
                    strokeWidth: 8, // Thicker, bolder route
                    borderColor: const Color(0xFF003825), // Dark border
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: _currentPosition == null
                    ? const []
                    : [
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 26,
                          height: 26,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.deepOrange,
                            size: 26,
                          ),
                        ),
                      ],
              ),
            ],
          ),
          Positioned(
            top: 56,
            left: 20,
            right: 20,
            child: Material(
              key: TutorialService.driveCurrentLocationKey,
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36), // Extremely rounded
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 24,
                    sigmaY: 24,
                  ), // Stronger blur
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF0F0F0F,
                      ).withValues(alpha: 0.5), // Pure black semi-transparent
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CURRENT LOCATION',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF41D3A8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentLocationName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          key: TutorialService.driveStartStopKey,
                          onPressed: _toggleDriveMode,
                          icon: Icon(
                            _isDriving
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(_isDriving ? 'Stop' : 'Start'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isDriving
                                ? const Color(0xFFFF453A).withValues(alpha: 0.2)
                                : const Color(
                                    0xFF41D3A8,
                                  ).withValues(alpha: 0.2),
                            foregroundColor: _isDriving
                                ? const Color(0xFFFF453A)
                                : const Color(0xFF41D3A8),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _showCurrentLocation,
                          tooltip: 'Show current location',
                          icon: const Icon(Icons.my_location_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 210,
            left: 16,
            right: 16,
            child: Row(
              key: TutorialService.driveMetricsKey,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MetricCard(
                  label: 'LIFETIME AVG',
                  value: _lifetimeAverageSpeedKmh.toStringAsFixed(0),
                  unit: 'km/h',
                  icon: Icons.speed_rounded,
                ),
                _MetricCard(
                  label: 'DISTANCE',
                  value: _distanceKm.toStringAsFixed(1),
                  unit: 'km',
                  icon: Icons.route_rounded,
                ),
                _MetricCard(
                  label: 'STATUS',
                  value: _isDriving ? 'Live' : 'Standby',
                  unit: '',
                  icon: Icons.location_searching_rounded,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            right: 24,
            child: AnimatedContainer(
              key: TutorialService.driveSpeedKey,
              duration: const Duration(milliseconds: 300),
              width: _currentSpeedKmh > 0 ? 96 : 88,
              height: _currentSpeedKmh > 0 ? 96 : 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F0F0F).withValues(alpha: 0.8),
                border: Border.all(
                  color: const Color(
                    0xFF41D3A8,
                  ).withValues(alpha: _currentSpeedKmh > 0 ? 1.0 : 0.2),
                  width: _currentSpeedKmh > 0 ? 4 : 1,
                ),
                boxShadow: _currentSpeedKmh > 0
                    ? [
                        BoxShadow(
                          color: const Color(0xFF41D3A8).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Text(
                          _currentSpeedKmh.toStringAsFixed(0),
                          key: ValueKey<int>(_currentSpeedKmh.round()),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const Text(
                        'km/h',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F).withValues(alpha: 0.5),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF41D3A8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: const Color(0xFF41D3A8)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              unit,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
