import 'app_settings.dart';

/// Named system-prompt preset for the universal agent.
class AgentPreset {
  const AgentPreset({
    required this.id,
    required this.name,
    required this.systemPrompt,
  });

  final String id;
  final String name;
  final String systemPrompt;

  static const defaultPresetId = 'default_clarifying';

  /// Built-in clarifying default (current shipped system prompt).
  static AgentPreset get clarifyingDefault => AgentPreset(
        id: defaultPresetId,
        name: 'Уточняющий (default)',
        systemPrompt: AppSettings.defaultSystemPrompt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'systemPrompt': systemPrompt,
      };

  factory AgentPreset.fromJson(Map<String, dynamic> json) {
    return AgentPreset(
      id: json['id'] as String? ?? 'preset_${DateTime.now().microsecondsSinceEpoch}',
      name: (json['name'] as String? ?? 'Пресет').trim(),
      systemPrompt: json['systemPrompt'] as String? ?? '',
    );
  }

  AgentPreset copyWith({String? id, String? name, String? systemPrompt}) {
    return AgentPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}
