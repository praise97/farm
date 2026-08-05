import 'dart:convert';

import 'package:http/http.dart' as http;

/// Free forecast via Open-Meteo (no API key).
class WeatherForecast {
  const WeatherForecast({
    required this.timezone,
    required this.currentTempC,
    required this.currentCode,
    required this.currentWindKph,
    required this.daily,
  });

  final String timezone;
  final double currentTempC;
  final int currentCode;
  final double currentWindKph;
  final List<DailyWeather> daily;

  String get currentLabel => weatherCodeLabel(currentCode);
  IconDataLike get currentIcon => weatherCodeIcon(currentCode);

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final daily = json['daily'] as Map<String, dynamic>? ?? {};
    final times = (daily['time'] as List? ?? []).cast<String>();
    final maxes = (daily['temperature_2m_max'] as List? ?? []).cast<num>();
    final mins = (daily['temperature_2m_min'] as List? ?? []).cast<num>();
    final codes = (daily['weather_code'] as List? ?? []).cast<num>();
    final precip = (daily['precipitation_probability_max'] as List? ?? []).cast<num>();

    return WeatherForecast(
      timezone: json['timezone'] as String? ?? '',
      currentTempC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      currentCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      currentWindKph: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      daily: [
        for (var i = 0; i < times.length; i++)
          DailyWeather(
            date: DateTime.parse(times[i]),
            maxC: i < maxes.length ? maxes[i].toDouble() : 0,
            minC: i < mins.length ? mins[i].toDouble() : 0,
            code: i < codes.length ? codes[i].toInt() : 0,
            precipChance: i < precip.length ? precip[i].toInt() : 0,
          ),
      ],
    );
  }
}

class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.maxC,
    required this.minC,
    required this.code,
    required this.precipChance,
  });

  final DateTime date;
  final double maxC;
  final double minC;
  final int code;
  final int precipChance;

  String get label => weatherCodeLabel(code);
}

/// Avoid importing Flutter in pure service — map in UI.
typedef IconDataLike = String;

String weatherCodeLabel(int code) {
  if (code == 0) return 'Clear';
  if (code <= 3) return 'Partly cloudy';
  if (code <= 48) return 'Foggy';
  if (code <= 57) return 'Drizzle';
  if (code <= 67) return 'Rain';
  if (code <= 77) return 'Snow';
  if (code <= 82) return 'Showers';
  if (code <= 99) return 'Thunderstorm';
  return 'Unknown';
}

String weatherCodeIcon(int code) {
  if (code == 0) return 'sunny';
  if (code <= 3) return 'partly';
  if (code <= 48) return 'fog';
  if (code <= 67 || (code >= 80 && code <= 82)) return 'rain';
  if (code <= 77) return 'snow';
  if (code <= 99) return 'storm';
  return 'cloud';
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  Future<WeatherForecast> fetch({required double lat, required double lon}) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,weather_code,wind_speed_10m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&timezone=auto'
      '&forecast_days=5',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Weather HTTP ${res.statusCode}');
    }
    return WeatherForecast.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
