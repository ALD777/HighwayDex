import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:highwaydex/services/tutorial_service.dart';

class HighwayCollectionScreen extends StatefulWidget {
  const HighwayCollectionScreen({super.key});

  @override
  State<HighwayCollectionScreen> createState() =>
      _HighwayCollectionScreenState();
}

class _HighwayCollectionScreenState extends State<HighwayCollectionScreen> {
  late List<HighwayCardData> _cards;
  final List<String> _collectedCardNames = <String>[];
  final Map<String, double> _collectedKilometers = <String, double>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cards = [
      HighwayCardData(
        name: 'A1',
        label: 'Delhi to Jaipur',
        distanceKm: 240,
        tier: 'Bronze',
        color: Color(0xFFCD7F32),
      ),
      HighwayCardData(
        name: 'Yamuna Ex',
        label: 'Delhi to Agra',
        distanceKm: 165,
        tier: 'Bronze',
        color: Color(0xFFB87333),
      ),
      HighwayCardData(
        name: 'M1',
        label: 'Mumbai Ring',
        distanceKm: 540,
        tier: 'Silver',
        color: Color(0xFFC0C0C0),
      ),
      HighwayCardData(
        name: 'E3',
        label: 'Mumbai–Pune Expressway',
        distanceKm: 94,
        tier: 'Silver',
        color: Color(0xFFB0BEC5),
      ),
      HighwayCardData(
        name: 'NH44',
        label: 'North-South Spine',
        distanceKm: 1380,
        tier: 'Gold',
        color: Color(0xFF4DD0E1),
      ),
      HighwayCardData(
        name: 'GQ',
        label: 'Golden Quadrilateral',
        distanceKm: 584,
        tier: 'Gold',
        color: Color(0xFFFFD700),
      ),
      HighwayCardData(
        name: 'NH48',
        label: 'Bengaluru to Chennai',
        distanceKm: 360,
        tier: 'Gold',
        color: Color(0xFFF7C948),
      ),
      HighwayCardData(
        name: 'Atal',
        label: 'Mumbai Trans Harbour',
        distanceKm: 21,
        tier: 'Bronze',
        color: Color(0xFF7CB342),
      ),
      HighwayCardData(
        name: 'Express 7',
        label: 'Coastal Run',
        distanceKm: 820,
        tier: 'Platinum',
        color: Color(0xFFE5E4E2),
      ),
      HighwayCardData(
        name: 'NH27',
        label: 'East-West Corridor',
        distanceKm: 920,
        tier: 'Gold',
        color: Color(0xFF6A5ACD),
      ),
      HighwayCardData(
        name: 'Rural Loop',
        label: 'Rural Loop',
        distanceKm: 118,
        tier: 'Bronze',
        color: Color(0xFF8D6E63),
      ),
      HighwayCardData(
        name: 'Kashmir',
        label: 'Kashmir Valley Run',
        distanceKm: 310,
        tier: 'Silver',
        color: Color(0xFF90CAF9),
      ),
      HighwayCardData(
        name: 'Coastal',
        label: 'Western Coastline',
        distanceKm: 540,
        tier: 'Silver',
        color: Color(0xFF26A69A),
      ),
      HighwayCardData(
        name: 'Bharat',
        label: 'Bharat Mala',
        distanceKm: 640,
        tier: 'Gold',
        color: Color(0xFFFFB74D),
      ),
      HighwayCardData(
        name: 'Leh',
        label: 'Leh to Manali',
        distanceKm: 475,
        tier: 'Platinum',
        color: Color(0xFFE1BEE7),
      ),
    ];
    _loadProgress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final collectedNames = await LocalStorageService.loadCollectedCards();
    final collectedKilometers =
        await LocalStorageService.loadCollectedKilometers();
    final customHighways = await LocalStorageService.loadCustomHighways();
    final summary = await LocalStorageService.loadDriveSummary();

    if (!mounted) {
      return;
    }

