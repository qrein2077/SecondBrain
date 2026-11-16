import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/models/app_settings.dart';
import 'package:secondbrain/models/cloud_provider.dart';

void main() {
  test('CloudProvider storage', () {
    expect(CloudProviderX.fromStorage('groq'), CloudProvider.groq);
    expect(CloudProviderX.fromStorage('openRouter'), CloudProvider.openRouter);
    expect(CloudProviderX.fromStorage(null), CloudProvider.gemini);
  });

  test('default cloud models', () {
    const s = AppSettings();
    expect(s.cloudProvider, CloudProvider.groq);
    expect(s.groqModel, 'llama-3.1-8b-instant');
    expect(s.openRouterModel, contains(':free'));
    expect(s.cloudModelFor(CloudProvider.gemini), 'gemini-3.8-flash');
    expect(AppSettings.legacyDefaultGeminiModel, 'gemini-2.5-flash');
  });
}
