import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skincare_app/data/api/api_repository.dart';
import 'package:skincare_app/data/models/case_model.dart';
import 'package:skincare_app/data/models/doctor_model.dart';
import 'package:skincare_app/features/doctor/doctor_cases_screen.dart';
import 'package:skincare_app/features/doctor/doctor_dashboard_screen.dart';

CaseModel _case(String id, CaseStatus status) => CaseModel(
      id: id,
      caseNumber: 'SKC-${id.toUpperCase()}',
      submittedAt: DateTime(2026, 9, 1),
      status: status,
      mainConcern: 'Acne',
      answers: const [],
      photoAssets: const [],
    );

ApiRepository _repoWith(List<CaseModel> cases) {
  final repo = ApiRepository();
  repo.currentDoctor = const DoctorModel(
    id: 'd1',
    name: 'Dr. Test',
    specialization: 'Dermatology',
    experienceYears: 5,
    rating: 0,
    reviewCount: 0,
    isOnline: true,
    avatarSeed: 1,
  );
  repo.cases.addAll(cases);
  return repo;
}

Widget _wrap(ApiRepository repo, Widget child) => ProviderScope(
      overrides: [apiRepositoryProvider.overrideWith((ref) => repo)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  // One case the doctor solved that the admin later closed, one still solved.
  final cases = [_case('closed1', CaseStatus.closed), _case('solved1', CaseStatus.solved)];

  testWidgets('Solved tab keeps cases after admin closes them', (tester) async {
    await tester.pumpWidget(_wrap(_repoWith(cases), const DoctorCasesScreen()));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Solved'));
    await tester.pumpAndSettle();

    expect(find.text('SKC-CLOSED1'), findsOneWidget);
    expect(find.text('SKC-SOLVED1'), findsOneWidget);
  });

  testWidgets('Dashboard Solved count includes closed cases', (tester) async {
    // Wide logical viewport: the test font renders every glyph as a full square.
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_repoWith(cases), const DoctorDashboardScreen()));
    await tester.pump(const Duration(seconds: 2));

    final solvedCard = find.ancestor(of: find.text('Solved'), matching: find.byType(Column)).first;
    expect(find.descendant(of: solvedCard, matching: find.text('2')), findsOneWidget);
  });
}
