import "package:flutter/material.dart";

class DateSelectorBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  DateSelectorBar({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;

    if (diff == 0) return "Aujourd'hui";
    if (diff == -1) return "Hier";
    if (diff == 1) return "Demain";

    final mois = [
      "janv.", "févr.", "mars", "avr.", "mai", "juin",
      "juil.", "août", "sept.", "oct.", "nov.", "déc.",
    ];
    return "${date.day} ${mois[date.month - 1]}";
  }

  void _showQuickPicker(BuildContext context) {
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        Widget option(String label, DateTime date) {
          final isSelected = _isSameDay(date, selectedDate);
          return ListTile(
            title: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check, color: Color(0xFF16A34A))
                : null,
            onTap: () {
              onDateChanged(date);
              Navigator.pop(context);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              option("Hier", now.subtract(Duration(days: 1))),
              option("Aujourd'hui", now),
              option("Demain", now.add(Duration(days: 1))),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCalendar(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showQuickPicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      _label(selectedDate),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.calendar_today, size: 20),
            onPressed: () => _openCalendar(context),
          ),
        ],
      ),
    );
  }
}
