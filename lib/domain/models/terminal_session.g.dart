// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TerminalSession _$TerminalSessionFromJson(Map<String, dynamic> json) =>
    _TerminalSession(
      id: json['id'] as String,
      title: json['title'] as String,
      shell: json['shell'] as String? ?? 'sh',
      isRoot: json['isRoot'] as bool? ?? false,
      history:
          (json['history'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastActive: json['lastActive'] == null
          ? null
          : DateTime.parse(json['lastActive'] as String),
    );

Map<String, dynamic> _$TerminalSessionToJson(_TerminalSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'shell': instance.shell,
      'isRoot': instance.isRoot,
      'history': instance.history,
      'unreadCount': instance.unreadCount,
      'lastActive': instance.lastActive?.toIso8601String(),
    };
