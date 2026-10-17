import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/data/datasources/ai/on_device_llm_datasource.dart';

/// Smoke: LiteRT-LM engine registers on supported hosts without a model file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FlutterEdgeAi initializes with LiteRtLmEngine', () async {
    // Mobile/desktop hosts only — skip exotic CI targets.
    final supported =
        Platform.isLinux || Platform.isAndroid || Platform.isMacOS;
    expect(supported, isTrue);

    SharedPreferences.setMockInitialValues({});

    await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);

    final ds = OnDeviceLlmDatasource();
    // Fresh process: model not downloaded → not ready (no throw).
    final ready = await ds.isModelReady();
    expect(ready, isFalse);
  });
}
