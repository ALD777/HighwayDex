import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:highwaydex/services/tutorial_service.dart';

class TravelHistoryScreen extends StatefulWidget {
  const TravelHistoryScreen({super.key});

  @override
  State<TravelHistoryScreen> createState() => _TravelHistoryScreenState();
}

class _TravelHistoryScreenState extends State<TravelHistoryScreen> {
  late Future<List<TravelHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _deleteTrip(TravelHistoryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
          'Are you sure you want to delete this trip? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LocalStorageService.deleteTravelHistoryEntry(entry);
      await LocalStorageService.syncIdentifiedHighwaysFromHistory();
      await _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyFuture = LocalStorageService.loadTravelHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Travel History',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'One journey card is saved for each drive.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadHistory,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                key: TutorialService.travelListKey,
                child: FutureBuilder<List<TravelHistoryEntry>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final entries = snapshot.data ?? <TravelHistoryEntry>[];
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text(
                          'No highway trips saved yet. Start a drive over 2 km.',
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 18,
                        thickness: 1,
                        color: Colors.white12,
                      ),
                      itemBuilder: (context, index) {
                        final trip = entries.reversed.toList()[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TravelDetailScreen(entry: trip),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0F0F0F,
                                  ).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Hero(
                                            tag:
                                                'title-${trip.date.toIso8601String()}',
                                            child: Material(
                                              color: Colors.transparent,
                                              child: Text(
                                                '${trip.fromPlace} to ${trip.toPlace}',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _categoryColor(
                                              trip.category,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            trip.category,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: Colors.white54,
                                          ),
                                          onPressed: () => _deleteTrip(trip),
                                          tooltip: 'Delete Trip',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Date',
                                      value: _formatDate(trip.date),
                                    ),
                                    _InfoRow(
                                      label: 'Distance',
                                      value:
                                          '${trip.distanceKm.toStringAsFixed(1)} km',
                                    ),
                                    _InfoRow(
                                      label: 'From locality',
                                      value: trip.fromPlace,
                                    ),
                                    _InfoRow(
                                      label: 'To locality',
                                      value: trip.toPlace,
                                    ),
                                    _InfoRow(
                                      label: 'Avg speed',
                                      value:
                                          '${trip.averageSpeedKmh.toStringAsFixed(0)} km/h',
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.map_outlined,
                                          size: 16,
                                          color: Color(0xFF9AD9C5),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Open journey map',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Asia':
        return const Color(0xFF7C4DFF).withValues(alpha: 0.18);
      case 'National':
        return const Color(0xFF2E7CF6).withValues(alpha: 0.18);
      case 'State':
        return const Color(0xFF41D3A8).withValues(alpha: 0.18);
      default:
        return const Color(0xFFB39DDB).withValues(alpha: 0.18);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class TravelDetailScreen extends StatefulWidget {
  const TravelDetailScreen({required this.entry, super.key});

  final TravelHistoryEntry entry;

  @override
  State<TravelDetailScreen> createState() => _TravelDetailScreenState();
}

class _TravelDetailScreenState extends State<TravelDetailScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.entry.routePoints.length > 1) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(widget.entry.routePoints),
            padding: const EdgeInsets.all(56),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.entry.routePoints;
    final center = points.isEmpty
        ? const LatLng(28.6139, 77.2090)
        : points.first;
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'title-${widget.entry.date.toIso8601String()}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              '${widget.entry.fromPlace} to ${widget.entry.toPlace}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.highwaydex',
              ),
              if (points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      color: const Color(0xFF41D3A8),
                      strokeWidth: 8,
                      borderColor: const Color(0xFF003825),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (points.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points.first,
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.trip_origin, color: Colors.green),
                    ),
                    if (points.length > 1)
                      Marker(
                        point: points.last,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.deepOrange,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _JourneyMetric(
                        label: 'From locality',
                        value: widget.entry.fromPlace,
                      ),
                      _JourneyMetric(
                        label: 'To locality',
                        value: widget.entry.toPlace,
                      ),
                      _JourneyMetric(
                        label: 'Distance',
                        value:
                            '${widget.entry.distanceKm.toStringAsFixed(1)} km',
                      ),
                      _JourneyMetric(
                        label: 'Avg speed',
                        value:
                            '${widget.entry.averageSpeedKmh.toStringAsFixed(0)} km/h',
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

class _JourneyMetric extends StatelessWidget {
  const _JourneyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
