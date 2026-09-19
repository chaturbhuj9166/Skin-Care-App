import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/solution_model.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';

class _PrescriptionRow {
  final medicineController = TextEditingController();
  final instructionController = TextEditingController();
  final durationController = TextEditingController();
}

class WriteSolutionScreen extends ConsumerStatefulWidget {
  final String caseId;
  const WriteSolutionScreen({super.key, required this.caseId});

  @override
  ConsumerState<WriteSolutionScreen> createState() => _WriteSolutionScreenState();
}

class _WriteSolutionScreenState extends ConsumerState<WriteSolutionScreen> {
  final _diagnosisController = TextEditingController();
  final _noteController = TextEditingController();
  final List<_PrescriptionRow> _rows = [_PrescriptionRow()];
  DateTime? _followUpDate;
  bool _submitting = false;
  bool _previewing = false;
  bool _attaching = false;
  String? _attachmentUrl;
  String? _attachmentName;

  void _addRow() => setState(() => _rows.add(_PrescriptionRow()));

  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  Future<void> _pickFollowUp() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 28)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _followUpDate = date);
  }

  Future<void> _attachFile() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _attaching = true);
    try {
      final url = await ref.read(apiRepositoryProvider).uploadFile(picked);
      if (!mounted) return;
      setState(() {
        _attachmentUrl = url;
        _attachmentName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  List<PrescriptionItem> get _prescription => _rows
      .where((r) => r.medicineController.text.trim().isNotEmpty)
      .map((r) => PrescriptionItem(
            medicine: r.medicineController.text.trim(),
            instruction: r.instructionController.text.trim(),
            duration: r.durationController.text.trim(),
          ))
      .toList();

  void _goToPreview() {
    if (_diagnosisController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a diagnosis')));
      return;
    }
    setState(() => _previewing = true);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(apiRepositoryProvider).submitSolution(
            caseId: widget.caseId,
            solution: SolutionModel(
              diagnosis: _diagnosisController.text.trim(),
              prescription: _prescription,
              note: _noteController.text.trim().isEmpty ? 'Keep the skin clean and avoid harsh products.' : _noteController.text.trim(),
              issuedAt: DateTime.now(),
              followUpDate: _followUpDate,
              attachmentUrl: _attachmentUrl,
            ),
          );
      if (!mounted) return;
      context.pop();
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_previewing) return _buildPreview(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Write Solution')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _diagnosisController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'e.g. Mild to Moderate Acne'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prescription', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              TextButton.icon(onPressed: _addRow, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add')),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_rows.length, (i) {
            final row = _rows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(controller: row.medicineController, decoration: const InputDecoration(hintText: 'Medicine name', isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: row.instructionController, decoration: const InputDecoration(hintText: 'Dosage / instruction', isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: row.durationController, decoration: const InputDecoration(hintText: 'Duration (e.g. 2 weeks)', isDense: true)),
                      ],
                    ),
                  ),
                  if (_rows.length > 1)
                    IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 18), onPressed: () => _removeRow(i)),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text('Follow-up Date (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickFollowUp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: AppColors.textLight, size: 18),
                  const SizedBox(width: 10),
                  Text(_followUpDate == null ? 'Select a date' : DateFormat('dd MMM yyyy').format(_followUpDate!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Note for patient', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(controller: _noteController, maxLines: 3, decoration: const InputDecoration(hintText: 'Avoid oily products and keep your skin clean.')),
          const SizedBox(height: 20),
          const Text('Attachment (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _attaching ? null : _attachFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  if (_attaching)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                  else
                    Icon(_attachmentUrl == null ? Icons.attach_file_rounded : Icons.check_circle_rounded,
                        color: _attachmentUrl == null ? AppColors.textLight : AppColors.secondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_attachmentName ?? 'Attach a file', overflow: TextOverflow.ellipsis)),
                  if (_attachmentUrl != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      onPressed: () => setState(() {
                        _attachmentUrl = null;
                        _attachmentName = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Preview', onPressed: _goToPreview),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Preview Solution'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => _previewing = false)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Diagnosis', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(_diagnosisController.text.trim(), style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 18),
          Text('Prescription', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (_prescription.isEmpty)
            const Text('No medicines added', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            ..._prescription.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${p.medicine} — ${p.instruction}${p.duration.isNotEmpty ? ' · ${p.duration}' : ''}',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                )),
          if (_followUpDate != null) ...[
            const SizedBox(height: 12),
            Text('Follow-up Date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(DateFormat('dd MMM yyyy').format(_followUpDate!), style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 12),
          Text('Note for patient', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            _noteController.text.trim().isEmpty ? 'Keep the skin clean and avoid harsh products.' : _noteController.text.trim(),
            style: const TextStyle(fontSize: 14),
          ),
          if (_attachmentName != null) ...[
            const SizedBox(height: 12),
            Text('Attachment', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(_attachmentName!, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 28),
          PrimaryButton(label: 'Confirm & Submit', loading: _submitting, onPressed: _submit),
        ],
      ),
    );
  }
}
