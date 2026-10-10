import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/models/swipe_page_transition.dart';
import 'package:substitute/services/SchoolStorage.dart';

import 'Plan.dart';
import 'WeekPlan.dart';

/// Öffnet den Plan einer Klasse bzw. einer Person.
///
/// Je nach Einstellung „Ganze Woche anzeigen“ (Plan-Einstellungen) wird
/// entweder die Wochen- oder die Tagesansicht geöffnet. Die Einstellung wird
/// bei jedem Öffnen neu gelesen – sie kann sich geändert haben, seit die
/// Übersicht aufgebaut wurde (die Einstellungsseite liegt hinter der
/// Übersicht).
///
/// [wrapInScaffold] entspricht dem bisherigen Verhalten: Bei einer Person wird
/// der Plan in ein [Scaffold] gelegt, bei einer Klasse nicht.
Future<void> openPlanPage(
  BuildContext context, {
  required String classId,
  Map<String, dynamic>? person,
  bool wrapInScaffold = false,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool weekView =
      prefs.getBool(SchoolStorage.scopedKey(prefs, 'showWeekView')) ?? false;

  if (!context.mounted) return;

  final Widget page = weekView
      ? WeekPlan(classId: classId, person: person)
      : Plan(classId: classId, person: person);
  final Widget child = wrapInScaffold
      ? Scaffold(body: page)
      : page;

  await Navigator.push(
    context,
    SwipePageTransition(
      type: PageTransitionType.rightToLeft,
      child: child,
    ),
  );
}