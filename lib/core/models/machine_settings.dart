import 'json.dart';

/// Ein Satz Maschinenwerte: Temperatur (°C, 0 = aus), Zeit (s), Stufe (0 = aus).
/// Body von `POST /api/v1/machine/program`, auch Teil von Rezept- und Programmschritten.
class MachineSettings {
  const MachineSettings({
    required this.temperature,
    required this.time,
    required this.speed,
  });

  final int temperature;
  final int time;
  final int speed;

  MachineSettings copyWith({int? temperature, int? time, int? speed}) =>
      MachineSettings(
        temperature: temperature ?? this.temperature,
        time: time ?? this.time,
        speed: speed ?? this.speed,
      );

  factory MachineSettings.fromJson(Json json) => MachineSettings(
    temperature: readInt(json['temperature']),
    time: readInt(json['time']),
    speed: readInt(json['speed']),
  );

  Json toJson() => {'temperature': temperature, 'time': time, 'speed': speed};

  @override
  bool operator ==(Object other) =>
      other is MachineSettings &&
      other.temperature == temperature &&
      other.time == time &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(temperature, time, speed);

  @override
  String toString() =>
      'MachineSettings($temperature °C, $time s, Stufe $speed)';
}
