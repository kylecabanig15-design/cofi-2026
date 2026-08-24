import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';

class SubmitScheduleSection extends StatelessWidget {
  final List<MapEntry<String, String>> days;
  final Map<String, Map<String, dynamic>> schedule;
  final void Function(String dayKey, bool value) onToggleDay;
  final Future<void> Function(String dayKey, String field) onPickTime;

  const SubmitScheduleSection({
    super.key,
    required this.days,
    required this.schedule,
    required this.onToggleDay,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Daily Schedule',
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 12),
        ...days.map((d) => _buildDayRow(d.key, d.value)),
      ],
    );
  }

  Widget _buildDayRow(String key, String label) {
    final isOpen = (schedule[key]!['isOpen'] as bool);
    final TimeOfDay? open = schedule[key]!['open'] as TimeOfDay?;
    final TimeOfDay? close = schedule[key]!['close'] as TimeOfDay?;

    String fmt(TimeOfDay? t) => t == null
        ? '--:--'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextWidget(
                text: label,
                fontSize: 14,
                color: Colors.white,
                isBold: true,
              ),
              Switch(
                value: isOpen,
                activeColor: primary,
                onChanged: onToggleDay != null
                    ? (val) => onToggleDay(key, val)
                    : null,
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Open',
                  value: fmt(open),
                  enabled: isOpen,
                  onTap: () => onPickTime(key, 'open'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Close',
                  value: fmt(close),
                  enabled: isOpen,
                  onTap: () => onPickTime(key, 'close'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final tileColor = enabled ? Colors.grey[850] : Colors.grey[800];
    final textColor = enabled ? Colors.white : Colors.white54;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextWidget(
              text: label,
              fontSize: 13,
              color: textColor,
              isBold: false,
            ),
            Row(
              children: [
                TextWidget(
                  text: value,
                  fontSize: 13,
                  color: textColor,
                  isBold: true,
                ),
                const SizedBox(width: 8),
                Icon(Icons.access_time, color: textColor, size: 16),
              ],
            )
          ],
        ),
      ),
    );
  }
}
