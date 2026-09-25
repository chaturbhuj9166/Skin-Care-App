import 'package:flutter/material.dart';

/// Attached to [GoRouter]'s `navigatorKey`, so code outside the widget tree
/// (the incoming-call dialog triggered from [ApiRepository], a tapped
/// background push in `push_service.dart`) can still get a [BuildContext]
/// wired to the app's Navigator to show a dialog or push a route.
final rootNavigatorKey = GlobalKey<NavigatorState>();
