import 'dart:io';

import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

/// A [PageTransition] that enables the native iOS edge-swipe-back gesture
/// (vom linken Bildschirmrand zur Mitte wischen) on iOS devices, while keeping
/// the previous Material-style transition unchanged on Android.
class SwipePageTransition<T> extends PageTransition<T> {
  SwipePageTransition({
    required PageTransitionType type,
    required Widget child,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : super(
          type: type,
          child: child,
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          opaque: true,
          isIos: Platform.isIOS,
        );
}
