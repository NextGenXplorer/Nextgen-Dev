import 'package:freezed_annotation/freezed_annotation.dart';

part 'terminal_session.freezed.dart';
part 'terminal_session.g.dart';

@freezed
abstract class TerminalSession with _$TerminalSession {
  const factory TerminalSession({
    required String id,
    required String title,
    @Default('sh') String shell,
    @Default(false) bool isRoot,
    @Default([]) List<String> history,
    @Default(0) int unreadCount,
    DateTime? lastActive,
  }) = _TerminalSession;

  factory TerminalSession.fromJson(Map<String, dynamic> json) =>
      _$TerminalSessionFromJson(json);
}
