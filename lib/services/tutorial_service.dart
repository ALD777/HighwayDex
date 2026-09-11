import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:highwaydex/services/local_storage_service.dart';

class TutorialService {
  // Main Nav Keys
  static final GlobalKey navDriveKey = GlobalKey();
  static final GlobalKey navDirectoryKey = GlobalKey();
  static final GlobalKey navSavedKey = GlobalKey();
  static final GlobalKey navTravelKey = GlobalKey();
  static final GlobalKey navHistoryKey = GlobalKey();

  // Drive Mode Keys
  static final GlobalKey driveCurrentLocationKey = GlobalKey();
  static final GlobalKey driveStartStopKey = GlobalKey();
  static final GlobalKey driveSpeedKey = GlobalKey();
  static final GlobalKey driveMetricsKey = GlobalKey();

  // Directory Keys
  static final GlobalKey directoryListKey = GlobalKey();

  // Collection Keys
  static final GlobalKey collectionSearchKey = GlobalKey();
  static final GlobalKey collectionChipsKey = GlobalKey();

  // Travel Keys
  static final GlobalKey travelListKey = GlobalKey();

  // History Keys
  static final GlobalKey historyListKey = GlobalKey();

  static Future<void> showTutorial({
    required BuildContext context,
    required String tutorialName,
    required List<TargetFocus> targets,
  }) async {
    final globallyDisabled =
        await LocalStorageService.areTutorialsGloballyDisabled();
    if (globallyDisabled) return;

    final isCompleted = await LocalStorageService.isTutorialCompleted(
      tutorialName,
    );
    if (isCompleted) return;

    if (!context.mounted) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF0F0F0F),
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        LocalStorageService.markTutorialCompleted(tutorialName);
      },
      onClickTarget: (target) {
        // Optional logic on target click
      },
      onClickTargetWithTapPosition: (target, tapDetails) {},
      onClickOverlay: (target) {},
      onSkip: () {
        LocalStorageService.markTutorialCompleted(tutorialName);
        return true;
      },
    ).show(context: context);
  }

  static TargetFocus createTargetFocus({
    required String identify,
    required GlobalKey keyTarget,
    required String title,
    required String description,
    ContentAlign align = ContentAlign.bottom,
    ShapeLightFocus shape = ShapeLightFocus.RRect,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: keyTarget,
      alignSkip: Alignment.topRight,
      shape: shape,
      radius: 12,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) {
            bool skipFutureTutorials = false;
            return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF41D3A8).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF41D3A8),
                          fontSize: 20.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
                        child: Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: skipFutureTutorials,
                              onChanged: (val) {
                                setState(() {
                                  skipFutureTutorials = val ?? false;
                                });
                                if (skipFutureTutorials) {
                                  LocalStorageService.setTutorialsGloballyDisabled(
                                    true,
                                  );
                                } else {
                                  LocalStorageService.setTutorialsGloballyDisabled(
                                    false,
                                  );
                                }
                              },
                              activeColor: const Color(0xFF41D3A8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Never show tutorials again",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              controller.skip();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white54,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text("Skip All"),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  controller.previous();
                                },
                                icon: const Icon(
                                  Icons.arrow_back_ios_rounded,
                                  size: 16,
                                ),
                                color: Colors.white,
                                tooltip: "Previous",
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  controller.next();
                                },
                                icon: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                ),
                                color: Colors.white,
                                tooltip: "Next",
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
