import 'package:flutter_test/flutter_test.dart';
import 'package:avis_mobile/core/system_manual_manager.dart';

void main() {
  group('SystemManualManager Tests', () {
    final manual = SystemManualManager();

    test('Topic HTML runner returns playground and execution runner info', () {
      final res = manual.searchManual('HTML run kahan dikhega');
      expect(res, contains('Universal Live Playground'));
      expect(res, contains('AvisLivePlaygroundDialog'));
    });

    test('Topic Floating overlays returns WindowManager and Avis Canvas info', () {
      final res = manual.searchManual('floating overlay');
      expect(res, contains('Floating Overlays & Avis Canvas'));
      expect(res, contains('CodeOverlayService'));
    });

    test('Topic Passive Silent mode returns shadow context log info', () {
      final res = manual.searchManual('silent mode');
      expect(res, contains('Passive Silent Listening'));
      expect(res, contains('shadow_context_log.md'));
    });

    test('Topic Autonomous tools returns comprehensive tool catalog', () {
      final res = manual.searchManual('tools');
      expect(res, contains('Autonomous Tools Catalog'));
      expect(res, contains('control_flashlight'));
      expect(res, contains('type_text'));
    });

    test('All topics list is complete', () {
      final topics = manual.getAllTopicIds();
      expect(topics, containsAll([
        'html_runner',
        'floating_overlays',
        'neural_orb',
        'passive_silent_mode',
        'typing_safety',
        'autonomous_tools',
        'dual_personas',
        'cognitive_memory',
        'system_permissions',
      ]));
    });
  });
}
