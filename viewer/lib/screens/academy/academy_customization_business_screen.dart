import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/widgets/academy/academy_customization_business_sections.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class AcademyCustomizationBusinessScreen extends StatefulWidget {
  const AcademyCustomizationBusinessScreen({
    super.key,
    required this.academy,
  });

  final Academy academy;

  @override
  State<AcademyCustomizationBusinessScreen> createState() =>
      _AcademyCustomizationBusinessScreenState();
}

class _AcademyCustomizationBusinessScreenState
    extends State<AcademyCustomizationBusinessScreen> {
  late Academy _academy;

  @override
  void initState() {
    super.initState();
    _academy = widget.academy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Personalização e Negócios',
        subtitle: _academy.name,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Por enquanto, a seção já atualiza localmente após salvar/upload.
          // Mantemos o gesto de pull-to-refresh para consistência visual.
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppTheme.screenPadding(context)),
          child: AcademyCustomizationBusinessSections(
            academy: _academy,
            onUpdated: () => setState(() {}),
          ),
        ),
      ),
    );
  }
}

