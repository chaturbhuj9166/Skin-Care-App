import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/question_model.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';

IconData _iconFor(String key) {
  switch (key) {
    case 'acne':
      return Icons.face_retouching_natural_rounded;
    case 'spots':
      return Icons.blur_on_rounded;
    case 'dry':
      return Icons.ac_unit_rounded;
    case 'oily':
      return Icons.opacity_rounded;
    case 'redness':
      return Icons.local_fire_department_rounded;
    case 'combo':
      return Icons.blender_rounded;
    case 'sensitive':
      return Icons.favorite_rounded;
    case 'time':
      return Icons.schedule_rounded;
    default:
      return Icons.more_horiz_rounded;
  }
}

const _optionColors = [
  AppColors.secondary,
  Color(0xFFF97316),
  Color(0xFF3B82F6),
  AppColors.primary,
  Color(0xFFEC4899),
  AppColors.textMuted,
];

class SubmitProblemScreen extends ConsumerStatefulWidget {
  const SubmitProblemScreen({super.key});

  @override
  ConsumerState<SubmitProblemScreen> createState() => _SubmitProblemScreenState();
}

class _SubmitProblemScreenState extends ConsumerState<SubmitProblemScreen> {
  int _index = 0;
  // Display-friendly answer text, keyed by question id (drives the summary view + Next-button gating).
  final Map<String, String> _answers = {};
  final Map<String, Set<String>> _multiSelections = {};
  final Map<String, int> _ratings = {};
  final Map<String, List<String>> _photoUrls = {};
  int _rating = 0;
  int _photoCount = 0;
  bool _summary = false;
  bool _submitting = false;

  void _next(List<QuestionModel> questions) {
    if (_index < questions.length - 1) {
      setState(() => _index++);
    } else {
      setState(() => _summary = true);
    }
  }

  void _back(List<QuestionModel> questions) {
    if (_summary) {
      setState(() => _summary = false);
      return;
    }
    if (_index == 0) {
      context.pop();
    } else {
      setState(() => _index--);
    }
  }

  void _toggleMultiSelect(QuestionModel question, String label) {
    setState(() {
      final set = _multiSelections.putIfAbsent(question.id, () => {});
      if (set.contains(label)) {
        set.remove(label);
      } else {
        set.add(label);
      }
      _answers[question.id] = set.isEmpty ? '' : set.join(', ');
    });
  }

  bool _uploadingPhoto = false;

