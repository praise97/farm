import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// GlobalKeys for first-run guided tour (circle highlight + short note).
class TourKeys {
  static final menu = GlobalKey();
  static final stats = GlobalKey();
  static final weather = GlobalKey();
  static final charts = GlobalKey();
  static final quickActions = GlobalKey();
  static final alerts = GlobalKey();
  static final livestock = GlobalKey();
}

class RootsTour {
  static void start(BuildContext context) {
    ShowCaseWidget.of(context).startShowCase([
      TourKeys.menu,
      TourKeys.stats,
      TourKeys.weather,
      TourKeys.charts,
      TourKeys.quickActions,
      TourKeys.alerts,
      TourKeys.livestock,
    ]);
  }
}

Widget tourTarget({
  required GlobalKey key,
  required String title,
  required String description,
  required Widget child,
  VoidCallback? onTargetClick,
}) {
  return Showcase(
    key: key,
    title: title,
    description: description,
    targetShapeBorder: const CircleBorder(),
    disableDefaultTargetGestures: false,
    disableBarrierInteraction: false,
    onTargetClick: onTargetClick,
    disposeOnTap: onTargetClick != null,
    tooltipBackgroundColor: const Color(0xFF0F1A17),
    textColor: Colors.white,
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    ),
    descTextStyle: const TextStyle(color: Color(0xFFD5DDD8), fontSize: 13, height: 1.35),
    child: child,
  );
}
