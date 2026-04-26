import 'package:flutter/material.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/screens/admin/academy_detail_screen.dart';

class AcademyTrainingFieldScreen extends StatelessWidget {
  const AcademyTrainingFieldScreen({
    super.key,
    required this.academy,
  });

  final Academy academy;

  @override
  Widget build(BuildContext context) {
    return AcademyDetailScreen(
      academy: academy,
      onUpdated: () {},
      onDeleted: () {},
      trainingFieldOnly: true,
    );
  }
}
