import 'package:flutter/material.dart';

class StageBadge extends StatelessWidget {
  final String stage;
  final String? wonStage;

  const StageBadge({
    super.key,
    required this.stage,
    this.wonStage,
  });

  static Color getColor(String stage, String? wonStage) {
    if (wonStage != null && stage == wonStage) {
      return Colors.green;
    }
    // Default colors for common stages
    switch (stage.toLowerCase()) {
      case 'lead':
        return Colors.blue;
      case 'negotiation':
        return Colors.orange;
      case 'quotation created':
      case 'quotation sent':
        return Colors.purple;
      case 'invoice created':
      case 'invoice sent':
        return Colors.amber;
      case 'won':
        return Colors.green;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(stage, wonStage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        stage,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
