import 'package:flutter_test/flutter_test.dart';
import 'package:avis_mobile/core/live_runner_controller.dart';

void main() {
  group('LiveRunnerController Tests', () {
    final controller = LiveRunnerController();

    test('Load code stores payload and generates executable HTML', () {
      controller.loadCode(
        code: '<button id="btn">Click Me</button>',
        language: 'html',
        title: 'Test App',
      );

      expect(controller.currentPayload, isNotNull);
      expect(controller.currentPayload!.language, 'html');
      expect(controller.currentPayload!.title, 'Test App');

      final html = controller.buildExecutableHtml(controller.currentPayload!);
      expect(html, contains('AvisBridge'));
      expect(html, contains('console.log'));
      expect(html, contains('Click Me'));
    });

    test('JavaScript payload is wrapped with execution canvas and error traps', () {
      controller.loadCode(
        code: 'console.log("Hello from Test JS");',
        language: 'javascript',
        title: 'JS Test',
      );

      final html = controller.buildExecutableHtml(controller.currentPayload!);
      expect(html, contains('JAVASCRIPT ACTIVE EXECUTION'));
      expect(html, contains('Hello from Test JS'));
    });

    test('Bridge message ingestion records log entry', () {
      controller.clearLogs();
      controller.ingestBridgeMessage('{"level":"error","message":"Uncaught SyntaxError"}');

      expect(controller.logs.length, 1);
      expect(controller.logs.first.level, 'error');
      expect(controller.logs.first.message, 'Uncaught SyntaxError');
    });

    test('Hot reload updates payload without losing session', () {
      controller.loadCode(code: '<h1>Version 1</h1>', language: 'html');
      controller.hotReload('<h1>Version 2</h1>');

      expect(controller.currentPayload!.code, '<h1>Version 2</h1>');
    });
  });
}
