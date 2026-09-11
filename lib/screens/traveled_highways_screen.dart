import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:highwaydex/services/google_maps_highway_service.dart';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:highwaydex/services/tutorial_service.dart';

class TraveledHighwaysScreen extends StatefulWidget {
  const TraveledHighwaysScreen({super.key});

  @override
  State<TraveledHighwaysScreen> createState() => _TraveledHighwaysScreenState();
}

enum _HighwayFilter { all, asian, national, state }

enum _HighwaySortOption { ascending, descending, latestTraveled, mostTrips }

extension _HighwaySortOptionExtension on _HighwaySortOption {
  String get label {
    switch (this) {
      case _HighwaySortOption.ascending:
        return 'Ascending';
      case _HighwaySortOption.descending:
        return 'Descending';
      case _HighwaySortOption.latestTraveled:
        return 'Latest Traveled';
      case _HighwaySortOption.mostTrips:
        return 'Most Trips';
    }
  }
}

class _TraveledHighwaysScreenState extends State<TraveledHighwaysScreen> {
  late Future<List<IdentifiedHighway>> _highwaysFuture;
  final TextEditingController _searchController = TextEditingController();
  _HighwayFilter _selectedFilter = _HighwayFilter.all;
  _HighwaySortOption _selectedSort = _HighwaySortOption.ascending;
  String _searchQuery = '';
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _highwaysFuture = LocalStorageService.loadIdentifiedHighways();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _highwaysFuture = LocalStorageService.loadIdentifiedHighways();
    });
  }

  Future<void> _syncFromTrips() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final updated =
          await LocalStorageService.syncIdentifiedHighwaysFromHistory();
      if (!mounted) return;
      setState(() {
        _highwaysFuture = Future.value(updated);
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synchronized ${updated.length} unique state/national highway(s).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not synchronize highways.')),
      );
    }
  }

  void _showHighwayDetail(IdentifiedHighway highway) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: highway.category == 'national'
                    ? const Color(0xFF41D3A8).withValues(alpha: 0.2)
                    : const Color(0xFFFFB86B).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                highway.code,
                style: TextStyle(
                  color: highway.category == 'national'
                      ? const Color(0xFF41D3A8)
                      : const Color(0xFFFFB86B),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                highway.category == 'national'
                    ? 'National Highway'
                    : highway.category == 'asian'
                    ? 'Asian Highway'
                    : 'State Highway',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                highway.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _DetailRow(label: 'Highway Code', value: highway.code),
              _DetailRow(
                label: 'Highway Number',
                value: '${highway.number}${highway.suffix}',
              ),
              _DetailRow(
                label: 'Category',
                value: highway.category == 'national'
                    ? 'National Highway (NH)'
                    : highway.category == 'asian'
                    ? 'Asian Highway (AH)'
                    : 'State Highway (SH)',
              ),
              _DetailRow(
                label: 'Times Traveled',
                value: '${highway.tripCount} trip(s)',
              ),
              if (highway.lastTraveledDate != null)
                _DetailRow(
                  label: 'Last Recorded',
                  value: _formatDate(highway.lastTraveledDate!),
                ),
              if (highway.tripRoutes.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Associated Trip Routes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                ...highway.tripRoutes.map(
                  (route) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.route_rounded,
                            size: 14,
                            color: Color(0xFF41D3A8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            route,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year';
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
                          'Traveled Highways',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'State, National and Asian Highways',
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
                    onPressed: _isSyncing ? null : _syncFromTrips,
                    tooltip: 'Sync with completed trips',
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search input
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search highway (e.g. NH5, NH55, NH149, SH10)',
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              // FutureBuilder to load the deduplicated ascending list
              Expanded(
                key: TutorialService.directoryListKey,
                child: FutureBuilder<List<IdentifiedHighway>>(
                  future: _highwaysFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allHighways = snapshot.data ?? <IdentifiedHighway>[];

                    // Strict filter: only national or state highways
                    final filteredHighways = allHighways.where((h) {
                      final isNational = h.category == 'national';
                      final isState = h.category == 'state';
                      final isAsian = h.category == 'asian';
                      if (!isNational && !isState && !isAsian) return false;

                      if (_selectedFilter == _HighwayFilter.national &&
                          !isNational) {
                        return false;
                      }
                      if (_selectedFilter == _HighwayFilter.state && !isState) {
                        return false;
                      }
                      if (_selectedFilter == _HighwayFilter.asian && !isAsian) {
                        return false;
                      }

                      if (_searchQuery.trim().isEmpty) return true;
                      final query = _searchQuery.trim().toLowerCase();
                      return h.code.toLowerCase().contains(query) ||
                          h.name.toLowerCase().contains(query) ||
                          h.number.toString().contains(query) ||
                          h.tripRoutes.any(
                            (r) => r.toLowerCase().contains(query),
                          );
                    }).toList();

                    // Dynamic sort
                    filteredHighways.sort((a, b) {
                      switch (_selectedSort) {
                        case _HighwaySortOption.ascending:
                          return IdentifiedHighway.compareAscending(a, b);
                        case _HighwaySortOption.descending:
                          return IdentifiedHighway.compareAscending(b, a);
                        case _HighwaySortOption.latestTraveled:
                          final aDate = a.lastTraveledDate;
                          final bDate = b.lastTraveledDate;
                          if (aDate == null && bDate == null)
                            return IdentifiedHighway.compareAscending(a, b);
                          if (aDate == null) return 1;
                          if (bDate == null) return -1;
                          return bDate.compareTo(aDate);
                        case _HighwaySortOption.mostTrips:
                          final countCmp = b.tripCount.compareTo(a.tripCount);
                          if (countCmp != 0) return countCmp;
                          return IdentifiedHighway.compareAscending(a, b);
                      }
                    });

                    final nationalCount = allHighways
                        .where((h) => h.category == 'national')
                        .length;
                    final stateCount = allHighways
                        .where((h) => h.category == 'state')
                        .length;
                    final asianCount = allHighways
                        .where((h) => h.category == 'asian')
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterPill(
                                label: 'All (${allHighways.length})',
                                isSelected:
                                    _selectedFilter == _HighwayFilter.all,
                                onTap: () => setState(
                                  () => _selectedFilter = _HighwayFilter.all,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Asian ($asianCount)',
                                color: const Color(0xFF6B8AFF),
                                isSelected:
                                    _selectedFilter == _HighwayFilter.asian,
                                onTap: () => setState(
                                  () => _selectedFilter = _HighwayFilter.asian,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'National ($nationalCount)',
                                color: const Color(0xFF41D3A8),
                                isSelected:
                                    _selectedFilter == _HighwayFilter.national,
                                onTap: () => setState(
                                  () =>
                                      _selectedFilter = _HighwayFilter.national,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'State ($stateCount)',
                                color: const Color(0xFFFFB86B),
                                isSelected:
                                    _selectedFilter == _HighwayFilter.state,
                                onTap: () => setState(
                                  () => _selectedFilter = _HighwayFilter.state,
                                ),
                              ),
                              const SizedBox(width: 12),
                              PopupMenuButton<_HighwaySortOption>(
                                initialValue: _selectedSort,
                                color: const Color(0xFF1E1E1E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (option) =>
                                    setState(() => _selectedSort = option),
                                itemBuilder: (context) =>
                                    _HighwaySortOption.values.map((option) {
                                      return PopupMenuItem(
                                        value: option,
                                        child: Text(
                                          option.label,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF0F0F0F,
                                    ).withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.sort_rounded,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _selectedSort.label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (allHighways.isEmpty)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF0F0F0F,
                                        ).withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(
                                            0xFF41D3A8,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.alt_route_rounded,
                                        size: 40,
                                        color: Color(0xFF41D3A8),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No State or National Highways yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Highways will appear here in ascending order once you log drives or analyze past trips using Google Maps.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      onPressed: _syncFromTrips,
                                      icon: const Icon(Icons.sync_rounded),
                                      label: const Text('Sync from History'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (filteredHighways.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text(
                                'No highways match the current filter or search.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: filteredHighways.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final highway = filteredHighways[index];
                                return _HighwayListCard(
                                  index: index + 1,
                                  highway: highway,
                                  onTap: () => _showHighwayDetail(highway),
                                );
                              },
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFF9AD9C5);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.22)
              : const Color(0xFF0F0F0F).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? effectiveColor
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? effectiveColor : Colors.white70,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _HighwayListCard extends StatelessWidget {
  const _HighwayListCard({
    required this.index,
    required this.highway,
    required this.onTap,
  });

  final int index;
  final IdentifiedHighway highway;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNational = highway.category == 'national';
    final isAsian = highway.category == 'asian';
    final accentColor = isNational
        ? const Color(0xFF41D3A8)
        : isAsian
        ? const Color(0xFF6B8AFF)
        : const Color(0xFFFFB86B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.24),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Order index
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    '#$index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white38,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Highway Code Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alt_route_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        highway.code,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Highway Name and Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        highway.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isNational ? 'National' : 'State',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${highway.tripCount} trip(s)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
