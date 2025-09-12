import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import '../utils/date_time_utils.dart';
import 'toggle_switch.dart';

class PrayerTimeCard extends StatelessWidget {
  final PrayerTime prayer;
  final bool isActive;
  final bool isNext;
  final bool showToggle;
  final Function(bool)? onToggle;

  const PrayerTimeCard({
    super.key,
    required this.prayer,
    this.isActive = false,
    this.isNext = false,
    this.showToggle = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    Color? textColor;
    IconData? statusIcon;

    if (isActive) {
      cardColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      statusIcon = Icons.volume_off;
    } else if (isNext) {
      cardColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      statusIcon = Icons.schedule;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (statusIcon != null) ...[
              Icon(statusIcon, color: textColor),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: isActive || isNext ? FontWeight.bold : null,
                    ),
                  ),
                  Text(
                    DateTimeUtils.formatTime(prayer.time),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textColor,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 4),
                    Text(
                      'SILENCED',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else if (isNext) ...[
                    const SizedBox(height: 4),
                    Text(
                      'NEXT PRAYER',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showToggle && onToggle != null)
              ToggleSwitch(
                value: prayer.isEnabled,
                onChanged: onToggle!,
              ),
          ],
        ),
      ),
    );
  }
}
