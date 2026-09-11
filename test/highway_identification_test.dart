import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highwaydex/screens/traveled_highways_screen.dart';
import 'package:highwaydex/services/google_maps_highway_service.dart';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HighwayParser - National Highway Identification', () {
    test('Identifies NH5 correctly', () {
      final highway = HighwayParser.parse(primary: 'NH5');
      expect(highway, isNotNull);
      expect(highway!.code, 'NH5');
      expect(highway.number, 5);
      expect(highway.category, 'national');
    });

    test('Identifies NH55 with spacing and full name', () {
      final highway = HighwayParser.parse(
        primary: 'NH 55',
        secondary: 'Cuttack - Sambalpur Road',
      );
      expect(highway, isNotNull);
      expect(highway!.code, 'NH55');
      expect(highway.number, 55);
      expect(highway.category, 'national');
      expect(highway.name, contains('National Highway 55'));
    });

    test('Identifies NH149 correctly', () {
      final highway = HighwayParser.parse(
        primary: 'NH149',
        context: 'Pallahara, Odisha, India',
      );
      expect(highway, isNotNull);
      expect(highway!.code, 'NH149');
      expect(highway.number, 149);
      expect(highway.category, 'national');
    });

    test('Identifies National Highway from spelled out text', () {
      final highway = HighwayParser.parse(primary: 'National Highway 44');
      expect(highway, isNotNull);
      expect(highway!.code, 'NH44');
      expect(highway.number, 44);
      expect(highway.category, 'national');
    });

    test('Identifies NH with hyphen and suffix like NH-149A', () {
      final highway = HighwayParser.parse(primary: 'NH-149A');
      expect(highway, isNotNull);
      expect(highway!.code, 'NH149A');
      expect(highway.number, 149);
      expect(highway.suffix, 'A');
    });
  });

  group('HighwayParser - State Highway Identification', () {
    test('Identifies SH10 correctly', () {
      final highway = HighwayParser.parse(primary: 'SH10');
      expect(highway, isNotNull);
      expect(highway!.code, 'SH10');
      expect(highway.number, 10);
      expect(highway.category, 'state');
    });

    test('Identifies SH with state prefix e.g. OD SH 6', () {
      final highway = HighwayParser.parse(primary: 'OD SH 6');
      expect(highway, isNotNull);
      expect(highway!.code, 'OD SH6');
      expect(highway.number, 6);
      expect(highway.category, 'state');
    });

    test('Identifies State Highway from spelled out text', () {
      final highway = HighwayParser.parse(primary: 'State Highway 55');
      expect(highway, isNotNull);
      expect(highway!.code, 'SH55');
      expect(highway.number, 55);
      expect(highway.category, 'state');
    });
  });

  group('HighwayParser - Strict Exclusion of Non-Highways', () {
    test('Rejects local streets and municipal roads', () {
      expect(HighwayParser.parse(primary: 'MG Road'), isNull);
      expect(HighwayParser.parse(primary: 'Main Street'), isNull);
      expect(HighwayParser.parse(primary: 'Outer Ring Road'), isNull);
      expect(HighwayParser.parse(primary: 'Service Road'), isNull);
      expect(HighwayParser.parse(primary: 'MDR 14'), isNull);
      expect(HighwayParser.parse(primary: 'Rural Loop'), isNull);
    });
  });

  group('Ascending Order Sorting', () {
    test('Sorts National Highways in natural numeric ascending order', () {
      final list = [
        const IdentifiedHighway(
          code: 'NH149',
          name: 'National Highway 149',
          category: 'national',
          number: 149,
        ),
        const IdentifiedHighway(
          code: 'NH5',
          name: 'National Highway 5',
          category: 'national',
          number: 5,
        ),
        const IdentifiedHighway(
          code: 'NH55',
          name: 'National Highway 55',
          category: 'national',
          number: 55,
        ),
        const IdentifiedHighway(
          code: 'NH16',
          name: 'National Highway 16',
          category: 'national',
          number: 16,
        ),
      ];

      list.sort(IdentifiedHighway.compareAscending);

      expect(list.map((h) => h.code).toList(), [
        'NH5',
        'NH16',
        'NH55',
        'NH149',
      ]);
    });

    test('Sorts State Highways in numeric ascending order', () {
      final list = [
        const IdentifiedHighway(
          code: 'SH55',
          name: 'State Highway 55',
          category: 'state',
          number: 55,
        ),
        const IdentifiedHighway(
          code: 'SH2',
          name: 'State Highway 2',
          category: 'state',
          number: 2,
        ),
        const IdentifiedHighway(
          code: 'SH10',
          name: 'State Highway 10',
          category: 'state',
          number: 10,
        ),
      ];

      list.sort(IdentifiedHighway.compareAscending);

      expect(list.map((h) => h.code).toList(), ['SH2', 'SH10', 'SH55']);
    });
  });

  group('Deduplication & LocalStorage Synchronization', () {
    test(
      'Deduplicates repeated highways across multiple trips and sorts ascending',
      () async {
        final trip1 = TravelHistoryEntry(
          date: DateTime.utc(2026, 9, 1),
          highwayName: 'NH55',
          category: 'National',
          distanceKm: 50,
          averageSpeedKmh: 60,
          routePoints: [const LatLng(20.4, 85.8)],
          fromPlace: 'Cuttack',
          toPlace: 'Dhenkanal',
          nationalHighways: ['NH55 - National Highway 55'],
        );

        final trip2 = TravelHistoryEntry(
          date: DateTime.utc(2026, 9, 2),
          highwayName: 'NH55',
          category: 'National',
          distanceKm: 65,
          averageSpeedKmh: 55,
          routePoints: [const LatLng(20.7, 85.1)],
          fromPlace: 'Dhenkanal',
          toPlace: 'Angul',
          nationalHighways: ['NH 55'],
        );

        final trip3 = TravelHistoryEntry(
          date: DateTime.utc(2026, 9, 3),
          highwayName: 'NH149',
          category: 'National',
          distanceKm: 70,
          averageSpeedKmh: 50,
          routePoints: [const LatLng(21.1, 85.2)],
          fromPlace: 'Talcher',
          toPlace: 'Pallahara',
          nationalHighways: ['NH149'],
          stateHighways: ['SH10'],
        );

        final trip4 = TravelHistoryEntry(
          date: DateTime.utc(2026, 9, 4),
          highwayName: 'NH5',
          category: 'National',
          distanceKm: 40,
          averageSpeedKmh: 65,
          routePoints: [const LatLng(20.2, 85.8)],
          fromPlace: 'Bhubaneswar',
          toPlace: 'Cuttack',
          nationalHighways: ['NH5'],
        );

        await LocalStorageService.saveTravelHistory([
          trip1,
          trip2,
          trip3,
          trip4,
        ]);

        final highways =
            await LocalStorageService.syncIdentifiedHighwaysFromHistory();

        // Must not contain duplicate NH55 entries
        final nh55List = highways.where((h) => h.code == 'NH55').toList();
        expect(nh55List.length, 1);
        expect(nh55List.single.tripCount, 2);
        expect(nh55List.single.tripRoutes, [
          'Cuttack to Dhenkanal',
          'Dhenkanal to Angul',
        ]);

        // Ascending order check: NH5 (5), SH10 (10), NH55 (55), NH149 (149)
        expect(highways.map((h) => h.code).toList(), [
          'NH5',
          'SH10',
          'NH55',
          'NH149',
        ]);
      },
    );
  });

  group('TraveledHighwaysScreen Widget Tests', () {
    testWidgets('Renders header, ascending indicator, and filter pills', (
      WidgetTester tester,
    ) async {
      await LocalStorageService.saveIdentifiedHighways([
        const IdentifiedHighway(
          code: 'NH5',
          name: 'National Highway 5',
          category: 'national',
          number: 5,
        ),
        const IdentifiedHighway(
          code: 'NH55',
          name: 'National Highway 55',
          category: 'national',
          number: 55,
        ),
        const IdentifiedHighway(
          code: 'SH10',
          name: 'State Highway 10',
          category: 'state',
          number: 10,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: TraveledHighwaysScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Traveled Highways'), findsOneWidget);
      expect(
        find.text('State and National Highways in ascending order'),
        findsOneWidget,
      );
      expect(find.text('Ascending'), findsOneWidget);
      expect(find.text('NH5'), findsOneWidget);
      expect(find.text('SH10'), findsOneWidget);
      expect(find.text('NH55'), findsOneWidget);

      // Verify order index #1, #2, #3
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
    });

    testWidgets('Filter by National and State highways works', (
      WidgetTester tester,
    ) async {
      await LocalStorageService.saveIdentifiedHighways([
        const IdentifiedHighway(
          code: 'NH5',
          name: 'National Highway 5',
          category: 'national',
          number: 5,
        ),
        const IdentifiedHighway(
          code: 'SH10',
          name: 'State Highway 10',
          category: 'state',
          number: 10,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: TraveledHighwaysScreen()),
      );
      await tester.pumpAndSettle();

      // Tap National pill
      await tester.tap(find.text('National (1)'));
      await tester.pumpAndSettle();

      expect(find.text('NH5'), findsOneWidget);
      expect(find.text('SH10'), findsNothing);

      // Tap State pill
      await tester.tap(find.text('State (1)'));
      await tester.pumpAndSettle();

      expect(find.text('NH5'), findsNothing);
      expect(find.text('SH10'), findsOneWidget);
    });

    testWidgets('Searching highway code filters list dynamically', (
      WidgetTester tester,
    ) async {
      await LocalStorageService.saveIdentifiedHighways([
        const IdentifiedHighway(
          code: 'NH5',
          name: 'National Highway 5',
          category: 'national',
          number: 5,
        ),
        const IdentifiedHighway(
          code: 'NH149',
          name: 'National Highway 149',
          category: 'national',
          number: 149,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: TraveledHighwaysScreen()),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '149');
      await tester.pumpAndSettle();

      expect(find.text('NH149'), findsOneWidget);
      expect(find.text('NH5'), findsNothing);
    });

    testWidgets('Tapping highway opens detail dialog', (
      WidgetTester tester,
    ) async {
      await LocalStorageService.saveIdentifiedHighways([
        const IdentifiedHighway(
          code: 'NH55',
          name: 'National Highway 55',
          category: 'national',
          number: 55,
          tripRoutes: ['Cuttack to Angul'],
          tripCount: 2,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: TraveledHighwaysScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NH55'));
      await tester.pumpAndSettle();

      expect(find.text('Highway Code'), findsOneWidget);
      expect(find.text('Associated Trip Routes'), findsOneWidget);
      expect(find.text('Cuttack to Angul'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('2 trip(s)'),
        ),
        findsOneWidget,
      );
    });
  });
}
