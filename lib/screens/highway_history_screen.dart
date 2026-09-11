import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:highwaydex/screens/traveled_highways_screen.dart';
import 'package:highwaydex/screens/settings_screen.dart';
import 'package:highwaydex/services/google_maps_highway_service.dart';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:highwaydex/services/tutorial_service.dart';

class HighwayHistoryScreen extends StatefulWidget {
  const HighwayHistoryScreen({super.key});

  @override
  State<HighwayHistoryScreen> createState() => _HighwayHistoryScreenState();
}

class _HighwayHistoryScreenState extends State<HighwayHistoryScreen> {
  late Future<List<TravelHistoryEntry>> _historyFuture;
  final Set<String> _analyzingEntries = <String>{};
  bool _isAnalyzingPastTrips = false;
  bool _stopAnalysis = false;
  int _analysisProgress = 0;
  int _analysisTotal = 0;

  @override
  void initState() {
    super.initState();
    _historyFuture = LocalStorageService.loadTravelHistory();
  }

  void _refresh() {
    setState(() {
      _historyFuture = LocalStorageService.loadTravelHistory();
    });
  }

  String _entryKey(TravelHistoryEntry entry) =>
      '${entry.date.toIso8601String()}|${entry.fromPlace}|${entry.toPlace}';

  bool _canAnalyze(TravelHistoryEntry entry) => entry.routePoints.isNotEmpty;

