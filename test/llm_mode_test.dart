import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/models/llm_mode.dart';

void main() {
  test('LlmMode storage round-trip', () {
    expect(LlmModeX.fromStorage('local'), LlmMode.local);
    expect(LlmModeX.fromStorage('cloud'), LlmMode.cloud);
    expect(LlmModeX.fromStorage('auto'), LlmMode.auto);
    expect(LlmModeX.fromStorage(null), LlmMode.local);
    expect(LlmModeX.fromStorage('nope'), LlmMode.local);
    expect(LlmMode.auto.storageValue, 'auto');
  });
}
