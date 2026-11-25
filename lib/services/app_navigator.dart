import 'package:flutter/material.dart';

/// Navigation hors widgets (push, temps réel).
final appNavigatorKey = GlobalKey<NavigatorState>();

NavigatorState? get appNavigator => appNavigatorKey.currentState;
