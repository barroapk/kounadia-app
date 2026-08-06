import "package:flutter/material.dart";
import "../models/calendar.dart";

class MatchdaySelector extends StatefulWidget {
  final CalendarResponse calendar;
  final int selectedDay;
  final ValueChanged<int> onSelected;

  const MatchdaySelector({
    super.key,
    required this.calendar,
    required this.selectedDay,
    required this.onSelected,
  });

  @override
  State<MatchdaySelector> createState() => _MatchdaySelectorState();
}

class _MatchdaySelectorState extends State<MatchdaySelector> {
  final ScrollController _controller = ScrollController();
  static const double _itemWidth = 68;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _scrollToCurrent() {
    if (!_controller.hasClients) return;

    final realMatchdays = widget.calendar.matchdays.map((g) => g.matchday).toList();
    final index = realMatchdays.indexOf(widget.calendar.currentMatchday);
    if (index == -1) return;

    // Centre approximativement la journée en cours dans la barre visible.
    final viewportWidth = _controller.position.viewportDimension;
    final target = (index * _itemWidth - viewportWidth / 2 + _itemWidth / 2)
        .clamp(0, _controller.position.maxScrollExtent)
        .toDouble();

    _controller.jumpTo(target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final realMatchdays = widget.calendar.matchdays.map((g) => g.matchday).toList();

    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: realMatchdays.length,
        itemBuilder: (context, index) {
          final day = realMatchdays[index];
          final isSelected = day == widget.selectedDay;
          final group = widget.calendar.matchdays.firstWhere((g) => g.matchday == day);

          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _MatchdaySelectorState._itemWidth),
            child: IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(
                  label: Text(
                    widget.calendar.matchdays
                        .firstWhere((g) => g.matchday == day, orElse: () => group)
                        .shortDisplayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF16A34A),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  avatar: group.summary.live > 0
                      ? const CircleAvatar(backgroundColor: Color(0xFFDC2626), radius: 4)
                      : null,
                  onSelected: (_) => widget.onSelected(day),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
