import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';

/// Public legal pages served by the backend (backend/public). App Store
/// review wants the privacy policy reachable from inside the app.
const privacyPolicyPath = '/privacy-policy';
const termsPath = '/terms-and-conditions';

Future<void> openLegalPage(BuildContext context, String path) async {
  final opened = await launchUrl(Uri.parse('${AppConfig.apiBaseUrl}$path'), mode: LaunchMode.inAppBrowserView);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the page')));
  }
}
