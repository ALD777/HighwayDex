import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:highwaydex/screens/drive_mode_screen.dart';
import 'package:highwaydex/screens/highway_collection_screen.dart';
import 'package:highwaydex/screens/highway_history_screen.dart';
import 'package:highwaydex/screens/travel_history_screen.dart';
import 'package:highwaydex/screens/traveled_highways_screen.dart';
import 'package:highwaydex/services/local_storage_service.dart';
import 'package:highwaydex/services/google_drive_sync_service.dart';
import 'package:highwaydex/services/tutorial_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await LocalStorageService.init();
  runApp(const HighwayRxApp());
}

class HighwayRxApp extends StatelessWidget {
  const HighwayRxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HighwayRx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(
          0xFF030303,
        ), // Pure deep OLED black
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF41D3A8), // Vibrant neon mint
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFF41D3A8),
              onPrimary: const Color(0xFF003825),
              secondary: const Color(0xFFFF9B42), // Vibrant orange
              onSecondary: const Color(0xFF381A00),
              surface: const Color(0xFF0A0A0A),
              surfaceContainer: const Color(0xFF141414),
              surfaceContainerHigh: const Color(0xFF1E1E1E),
              outline: const Color(0xFF333333),
            ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w400,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0F0F0F),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              32,
            ), // Modern highly rounded corners
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141414),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFF41D3A8), width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const HighwayDexHome(),
    );
  }
}

class HighwayDexHome extends StatefulWidget {
  const HighwayDexHome({super.key});

  @override
  State<HighwayDexHome> createState() => _HighwayDexHomeState();
}

