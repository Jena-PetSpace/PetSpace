import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/my/presentation/widgets/my_pet_summary_section.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

void main() {
  testWidgets('펫 0마리(빈 상태) 섹션이 좁은 높이에서도 오버플로우 없이 렌더된다',
      (tester) async {
    final petBloc = MockPetBloc();
    whenListen(
      petBloc,
      const Stream<PetState>.empty(),
      initialState: const PetLoaded(pets: [], selectedPet: null),
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            // MY 탭 고정 영역에서 남는 공간을 모사한 좁은 컨테이너
            body: SizedBox(
              height: 200,
              child: BlocProvider<PetBloc>.value(
                value: petBloc,
                child: const MyPetSummarySection(userId: 'u-1'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // RenderFlex overflow 등 레이아웃 예외가 없어야 한다.
    expect(tester.takeException(), isNull);
    expect(find.text('내 반려동물'), findsOneWidget);
  });
}