    setState(() {
      _collectedCardNames.clear();
      _collectedCardNames.addAll(collectedNames);
      _collectedKilometers
        ..clear()
        ..addAll(collectedKilometers);
      _cards.addAll(
        customHighways.map(
          (data) => HighwayCardData(
            name: data['name'] as String,
            label: data['label'] as String,
            distanceKm: (data['distance_km'] as num).toInt(),
            tier: data['tier'] as String? ?? 'Bronze',
            color: Color((data['color'] as num?)?.toInt() ?? 0xFF607D8B),
            isCustom: true,
          ),
        ),
      );
      final totalDistance = (summary['distance_km'] as num?)?.toDouble() ?? 0;
      if (totalDistance >= 250 && !_collectedCardNames.contains('A1')) {
        _collectedCardNames.add('A1');
      }
      if (totalDistance >= 500 && !_collectedCardNames.contains('M1')) {
        _collectedCardNames.add('M1');
      }
      if (totalDistance >= 700 && !_collectedCardNames.contains('NH48')) {
        _collectedCardNames.add('NH48');
      }
    });
    await LocalStorageService.saveCollectedCards(_collectedCardNames);
  }

  Future<void> _claimCard(HighwayCardData card) async {
    final kilometers = await showDialog<double>(
      context: context,
      builder: (_) => _ClaimHighwayDialog(
        highwayName: card.name,
        initialKilometers:
            _collectedKilometers[card.name] ?? card.distanceKm.toDouble(),
      ),
    );
    if (!mounted || kilometers == null) return;
    setState(() {
      if (!_collectedCardNames.contains(card.name)) {
        _collectedCardNames.add(card.name);
      }
      _collectedKilometers[card.name] = kilometers;
    });
    await LocalStorageService.saveCollectedCards(_collectedCardNames);
    await LocalStorageService.saveCollectedKilometers(_collectedKilometers);
  }

  Future<void> _resetCard(HighwayCardData card) async {
    setState(() {
      _collectedCardNames.remove(card.name);
      _collectedKilometers.remove(card.name);
    });
    await LocalStorageService.saveCollectedCards(_collectedCardNames);
    await LocalStorageService.saveCollectedKilometers(_collectedKilometers);
  }

  Future<void> _addHighway() async {
    final result = await showDialog<HighwayCardData>(
      context: context,
      builder: (_) => const _AddHighwayDialog(),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() => _cards.add(result.copyWith(isCustom: true)));
    await LocalStorageService.saveCustomHighways(
      _cards
          .where((item) => item.isCustom)
          .map(
            (item) => {
              'name': item.name,
              'label': item.label,
              'distance_km': item.distanceKm,
              'tier': item.tier,
              'color': item.color.toARGB32(),
            },
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _loadSummarySnapshot();
    final totalRoute = summary['total_route'];
    final driven = summary['driven'];
    final tier = summary['tier'];
    final visibleCards = _cards.where((card) {
      final query = _searchQuery.toLowerCase();
      return query.isEmpty ||
          card.name.toLowerCase().contains(query) ||
          card.label.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
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
                          'Your routes',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track, claim, and revisit every journey.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26332F),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: const Color(0xFFFFB86B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _StatPill(label: 'Total route', value: '$totalRoute km'),
                  const SizedBox(width: 12),
                  _StatPill(label: 'Driven', value: '$driven km'),
                  const SizedBox(width: 12),
                  _StatPill(label: 'Tier', value: tier),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: TutorialService.collectionSearchKey,
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search highways or roads',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    key: TutorialService.collectionChipsKey,
                    onPressed: _addHighway,
                    tooltip: 'Add highway manually',
                    icon: const Icon(Icons.add_road_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: visibleCards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.60,
                  ),
                  itemBuilder: (context, index) {
                    final card = visibleCards[index];
                    final isCollected = _collectedCardNames.contains(card.name);
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(
                        milliseconds: 300 + (index * 50).clamp(0, 500),
                      ),
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: GestureDetector(
                        onTap: () => _claimCard(card),
                        child: _HighwayCardTile(
                          card: card,
                          isCollected: isCollected,
                          claimedKm: _collectedKilometers[card.name],
                          onReset: () => _resetCard(card),
                        ),
                      ),
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

  Map<String, dynamic> _loadSummarySnapshot() {
    final totalDistance = _cards.fold<int>(
      0,
      (sum, card) => sum + card.distanceKm,
    );
    final drivenDistance = _collectedKilometers.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    final tier = drivenDistance >= 1100
        ? 'Platinum'
        : drivenDistance >= 650
        ? 'Gold'
        : drivenDistance >= 300
        ? 'Silver'
        : 'Bronze';

    return {
      'total_route': totalDistance,
      'driven': drivenDistance.toStringAsFixed(1),
      'tier': tier,
    };
  }
}

class HighwayCardData {
  const HighwayCardData({
    required this.name,
    required this.label,
    required this.distanceKm,
    required this.tier,
    required this.color,
    this.isCustom = false,
  });

  final String name;
  final String label;
  final int distanceKm;
  final String tier;
  final Color color;
  final bool isCustom;

  HighwayCardData copyWith({bool? isCustom}) => HighwayCardData(
    name: name,
    label: label,
    distanceKm: distanceKm,
    tier: tier,
    color: color,
    isCustom: isCustom ?? this.isCustom,
  );
}

class _ClaimHighwayDialog extends StatefulWidget {
  const _ClaimHighwayDialog({
    required this.highwayName,
    required this.initialKilometers,
  });

  final String highwayName;
  final double initialKilometers;

  @override
  State<_ClaimHighwayDialog> createState() => _ClaimHighwayDialogState();
}

class _ClaimHighwayDialogState extends State<_ClaimHighwayDialog> {
  late final TextEditingController _kilometersController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _kilometersController = TextEditingController(
      text: widget.initialKilometers.toString(),
    );
  }

  @override
  void dispose() {
    _kilometersController.dispose();
    super.dispose();
  }

  void _submit() {
    final kilometers = double.tryParse(_kilometersController.text.trim());
    if (kilometers == null || kilometers < 0) {
      setState(() => _errorText = 'Enter a valid kilometer value.');
      return;
    }
    Navigator.of(context).pop(kilometers);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Claim ${widget.highwayName}'),
      content: TextField(
        controller: _kilometersController,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Kilometers driven',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save claim')),
      ],
    );
  }
}

class _AddHighwayDialog extends StatefulWidget {
  const _AddHighwayDialog();

  @override
  State<_AddHighwayDialog> createState() => _AddHighwayDialogState();
}

class _AddHighwayDialogState extends State<_AddHighwayDialog> {
  final _nameController = TextEditingController();
  final _routeController = TextEditingController();
  final _lengthController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _routeController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final route = _routeController.text.trim();
    final length = int.tryParse(_lengthController.text.trim());
    if (name.isEmpty || length == null || length <= 0) {
      return;
    }
    Navigator.of(context).pop(
      HighwayCardData(
        name: name,
        label: route.isEmpty ? name : route,
        distanceKm: length,
        tier: 'Bronze',
        color: const Color(0xFF607D8B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add highway manually'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Highway name'),
          ),
          TextField(
            controller: _routeController,
            decoration: const InputDecoration(labelText: 'Road or route name'),
          ),
          TextField(
            controller: _lengthController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total kilometers'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighwayCardTile extends StatelessWidget {
  const _HighwayCardTile({
    required this.card,
    required this.isCollected,
    required this.onReset,
    this.claimedKm,
  });

  final HighwayCardData card;
  final bool isCollected;
  final VoidCallback onReset;
  final double? claimedKm;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: isCollected
            ? [
                BoxShadow(
                  color: card.color.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isCollected
                    ? card.color
                    : Colors.white.withValues(alpha: 0.05),
                width: isCollected ? 2.0 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.tier,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onReset,
                        tooltip: 'Reset highway status',
                        icon: const Icon(Icons.restart_alt_rounded),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                      ),
                      Icon(
                        isCollected
                            ? Icons.verified_rounded
                            : Icons.pending_rounded,
                        color: isCollected
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      card.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    card.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.route_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${claimedKm?.toStringAsFixed(1) ?? card.distanceKm} km',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCollected
                          ? card.color.withValues(alpha: 0.15)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isCollected ? 'Collected' : 'Available',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isCollected ? card.color : Colors.white54,
                      ),
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
