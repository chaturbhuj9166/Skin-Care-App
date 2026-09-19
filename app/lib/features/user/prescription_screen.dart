import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/not_found_scaffold.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/case_model.dart';
import '../../data/models/solution_model.dart';
import '../../data/api/api_repository.dart';

class PrescriptionScreen extends ConsumerWidget {
  final String caseId;
  const PrescriptionScreen({super.key, required this.caseId});

  Future<void> _downloadPdf(BuildContext context, CaseModel c, SolutionModel solution) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pwContext) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SkinCare', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A7C6E))),
            pw.SizedBox(height: 4),
            pw.Text('Prescription · ${DateFormat('dd MMM yyyy').format(solution.issuedAt)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),
            pw.Text(c.doctor?.name ?? 'Doctor', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (c.doctor?.specialization != null) pw.Text(c.doctor?.specialization ?? '', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            pw.Text('DIAGNOSIS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(solution.diagnosis, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('PRESCRIPTION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...solution.prescription.map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text('${p.medicine} — ${p.instruction}${p.duration.isNotEmpty ? ' (${p.duration})' : ''}', style: const pw.TextStyle(fontSize: 12)),
                )),
            if (solution.followUpDate != null) ...[
              pw.SizedBox(height: 12),
              pw.Text('FOLLOW UP', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(DateFormat('dd MMM yyyy').format(solution.followUpDate!), style: const pw.TextStyle(fontSize: 12)),
            ],
            pw.SizedBox(height: 16),
            pw.Text(solution.note, style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'prescription-${c.caseNumber}.pdf');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    CaseModel? found;
    for (final item in repo.cases) {
      if (item.id == caseId) {
        found = item;
        break;
      }
    }
    if (found == null || found.solution == null) {
      return const NotFoundScaffold(title: 'Prescription not found', message: 'This prescription is no longer available.');
    }
    final c = found;
    final solution = c.solution!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Prescription')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      child: Image.asset('assets/images/logo_icon.jpg', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 8),
                    const Text('SkinCare', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary)),
                    const Spacer(),
                    Text(DateFormat('dd MMM yyyy').format(solution.issuedAt), style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                  ],
                ),
                const Divider(height: 28),
                Text(c.doctor?.name ?? 'Doctor', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(c.doctor?.specialization ?? '', style: const TextStyle(color: AppColors.textLight, fontSize: 12.5)),
                const SizedBox(height: 20),
                const Text('DIAGNOSIS', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const SizedBox(height: 6),
                Text(solution.diagnosis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 20),
                const Text('PRESCRIPTION', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const SizedBox(height: 8),
                ...List.generate(solution.prescription.length, (i) {
                  final p = solution.prescription[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
                              children: [
                                TextSpan(text: p.medicine, style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' – ${p.instruction}${p.duration.isNotEmpty ? ' · ${p.duration}' : ''}'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (solution.followUpDate != null) ...[
                  const SizedBox(height: 12),
                  const Text('FOLLOW UP', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Text('After 4 weeks (${DateFormat('dd MMM yyyy').format(solution.followUpDate!)})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ],
                if (solution.attachmentUrl != null) ...[
                  const SizedBox(height: 12),
                  const Text('ATTACHMENT', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(solution.attachmentUrl!, height: 140, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(solution.note, style: const TextStyle(fontSize: 12.5, height: 1.4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Download Prescription',
            icon: Icons.download_rounded,
            onPressed: () => _downloadPdf(context, c, solution),
          ),
        ],
      ),
    );
  }
}
