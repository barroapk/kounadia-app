import "package:flutter/material.dart";

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});

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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(100, 12),
            const SizedBox(height: 12),
            _bar(180, 14),
            const SizedBox(height: 8),
            _bar(160, 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: List.generate(4, (_) => _skeletonCard()),
    );
  }
}
