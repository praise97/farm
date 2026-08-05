import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/weather_service.dart';
import '../../core/theme/roots_theme.dart';
import '../providers/app_providers.dart';
import 'common_widgets.dart';

class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  IconData _icon(String key) => switch (key) {
        'sunny' => Icons.wb_sunny_outlined,
        'partly' => Icons.wb_cloudy_outlined,
        'fog' => Icons.foggy,
        'rain' => Icons.umbrella_outlined,
        'snow' => Icons.ac_unit,
        'storm' => Icons.thunderstorm_outlined,
        _ => Icons.cloud_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherProvider);

    return RootsCard(
      child: async.when(
        loading: () => const SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Row(
          children: [
            const Icon(Icons.cloud_off, color: RootsColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Weather unavailable. Pull to refresh later.\n$e',
                style: const TextStyle(color: RootsColors.muted, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: 'Retry',
              onPressed: () => ref.invalidate(weatherProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        data: (w) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: RootsColors.greenPale,
                  child: Icon(_icon(w.currentIcon), color: RootsColors.greenDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weather forecast',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        '${w.currentTempC.toStringAsFixed(0)}°C · ${w.currentLabel} · wind ${w.currentWindKph.toStringAsFixed(0)} km/h',
                        style: const TextStyle(color: RootsColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(weatherProvider),
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: w.daily.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final d = w.daily[i];
                  return Container(
                    width: 78,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: RootsColors.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          i == 0 ? 'Today' : DateFormat('E').format(d.date),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Icon(_icon(weatherCodeIcon(d.code)), size: 20, color: RootsColors.blue),
                        const SizedBox(height: 4),
                        Text(
                          '${d.maxC.toStringAsFixed(0)}°/${d.minC.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text('${d.precipChance}% rain',
                            style: const TextStyle(fontSize: 10, color: RootsColors.muted)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