  Future<void> _addPhoto(QuestionModel question) async {
    if (_photoCount >= 5 || _uploadingPhoto) return;
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

    setState(() => _uploadingPhoto = true);
    try {
      final url = await ref.read(apiRepositoryProvider).uploadFile(picked);
      if (!mounted) return;
      setState(() {
        _photoCount++;
        final urls = _photoUrls.putIfAbsent(question.id, () => []);
        urls.add(url);
        _answers[question.id] = '$_photoCount photo(s) attached';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  dynamic _rawAnswerFor(QuestionModel q) {
    switch (q.type) {
      case QuestionType.singleChoice:
      case QuestionType.text:
        return _answers[q.id];
      case QuestionType.multipleChoice:
        return _multiSelections[q.id]?.toList() ?? const [];
      case QuestionType.yesNo:
        return _answers[q.id] == 'Yes';
      case QuestionType.rating:
        return _ratings[q.id];
      case QuestionType.photo:
        return _photoUrls[q.id] ?? const [];
    }
  }

  Future<void> _submit(List<QuestionModel> questions) async {
    setState(() => _submitting = true);
    final answers = <String, dynamic>{};
    for (final q in questions) {
      final raw = _rawAnswerFor(q);
      final empty = raw == null || (raw is String && raw.isEmpty) || (raw is List && raw.isEmpty);
      if (!empty) answers[q.id] = raw;
    }
    try {
      await ref.read(apiRepositoryProvider).submitCase(answers: answers);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case submitted! A doctor will review it shortly.')),
      );
      context.pushReplacement('/cases');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(apiRepositoryProvider).questionFlow;

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
          title: const Text('Skin Analysis'),
        ),
        body: const EmptyState(
          icon: Icons.assignment_late_outlined,
          title: 'No questionnaire available',
          subtitle: 'The admin team hasn\'t set up a consultation form yet. Please check back shortly.',
        ),
      );
    }

    final progress = _summary ? 1.0 : (_index + 1) / questions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _back(questions)),
        title: const Text('Skin Analysis'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(height: 6, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_summary ? 'Review' : '${_index + 1}/${questions.length}',
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _summary
                ? _SummaryView(questions: questions, answers: _answers, photoCount: _photoCount)
                : _QuestionView(
                    key: ValueKey(_index),
                    question: questions[_index],
                    selected: _answers[questions[_index].id],
                    multiSelected: _multiSelections[questions[_index].id] ?? const {},
                    rating: _rating,
                    photoCount: _photoCount,
                    photoUrls: _photoUrls[questions[_index].id] ?? const [],
                    uploadingPhoto: _uploadingPhoto,
                    onSelect: (val) {
                      final q = questions[_index];
                      if (q.type == QuestionType.multipleChoice) {
                        _toggleMultiSelect(q, val);
                      } else {
                        setState(() => _answers[q.id] = val);
                      }
                    },
                    onRating: (r) => setState(() {
                      _rating = r;
                      _ratings[questions[_index].id] = r;
                      _answers[questions[_index].id] = '$r / 5';
                    }),
                    onAddPhoto: () => _addPhoto(questions[_index]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(label: 'Back', outlined: true, onPressed: () => _back(questions)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _summary
                        ? PrimaryButton(label: 'Submit', loading: _submitting, onPressed: () => _submit(questions))
                        : PrimaryButton(
                            label: 'Next',
                            onPressed: (questions[_index].required && _answers[questions[_index].id] == null)
                                ? null
                                : () => _next(questions),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final QuestionModel question;
  final String? selected;
  final Set<String> multiSelected;
  final int rating;
  final int photoCount;
  final List<String> photoUrls;
  final bool uploadingPhoto;
  final ValueChanged<String> onSelect;
  final ValueChanged<int> onRating;
  final VoidCallback onAddPhoto;

  const _QuestionView({
    super.key,
    required this.question,
    required this.selected,
    this.multiSelected = const {},
    required this.rating,
    required this.photoCount,
    this.photoUrls = const [],
    this.uploadingPhoto = false,
    required this.onSelect,
    required this.onRating,
    required this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey(question.id),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(question.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        if (question.type == QuestionType.text)
          TextField(
            key: ValueKey('text-${question.id}'),
            minLines: 3,
            maxLines: 5,
            controller: TextEditingController(text: selected)..selection = TextSelection.collapsed(offset: selected?.length ?? 0),
            onChanged: onSelect,
            decoration: const InputDecoration(hintText: 'Type your answer...'),
          ),
        if (question.type == QuestionType.singleChoice || question.type == QuestionType.multipleChoice)
          ...List.generate(question.options.length, (i) {
            final o = question.options[i];
            final isSelected = question.type == QuestionType.multipleChoice ? multiSelected.contains(o.label) : selected == o.label;
            final color = _optionColors[i % _optionColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onSelect(o.label),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 1.6 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                        child: Icon(_iconFor(o.icon), color: color, size: 21),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(o.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      else
                        const Icon(Icons.circle_outlined, color: AppColors.border),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: 0.05, end: 0);
          }),
        if (question.type == QuestionType.yesNo)
          Row(
            children: [
              Expanded(child: _YesNoCard(label: 'Yes', selected: selected == 'Yes', onTap: () => onSelect('Yes'))),
              const SizedBox(width: 14),
              Expanded(child: _YesNoCard(label: 'No', selected: selected == 'No', onTap: () => onSelect('No'))),
            ],
          ),
        if (question.type == QuestionType.rating)
          Center(
            child: Wrap(
              spacing: 8,
              children: List.generate(5, (i) {
                final filled = i < rating;
                return GestureDetector(
                  onTap: () => onRating(i + 1),
                  child: Icon(filled ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.accent, size: 40),
                );
              }),
            ),
          ),
        if (question.type == QuestionType.photo) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...photoUrls.map((url) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, width: 84, height: 84, fit: BoxFit.cover),
                  )),
              if (photoCount < 5)
                InkWell(
                  onTap: uploadingPhoto ? null : onAddPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                    ),
                    child: uploadingPhoto
                        ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))
                        : const Icon(Icons.add_a_photo_rounded, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Camera or Gallery · Max 5 photos', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        ],
      ],
    );
  }
}

class _YesNoCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _YesNoCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final List<QuestionModel> questions;
  final Map<String, String> answers;
  final int photoCount;
  const _SummaryView({required this.questions, required this.answers, required this.photoCount});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text('Review your answers', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Make sure everything looks correct before submitting.', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
        const SizedBox(height: 20),
        ...questions.where((q) => q.type != QuestionType.photo).map((q) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.title, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(answers[q.id] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            )),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('$photoCount photo(s) attached', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
