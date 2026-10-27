import 'package:hive_ce_flutter/hive_flutter.dart';

/// What a reminder is about. [wire] is the value the reminders backend and
/// the sync JSON use.
enum ReminderType {
  weighIn('weigh_in'),
  meal('meal'),
  custom('custom');

  final String wire;

  const ReminderType(this.wire);

  static ReminderType fromWire(String value) => values.firstWhere((t) => t.wire == value, orElse: () => custom);
}

enum ReminderMealType {
  breakfast,
  lunch,
  snack,
  dinner;

  static ReminderMealType? fromWire(String? value) {
    for (final t in values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

enum ReminderChannel {
  push,
  email,
  telegram;

  static ReminderChannel fromWire(String? value) => values.firstWhere((c) => c.name == value, orElse: () => telegram);
}

/// One reminder. Doubles as the record the reminders backend takes in
/// `reminders-sync`: [toJson] is exactly its wire format.
class ReminderDBO extends HiveObject {
  static const int hiveTypeId = 25;

  /// Prefix of the ids of the five built-in reminders (never deleted).
  static const String defaultIdPrefix = 'default_';

  final String id;
  final ReminderType type;

  /// Set when [type] is [ReminderType.meal], null otherwise.
  final ReminderMealType? mealType;

  /// Up to 40 characters; empty for the built-in reminders, which show a
  /// localized name instead.
  final String label;

  /// Local time, `HH:MM`.
  final String time;

  /// ISO weekdays, 1 = Monday .. 7 = Sunday.
  final List<int> days;
  final ReminderChannel channel;
  final bool enabled;
  final bool skipIfLogged;

  ReminderDBO({
    required this.id,
    required this.type,
    this.mealType,
    this.label = '',
    required this.time,
    required this.days,
    required this.channel,
    this.enabled = true,
    this.skipIfLogged = false,
  });

  bool get isDefault => id.startsWith(defaultIdPrefix);

  ReminderDBO copyWith({
    String? id,
    String? label,
    String? time,
    List<int>? days,
    ReminderChannel? channel,
    bool? enabled,
    bool? skipIfLogged,
  }) => ReminderDBO(
    id: id ?? this.id,
    type: type,
    mealType: mealType,
    label: label ?? this.label,
    time: time ?? this.time,
    days: days ?? this.days,
    channel: channel ?? this.channel,
    enabled: enabled ?? this.enabled,
    skipIfLogged: skipIfLogged ?? this.skipIfLogged,
  );

  factory ReminderDBO.fromJson(Map<String, dynamic> json) => ReminderDBO(
    id: json['id'] as String,
    type: ReminderType.fromWire(json['type'] as String),
    mealType: ReminderMealType.fromWire(json['mealType'] as String?),
    label: json['label'] as String? ?? '',
    time: json['time'] as String,
    days: [for (final d in (json['days'] as List? ?? const [])) (d as num).toInt()],
    channel: ReminderChannel.fromWire(json['channel'] as String?),
    enabled: json['enabled'] as bool? ?? true,
    skipIfLogged: json['skipIfLogged'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.wire,
    'mealType': mealType?.name,
    'label': label,
    'time': time,
    'days': days,
    'channel': channel.name,
    'enabled': enabled,
    'skipIfLogged': skipIfLogged,
  };
}

/// Device-wide reminder settings (single record under [boxKey]).
class ReminderSettingsDBO extends HiveObject {
  static const int hiveTypeId = 26;
  static const String boxKey = 'settings';
  static const String defaultQuietStart = '23:00';
  static const String defaultQuietEnd = '06:30';

  /// IANA name, e.g. `Europe/Madrid`.
  final String timezone;

  /// Quiet hours (`HH:MM`); both null means no quiet hours.
  final String? quietStart;
  final String? quietEnd;
  final String? email;
  final bool emailVerified;
  final bool telegramLinked;

  ReminderSettingsDBO({
    this.timezone = 'UTC',
    this.quietStart = defaultQuietStart,
    this.quietEnd = defaultQuietEnd,
    this.email,
    this.emailVerified = false,
    this.telegramLinked = false,
  });

  bool get hasQuietHours => quietStart != null && quietEnd != null;

  /// [clearQuiet] switches quiet hours off (a null [quietStart] / [quietEnd]
  /// alone means "keep").
  ReminderSettingsDBO copyWith({
    String? timezone,
    String? quietStart,
    String? quietEnd,
    bool clearQuiet = false,
    String? email,
    bool? emailVerified,
    bool? telegramLinked,
  }) => ReminderSettingsDBO(
    timezone: timezone ?? this.timezone,
    quietStart: clearQuiet ? null : quietStart ?? this.quietStart,
    quietEnd: clearQuiet ? null : quietEnd ?? this.quietEnd,
    email: email ?? this.email,
    emailVerified: emailVerified ?? this.emailVerified,
    telegramLinked: telegramLinked ?? this.telegramLinked,
  );

  factory ReminderSettingsDBO.fromJson(Map<String, dynamic> json) => ReminderSettingsDBO(
    timezone: json['timezone'] as String? ?? 'UTC',
    quietStart: json['quietStart'] as String?,
    quietEnd: json['quietEnd'] as String?,
    email: json['email'] as String?,
    emailVerified: json['emailVerified'] as bool? ?? false,
    telegramLinked: json['telegramLinked'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'timezone': timezone,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'email': email,
    'emailVerified': emailVerified,
    'telegramLinked': telegramLinked,
  };
}

/// Hand-written in the generator's format (field ids are stable; add new
/// fields with new ids only).
class ReminderDBOAdapter extends TypeAdapter<ReminderDBO> {
  @override
  final typeId = ReminderDBO.hiveTypeId;

  @override
  ReminderDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ReminderDBO(
      id: fields[0] as String,
      type: ReminderType.fromWire(fields[1] as String),
      mealType: ReminderMealType.fromWire(fields[2] as String?),
      label: fields[3] as String? ?? '',
      time: fields[4] as String,
      days: [for (final d in (fields[5] as List? ?? const [])) (d as num).toInt()],
      channel: ReminderChannel.fromWire(fields[6] as String?),
      enabled: fields[7] as bool? ?? true,
      skipIfLogged: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderDBO obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.wire)
      ..writeByte(2)
      ..write(obj.mealType?.name)
      ..writeByte(3)
      ..write(obj.label)
      ..writeByte(4)
      ..write(obj.time)
      ..writeByte(5)
      ..write(obj.days)
      ..writeByte(6)
      ..write(obj.channel.name)
      ..writeByte(7)
      ..write(obj.enabled)
      ..writeByte(8)
      ..write(obj.skipIfLogged);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReminderDBOAdapter && typeId == other.typeId;
}

class ReminderSettingsDBOAdapter extends TypeAdapter<ReminderSettingsDBO> {
  @override
  final typeId = ReminderSettingsDBO.hiveTypeId;

  @override
  ReminderSettingsDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ReminderSettingsDBO(
      timezone: fields[0] as String? ?? 'UTC',
      quietStart: fields[1] as String?,
      quietEnd: fields[2] as String?,
      email: fields[3] as String?,
      emailVerified: fields[4] as bool? ?? false,
      telegramLinked: fields[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderSettingsDBO obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.timezone)
      ..writeByte(1)
      ..write(obj.quietStart)
      ..writeByte(2)
      ..write(obj.quietEnd)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.emailVerified)
      ..writeByte(5)
      ..write(obj.telegramLinked);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ReminderSettingsDBOAdapter && typeId == other.typeId;
}