  Future<void> _analyzeEntry(
    TravelHistoryEntry entry, {
    bool showResult = true,
  }) async {
    final key = _entryKey(entry);
    if (_analyzingEntries.contains(key) || !_canAnalyze(entry)) return;
    setState(() => _analyzingEntries.add(key));
    try {
      final analysis = await GoogleMapsHighwayService.analyzeRoute(
        routePoints: entry.routePoints,
        start: entry.fromPlace,
        end: entry.toPlace,
        tripDate: entry.date,
      );
      await LocalStorageService.updateTravelHistoryEntry(
        entry,
        entry.copyWith(
          nationalHighways: analysis.nationalHighways,
          stateHighways: analysis.stateHighways,
          highwayAnalysisStatus: analysis.status,
          analysisMessage: analysis.message,
        ),
      );
      await LocalStorageService.syncIdentifiedHighwaysFromHistory();
      if (mounted && showResult) {
        _showAnalysisDialog(entry, analysis);
      }
    } catch (e) {
      if (mounted) _showMessage('Could not save this highway analysis: $e');
      try {
        await LocalStorageService.updateTravelHistoryEntry(
          entry,
          entry.copyWith(
            highwayAnalysisStatus: 'failed',
            analysisMessage: 'Highway analysis could not be saved: $e',
          ),
        );
        await LocalStorageService.syncIdentifiedHighwaysFromHistory();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _analyzingEntries.remove(key);
          _historyFuture = LocalStorageService.loadTravelHistory();
        });
      }
    }
  }

  Future<void> _analyzePastTrips(List<TravelHistoryEntry> entries) async {
    if (_isAnalyzingPastTrips) {
      setState(() => _stopAnalysis = true);
      return;
    }
    final eligibleEntries = entries
        .where((e) => _canAnalyze(e) && e.highwayAnalysisStatus != 'completed')
        .toList();
    if (eligibleEntries.isEmpty) {
      _showMessage('No historical trips with route points need analysis.');
      return;
    }
    setState(() {
      _isAnalyzingPastTrips = true;
      _stopAnalysis = false;
      _analysisProgress = 0;
      _analysisTotal = eligibleEntries.length;
    });
    for (var index = 0; index < eligibleEntries.length; index++) {
      if (_stopAnalysis) break;
      final entry = eligibleEntries[index];
      await _analyzeEntry(entry, showResult: false);
      if (mounted) setState(() => _analysisProgress = index + 1);
    }
    if (!mounted) return;

    final wasStopped = _stopAnalysis;
    setState(() {
      _isAnalyzingPastTrips = false;
      _stopAnalysis = false;
    });

    if (wasStopped) {
      _showMessage(
        'Analysis stopped at $_analysisProgress/$_analysisTotal trips.',
      );
    } else {
      _showMessage('Historical highway analysis complete.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAnalysisDialog(TravelHistoryEntry entry, HighwayAnalysis analysis) {
    if (!mounted) return;
    final nationalHighways = _HighwayUtils._orderedUnique(
      analysis.nationalHighways,
    );
    final stateHighways = _HighwayUtils._orderedUnique(analysis.stateHighways);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${entry.fromPlace} to ${entry.toPlace}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                analysis.message ?? 'Analysis status: ${analysis.status}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              const Text(
                'National highways',
                style: TextStyle(
                  color: Color(0xFF9AD9C5),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _AnalysisValues(values: nationalHighways),
              const SizedBox(height: 18),
              const Text(
                'State highways',
                style: TextStyle(
                  color: Color(0xFFFFB86B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _AnalysisValues(values: stateHighways),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Highway History',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'AI-identified highways from completed trips',
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
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    tooltip: 'Settings & Cloud Sync',
                    icon: const Icon(Icons.cloud_sync_rounded),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!GoogleMapsHighwayService.isConfigured) ...[
                _GoogleMapsConfigurationNotice(onRefresh: _refresh),
                const SizedBox(height: 16),
              ],
              Expanded(
                key: TutorialService.historyListKey,
                child: FutureBuilder<List<TravelHistoryEntry>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allEntries = snapshot.data ?? <TravelHistoryEntry>[];
                    final entries = allEntries.reversed.toList();
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text(
                          'Highway results will appear after your first trip.',
                        ),
                      );
                    }
                    return ListView(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TraveledHighwaysScreen(),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0F0F0F,
                                  ).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.signpost_rounded,
                                      color: Color(0xFF41D3A8),
                                      size: 28,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Traveled Highways Directory',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: Color(0xFF41D3A8),
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'View unique NH & SH listed in ascending order',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: Colors.white30,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _isAnalyzingPastTrips && !_stopAnalysis
                              ? () => setState(() => _stopAnalysis = true)
                              : (_isAnalyzingPastTrips
                                    ? null
                                    : () => _analyzePastTrips(allEntries)),
                          icon: _isAnalyzingPastTrips
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            _isAnalyzingPastTrips
                                ? (_stopAnalysis
                                      ? 'Stopping...'
                                      : 'Stop analysis ($_analysisProgress/$_analysisTotal)')
                                : 'Analyze past trips',
                          ),
                          style: _isAnalyzingPastTrips && !_stopAnalysis
                              ? FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(
                                    alpha: 0.8,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        ...entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _HighwayTripCard(
                              entry: entry,
                              isAnalyzing: _analyzingEntries.contains(
                                _entryKey(entry),
                              ),
                              onAnalyze: _canAnalyze(entry)
                                  ? () => _analyzeEntry(entry)
                                  : null,
                              onStopAnalyze:
                                  _analyzingEntries.contains(
                                        _entryKey(entry),
                                      ) ||
                                      entry.highwayAnalysisStatus == 'pending'
                                  ? () async {
                                      final key = _entryKey(entry);
                                      setState(() {
                                        _analyzingEntries.remove(key);
                                      });
                                      await LocalStorageService.updateTravelHistoryEntry(
                                        entry,
                                        entry.copyWith(
                                          highwayAnalysisStatus:
                                              'not_requested',
                                          analysisMessage:
                                              'Analysis stopped manually',
                                        ),
                                      );
                                      _refresh();
                                    }
                                  : null,
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Trip'),
                                    content: const Text(
                                      'Are you sure you want to delete this trip? This action cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await LocalStorageService.deleteTravelHistoryEntry(
                                    entry,
                                  );
                                  await LocalStorageService.syncIdentifiedHighwaysFromHistory();
                                  setState(() {
                                    _historyFuture =
                                        LocalStorageService.loadTravelHistory();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
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
}

class _HighwayTripCard extends StatelessWidget {
  const _HighwayTripCard({
    required this.entry,
    required this.isAnalyzing,
    required this.onAnalyze,
    required this.onStopAnalyze,
    required this.onDelete,
  });

  final TravelHistoryEntry entry;
  final bool isAnalyzing;
  final VoidCallback? onAnalyze;
  final VoidCallback? onStopAnalyze;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final nationalHighways = _HighwayUtils._orderedUnique(
      entry.nationalHighways,
    );
    final stateHighways = _HighwayUtils._orderedUnique(entry.stateHighways);
    final asianHighways = _HighwayUtils._orderedUnique(entry.asianHighways);
    final allHighways = [
      ...nationalHighways,
      ...stateHighways,
      ...asianHighways,
    ];
    final statusText = switch (entry.highwayAnalysisStatus) {
      'completed' =>
        allHighways.isEmpty
            ? 'No highways confidently identified'
            : '${allHighways.length} highways identified',
      'not_configured' => 'Google Maps is not enabled for this run',
      'no_route' => 'No saved route points for this trip',
      'timeout' => 'Google Maps timed out. Try again.',
      'unauthorized' => 'Google Maps rejected the API key',
      'rate_limited' => 'Google Maps rate limit reached',
      'service_error' => 'Google Maps is temporarily unavailable',
      'network_error' => 'Could not reach Google Maps',
      'invalid_response' => 'Google Maps returned an invalid result',
      'request_error' => 'Google Maps could not analyze this trip',
      'failed' => 'Analysis failed. Trip was still saved.',
      'pending' => 'Highway analysis in progress',
      _ => 'Analysis not requested',
    };
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.fromPlace} to ${entry.toPlace}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Delete Trip',
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${entry.distanceKm.toStringAsFixed(1)} km  |  $statusText',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (entry.analysisMessage != null &&
                    entry.analysisMessage!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.analysisMessage!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                if (entry.highwayAnalysisStatus == 'completed') ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _showAnalysisResult(context),
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('View analysis result'),
                  ),
                ],
                if (onAnalyze != null || onStopAnalyze != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onStopAnalyze != null)
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: onStopAnalyze,
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              'Stop',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (onStopAnalyze != null && onAnalyze != null)
                        const SizedBox(width: 8),
                      if (onAnalyze != null)
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: isAnalyzing ? null : onAnalyze,
                            icon: isAnalyzing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              isAnalyzing
                                  ? 'Analyzing...'
                                  : (entry.highwayAnalysisStatus ==
                                                'completed' ||
                                            entry.highwayAnalysisStatus ==
                                                'failed'
                                        ? 'Force Re-analyze'
                                        : 'Analyze this trip'),
                              textAlign: TextAlign.center,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF41D3A8)),
                              foregroundColor: const Color(0xFF41D3A8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnalysisResult(BuildContext context) {
    final nationalHighways = _HighwayUtils._sortedUnique(
      entry.nationalHighways,
    );
    final stateHighways = _HighwayUtils._sortedUnique(entry.stateHighways);
    final asianHighways = _HighwayUtils._sortedUnique(entry.asianHighways);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Highway analysis'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Asian highways',
                style: TextStyle(
                  color: Color(0xFF6B8AFF),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _AnalysisValues(values: asianHighways),
              const SizedBox(height: 18),
              const Text(
                'National highways',
                style: TextStyle(
                  color: Color(0xFF41D3A8),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _AnalysisValues(values: nationalHighways),
              const SizedBox(height: 18),
              const Text(
                'State highways',
                style: TextStyle(
                  color: Color(0xFFFFB86B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _AnalysisValues(values: stateHighways),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GoogleMapsConfigurationNotice extends StatelessWidget {
  const _GoogleMapsConfigurationNotice({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB86B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFB86B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB86B)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Google Maps highway analysis is disabled for this run. Saved highway results remain available. Start the app with --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY.',
              style: TextStyle(height: 1.35),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Check configuration again',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _AnalysisValues extends StatelessWidget {
  const _AnalysisValues({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Text(
        'No highway was confidently identified for this route.',
        style: TextStyle(color: Colors.white70),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values
          .map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.alt_route_rounded, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HighwayUtils {
  static List<String> _sortedUnique(Iterable<String> highways) {
    final unique = <String, String>{};
    for (final highway in highways) {
      final cleaned = highway.trim();
      if (cleaned.isNotEmpty) unique[cleaned.toLowerCase()] = cleaned;
    }
    final result = unique.values.toList();
    result.sort((left, right) {
      final leftNumber = _number(left);
      final rightNumber = _number(right);
      if (leftNumber != null &&
          rightNumber != null &&
          leftNumber != rightNumber) {
        return leftNumber.compareTo(rightNumber);
      }
      if (leftNumber != null && rightNumber == null) return -1;
      if (leftNumber == null && rightNumber != null) return 1;
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    return result;
  }

  static List<String> _orderedUnique(Iterable<String> highways) {
    final unique = <String, String>{};
    for (final highway in highways) {
      final cleaned = highway.trim();
      if (cleaned.isNotEmpty) {
        unique.putIfAbsent(cleaned.toLowerCase(), () => cleaned);
      }
    }
    return unique.values.toList();
  }

  static int? _number(String highway) {
    final match = RegExp(r'\d+').firstMatch(highway);
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}