class _HighwayDexHomeState extends State<HighwayDexHome> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DriveModeScreen(key: ValueKey('drive')),
    TraveledHighwaysScreen(key: ValueKey('nh_sh')),
    HighwayCollectionScreen(key: ValueKey('collection')),
    TravelHistoryScreen(key: ValueKey('travel')),
    HighwayHistoryScreen(key: ValueKey('history')),
  ];

  @override
  void initState() {
    super.initState();
    _performStartupSyncChecks();
  }

  Future<void> _performStartupSyncChecks() async {
    final isFirst = await LocalStorageService.isFirstLaunch();
    if (isFirst) {
      if (!mounted) return;
      final wantToRestore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Backup?'),
          content: const Text(
            'Welcome! Would you like to sign in to Google Drive and check for an existing backup to restore?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, skip'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign in & Restore'),
            ),
          ],
        ),
      );

      if (wantToRestore == true) {
        final account = await GoogleDriveSyncService.signIn();
        if (account != null) {
          final success = await GoogleDriveSyncService.restoreData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Restore successful! Restarting app...'
                      : 'No backup found or restore failed.',
                ),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
            if (success) {
              Future.delayed(const Duration(seconds: 1), () {
                setState(() {}); // Trigger rebuild
              });
            }
          }
        }
      }
      _showMainNavTutorial();
    } else {
      // Not first launch, attempt silent daily backup
      await GoogleDriveSyncService.performDailyBackupIfNeeded();
    }
  }

  void _showMainNavTutorial() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final isMainNavCompleted = await LocalStorageService.isTutorialCompleted(
        'main_nav',
      );
      if (!isMainNavCompleted && mounted) {
        TutorialCoachMark(
          targets: [
            TutorialService.createTargetFocus(
              identify: "nav_drive",
              keyTarget: TutorialService.navDriveKey,
              title: "Drive Mode",
              description: "Start tracking your highway journeys from here.",
              align: ContentAlign.top,
            ),
            TutorialService.createTargetFocus(
              identify: "nav_directory",
              keyTarget: TutorialService.navDirectoryKey,
              title: "Highway Directory",
              description:
                  "View a directory of all discovered highways and their details.",
              align: ContentAlign.top,
            ),
            TutorialService.createTargetFocus(
              identify: "nav_saved",
              keyTarget: TutorialService.navSavedKey,
              title: "Saved Collections",
              description: "Access your saved and collected highway cards.",
              align: ContentAlign.top,
            ),
            TutorialService.createTargetFocus(
              identify: "nav_travel",
              keyTarget: TutorialService.navTravelKey,
              title: "Travel History",
              description: "Review all your past trips and tracked routes.",
              align: ContentAlign.top,
            ),
            TutorialService.createTargetFocus(
              identify: "nav_history",
              keyTarget: TutorialService.navHistoryKey,
              title: "Highway History",
              description:
                  "See detailed stats on all the highways you've traversed.",
              align: ContentAlign.top,
            ),
          ],
          colorShadow: const Color(0xFF0F0F0F),
          textSkip: "SKIP",
          paddingFocus: 10,
          opacityShadow: 0.85,
          onFinish: () {
            LocalStorageService.markTutorialCompleted('main_nav');
            _showDriveTutorial();
          },
          onSkip: () {
            LocalStorageService.markTutorialCompleted('main_nav');
            _showDriveTutorial();
            return true;
          },
        ).show(context: context);
      } else {
        _showDriveTutorial();
      }
    });
  }

  void _showDriveTutorial() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      TutorialService.showTutorial(
        context: context,
        tutorialName: 'drive_mode',
        targets: [
          TutorialService.createTargetFocus(
            identify: "drive_current_location",
            keyTarget: TutorialService.driveCurrentLocationKey,
            title: "Your Location",
            description:
                "Displays your current location name based on GPS data.",
            align: ContentAlign.bottom,
          ),
          TutorialService.createTargetFocus(
            identify: "drive_start_stop",
            keyTarget: TutorialService.driveStartStopKey,
            title: "Start Tracking",
            description:
                "Tap to begin tracking your trip and analyzing the highways you take.",
            align: ContentAlign.bottom,
          ),
          TutorialService.createTargetFocus(
            identify: "drive_speed",
            keyTarget: TutorialService.driveSpeedKey,
            title: "Current Speed",
            description:
                "Real-time speed indicator updates automatically as you drive.",
            align: ContentAlign.top,
          ),
          TutorialService.createTargetFocus(
            identify: "drive_metrics",
            keyTarget: TutorialService.driveMetricsKey,
            title: "Trip Metrics",
            description:
                "View your lifetime average speed, distance, and current tracking status here.",
            align: ContentAlign.top,
          ),
        ],
      );
    });
  }

  void _showDirectoryTutorial() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      TutorialService.showTutorial(
        context: context,
        tutorialName: 'directory',
        targets: [
          TutorialService.createTargetFocus(
            identify: "directory_list",
            keyTarget: TutorialService.directoryListKey,
            title: "Highway Directory",
            description: "Explore a list of all highways and your progression.",
            align: ContentAlign.bottom,
          ),
        ],
      );
    });
  }

  void _showCollectionTutorial() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      TutorialService.showTutorial(
        context: context,
        tutorialName: 'collection',
        targets: [
          TutorialService.createTargetFocus(
            identify: "collection_search",
            keyTarget: TutorialService.collectionSearchKey,
            title: "Search Cards",
            description:
                "Quickly find any saved highway card by its code or name.",
            align: ContentAlign.bottom,
          ),
          TutorialService.createTargetFocus(
            identify: "collection_chips",
            keyTarget: TutorialService.collectionChipsKey,
            title: "Add Custom Highway",
            description: "Tap here to manually log a custom road or highway.",
            align: ContentAlign.bottom,
          ),
        ],
      );
    });
  }

  void _showHistoryTutorial() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      TutorialService.showTutorial(
        context: context,
        tutorialName: 'history',
        targets: [
          TutorialService.createTargetFocus(
            identify: "history_list",
            keyTarget: TutorialService.historyListKey,
            title: "Detailed History",
            description:
                "Check stats and historical analysis of all your highway tracking sessions.",
            align: ContentAlign.bottom,
          ),
        ],
      );
    });
  }

  void _showTravelTutorial() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      TutorialService.showTutorial(
        context: context,
        tutorialName: 'travel',
        targets: [
          TutorialService.createTargetFocus(
            identify: "travel_list",
            keyTarget: TutorialService.travelListKey,
            title: "Travel Log",
            description:
                "Your complete chronological log of all tracked trips.",
            align: ContentAlign.top,
          ),
        ],
      );
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Trigger screen-specific tutorials when navigating to the tab
    if (index == 0) _showDriveTutorial();
    if (index == 1) _showDirectoryTutorial();
    if (index == 2) _showCollectionTutorial();
    if (index == 3) _showTravelTutorial();
    if (index == 4) _showHistoryTutorial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Needed for floating bottom nav
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141414).withValues(alpha: 0.6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                height: 72,
                backgroundColor: Colors.transparent,
                indicatorColor: const Color(0xFF41D3A8).withValues(alpha: 0.25),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Icon(
                      Icons.route_rounded,
                      key: TutorialService.navDriveKey,
                    ),
                    selectedIcon: const Icon(
                      Icons.route_rounded,
                      color: Color(0xFF41D3A8),
                    ),
                    label: 'Drive',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.signpost_rounded,
                      key: TutorialService.navDirectoryKey,
                    ),
                    selectedIcon: const Icon(
                      Icons.signpost_rounded,
                      color: Color(0xFF41D3A8),
                    ),
                    label: 'Directory',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.collections_bookmark_rounded,
                      key: TutorialService.navSavedKey,
                    ),
                    selectedIcon: const Icon(
                      Icons.collections_bookmark_rounded,
                      color: Color(0xFF41D3A8),
                    ),
                    label: 'Saved',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.history_rounded,
                      key: TutorialService.navTravelKey,
                    ),
                    selectedIcon: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF41D3A8),
                    ),
                    label: 'Travel',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.auto_awesome_rounded,
                      key: TutorialService.navHistoryKey,
                    ),
                    selectedIcon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF41D3A8),
                    ),
                    label: 'History',
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
