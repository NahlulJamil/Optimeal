import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Official Optimeal support channel opened from Profile → Support.
const String supportInstagramUrl =
    'https://www.instagram.com/optimeal.hihu?fqnt=c2J4bmIxYmZhNm9n';

typedef ExternalUrlLauncher = Future<bool> Function(String url);

const MethodChannel _externalUrlChannel = MethodChannel(
  'com.example.optimeal/external_url',
);

/// Opens an external HTTP(S) link via Android `Intent.ACTION_VIEW` without
/// adding third-party packages. Overridden in widget tests.
final externalUrlLauncherProvider = Provider<ExternalUrlLauncher>((ref) {
  return (String url) async {
    try {
      final launched = await _externalUrlChannel.invokeMethod<bool>(
        'openUrl',
        <String, String>{'url': url},
      );
      return launched ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  };
});
