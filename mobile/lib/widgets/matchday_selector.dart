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

  // Une clé par journée, pour pouvoir viser précisément le bon élément avec
  // Scrollable.ensureVisible : plus fiable qu'un calcul manuel de position,
  // qui suppose à tort une largeur fixe alors que les puces (J1, 1/4, Finale...)
  // ont des largeurs variables (IntrinsicWidth).
  final Map<int, GlobalKey> _itemKeys = {};

  GlobalKey _keyFor(int day) => _itemKeys.putIfAbsent(day, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(covariant MatchdaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le calendrier peut arriver après coup (chargement async, changement de
    // saison) : initState() seul ne suffit pas, il faut re-tenter à chaque
    // fois que les données changent réellement.
    if (oldWidget.calendar != widget.calendar || oldWidget.selectedDay != widget.selectedDay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _scrollToCurrent() {
    if (!mounted) return;
    final key = _itemKeys[widget.selectedDay];
    final context = key?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
    );
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
            key: _keyFor(day),
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
