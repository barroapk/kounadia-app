import "package:flutter/material.dart";

class LoadingSkeleton extends StatelessWidget {
  LoadingSkeleton({super.key});

  Widget _bar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _skeletonCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(100, 12),
            SizedBox(height: 12),
            _bar(180, 14),
            SizedBox(height: 8),
            _bar(160, 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      children: List.generate(4, (_) => _skeletonCard()),
    );
  }
}
