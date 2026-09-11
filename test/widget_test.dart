// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highwaydex/services/google_maps_highway_service.dart';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:highwaydex/screens/highway_history_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:highwaydex/screens/highway_collection_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Malformed history values are sanitized', () {
    final entry = TravelHistoryEntry.fromJson({
      'date': '2026-01-01T00:00:00Z',
      'highway_name': 'NH27',
      'distance_km': double.nan,
      'average_speed_kmh': double.infinity,
      'route_points': [
        {'lat': double.nan, 'lng': double.infinity},
      ],
    });

    expect(entry.distanceKm, 0);
    expect(entry.averageSpeedKmh, 0);
    expect(entry.routePoints, isEmpty);
  });

  test(
    'Stored route values accept integers and reject invalid coordinates',
    () {
      final entry = TravelHistoryEntry.fromJson({
        'route_points': [
          {'lat': 28, 'lng': 77},
          {'lat': 200, 'lng': 77},
          {'lat': 28, 'lng': -181},
        ],
      });

      expect(entry.routePoints, [const LatLng(28, 77)]);
    },
  );

  test(
    'Google Maps analysis fails closed when the request cannot complete',
    () async {
      final result = await GoogleMapsHighwayService.analyzeRoute(
        routePoints: [const LatLng(28.6139, 77.2090)],
        start: 'Delhi',
        end: 'Noida',
      );

      expect(result.status, 'request_error');
      expect(result.nationalHighways, isEmpty);
      expect(result.stateHighways, isEmpty);
    },
  );

  test('Historical highway analysis can update an existing trip', () async {
    final original = TravelHistoryEntry(
      date: DateTime.utc(2026, 1, 1),
      highwayName: 'Journey',
      category: 'Trip',
      distanceKm: 42,
      averageSpeedKmh: 45,
      routePoints: [const LatLng(28.6, 77.2)],
    );
    await LocalStorageService.saveTravelHistory([original]);
    await LocalStorageService.updateTravelHistoryEntry(
      original,
      original.copyWith(
        nationalHighways: ['NH44 - Test Highway'],
        highwayAnalysisStatus: 'completed',
      ),
    );

    final saved = await LocalStorageService.loadTravelHistory();
    expect(saved.single.nationalHighways, ['NH44 - Test Highway']);
    expect(saved.single.highwayAnalysisStatus, 'completed');
  });

  testWidgets('Legacy trips expose the historical analysis action', (
    WidgetTester tester,
  ) async {
    await LocalStorageService.saveTravelHistory([
      TravelHistoryEntry(
        date: DateTime.utc(2026, 1, 1),
        highwayName: 'Journey',
        category: 'Trip',
        distanceKm: 42,
        averageSpeedKmh: 45,
        routePoints: [const LatLng(28.6, 77.2)],
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: HighwayHistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Analyze past trips'), findsOneWidget);
    expect(find.text('Analyze this trip'), findsOneWidget);
  });

  testWidgets('Completed analysis exposes both result categories', (
    WidgetTester tester,
  ) async {
    await LocalStorageService.saveTravelHistory([
      TravelHistoryEntry(
        date: DateTime.utc(2026, 1, 2),
        highwayName: 'Journey',
        category: 'Trip',
        distanceKm: 42,
        averageSpeedKmh: 45,
        routePoints: [const LatLng(28.6, 77.2)],
        nationalHighways: ['NH44 - Test Highway'],
        highwayAnalysisStatus: 'completed',
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: HighwayHistoryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View analysis result'));
    await tester.pumpAndSettle();

    expect(find.text('Highway analysis'), findsOneWidget);
    expect(find.text('National highways'), findsOneWidget);
    expect(find.text('State highways'), findsOneWidget);
    expect(find.text('NH44 - Test Highway'), findsAtLeastNWidgets(1));
    expect(
      find.text('No highway was confidently identified for this route.'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('Highway collection screen renders the deck header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HighwayCollectionScreen()));

    expect(find.text('Your routes'), findsOneWidget);
    expect(
      find.text('Track, claim, and revisit every journey.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Collection deck includes a wider mix of popular and normal highways',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HighwayCollectionScreen()),
      );
      await tester.pumpAndSettle();

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate = grid.childrenDelegate as SliverChildBuilderDelegate;

      expect(delegate.estimatedChildCount, greaterThan(4));
    },
  );

  testWidgets('Manual highway is added to the collection deck', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HighwayCollectionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add highway manually'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'NH999');
    await tester.enterText(fields.at(2), 'Test Road');
    await tester.enterText(fields.at(3), '120');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'NH999');
    await tester.pumpAndSettle();
    expect(find.text('NH999'), findsAtLeastNWidgets(1));
    expect(find.text('Test Road'), findsOneWidget);
  });

  testWidgets('Claiming a highway saves kilometers without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HighwayCollectionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A1').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '42.5');
    await tester.tap(find.text('Save claim'));
    await tester.pumpAndSettle();

    expect(find.text('Collected'), findsOneWidget);
    expect(find.text('42.5 km'), findsAtLeastNWidgets(1));
  });

  testWidgets('Resetting a highway card clears its claimed status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HighwayCollectionScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A1').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '42.5');
    await tester.tap(find.text('Save claim'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reset highway status').first);
    await tester.pumpAndSettle();

    expect(find.text('Available'), findsAtLeastNWidgets(1));
    expect(find.text('240 km'), findsOneWidget);
  });
}
