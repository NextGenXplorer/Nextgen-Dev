// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'terminal_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TerminalSession {

 String get id; String get title; String get shell; bool get isRoot; List<String> get history; int get unreadCount; DateTime? get lastActive;
/// Create a copy of TerminalSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerminalSessionCopyWith<TerminalSession> get copyWith => _$TerminalSessionCopyWithImpl<TerminalSession>(this as TerminalSession, _$identity);

  /// Serializes this TerminalSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerminalSession&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.shell, shell) || other.shell == shell)&&(identical(other.isRoot, isRoot) || other.isRoot == isRoot)&&const DeepCollectionEquality().equals(other.history, history)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastActive, lastActive) || other.lastActive == lastActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,shell,isRoot,const DeepCollectionEquality().hash(history),unreadCount,lastActive);

@override
String toString() {
  return 'TerminalSession(id: $id, title: $title, shell: $shell, isRoot: $isRoot, history: $history, unreadCount: $unreadCount, lastActive: $lastActive)';
}


}

/// @nodoc
abstract mixin class $TerminalSessionCopyWith<$Res>  {
  factory $TerminalSessionCopyWith(TerminalSession value, $Res Function(TerminalSession) _then) = _$TerminalSessionCopyWithImpl;
@useResult
$Res call({
 String id, String title, String shell, bool isRoot, List<String> history, int unreadCount, DateTime? lastActive
});




}
/// @nodoc
class _$TerminalSessionCopyWithImpl<$Res>
    implements $TerminalSessionCopyWith<$Res> {
  _$TerminalSessionCopyWithImpl(this._self, this._then);

  final TerminalSession _self;
  final $Res Function(TerminalSession) _then;

/// Create a copy of TerminalSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? shell = null,Object? isRoot = null,Object? history = null,Object? unreadCount = null,Object? lastActive = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,shell: null == shell ? _self.shell : shell // ignore: cast_nullable_to_non_nullable
as String,isRoot: null == isRoot ? _self.isRoot : isRoot // ignore: cast_nullable_to_non_nullable
as bool,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<String>,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastActive: freezed == lastActive ? _self.lastActive : lastActive // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TerminalSession].
extension TerminalSessionPatterns on TerminalSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerminalSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerminalSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerminalSession value)  $default,){
final _that = this;
switch (_that) {
case _TerminalSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerminalSession value)?  $default,){
final _that = this;
switch (_that) {
case _TerminalSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String shell,  bool isRoot,  List<String> history,  int unreadCount,  DateTime? lastActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerminalSession() when $default != null:
return $default(_that.id,_that.title,_that.shell,_that.isRoot,_that.history,_that.unreadCount,_that.lastActive);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String shell,  bool isRoot,  List<String> history,  int unreadCount,  DateTime? lastActive)  $default,) {final _that = this;
switch (_that) {
case _TerminalSession():
return $default(_that.id,_that.title,_that.shell,_that.isRoot,_that.history,_that.unreadCount,_that.lastActive);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String shell,  bool isRoot,  List<String> history,  int unreadCount,  DateTime? lastActive)?  $default,) {final _that = this;
switch (_that) {
case _TerminalSession() when $default != null:
return $default(_that.id,_that.title,_that.shell,_that.isRoot,_that.history,_that.unreadCount,_that.lastActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerminalSession implements TerminalSession {
  const _TerminalSession({required this.id, required this.title, this.shell = 'sh', this.isRoot = false, final  List<String> history = const [], this.unreadCount = 0, this.lastActive}): _history = history;
  factory _TerminalSession.fromJson(Map<String, dynamic> json) => _$TerminalSessionFromJson(json);

@override final  String id;
@override final  String title;
@override@JsonKey() final  String shell;
@override@JsonKey() final  bool isRoot;
 final  List<String> _history;
@override@JsonKey() List<String> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

@override@JsonKey() final  int unreadCount;
@override final  DateTime? lastActive;

/// Create a copy of TerminalSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerminalSessionCopyWith<_TerminalSession> get copyWith => __$TerminalSessionCopyWithImpl<_TerminalSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerminalSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerminalSession&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.shell, shell) || other.shell == shell)&&(identical(other.isRoot, isRoot) || other.isRoot == isRoot)&&const DeepCollectionEquality().equals(other._history, _history)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastActive, lastActive) || other.lastActive == lastActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,shell,isRoot,const DeepCollectionEquality().hash(_history),unreadCount,lastActive);

@override
String toString() {
  return 'TerminalSession(id: $id, title: $title, shell: $shell, isRoot: $isRoot, history: $history, unreadCount: $unreadCount, lastActive: $lastActive)';
}


}

/// @nodoc
abstract mixin class _$TerminalSessionCopyWith<$Res> implements $TerminalSessionCopyWith<$Res> {
  factory _$TerminalSessionCopyWith(_TerminalSession value, $Res Function(_TerminalSession) _then) = __$TerminalSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String shell, bool isRoot, List<String> history, int unreadCount, DateTime? lastActive
});




}
/// @nodoc
class __$TerminalSessionCopyWithImpl<$Res>
    implements _$TerminalSessionCopyWith<$Res> {
  __$TerminalSessionCopyWithImpl(this._self, this._then);

  final _TerminalSession _self;
  final $Res Function(_TerminalSession) _then;

/// Create a copy of TerminalSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? shell = null,Object? isRoot = null,Object? history = null,Object? unreadCount = null,Object? lastActive = freezed,}) {
  return _then(_TerminalSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,shell: null == shell ? _self.shell : shell // ignore: cast_nullable_to_non_nullable
as String,isRoot: null == isRoot ? _self.isRoot : isRoot // ignore: cast_nullable_to_non_nullable
as bool,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<String>,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastActive: freezed == lastActive ? _self.lastActive : lastActive // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
