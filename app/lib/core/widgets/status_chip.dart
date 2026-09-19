import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../data/models/case_model.dart';

class StatusChip extends StatelessWidget {
  final CaseStatus status;
  const StatusChip({super.key, required this.status});

  Color get _color {
    switch (status) {
      case CaseStatus.pending:
        return AppColors.statusPending;
      case CaseStatus.assigned:
        return AppColors.statusAssigned;
      case CaseStatus.inReview:
        return AppColors.statusInReview;
      case CaseStatus.solved:
        return AppColors.statusSolved;
      case CaseStatus.closed:
        return AppColors.statusClosed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
