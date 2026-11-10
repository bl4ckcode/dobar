import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/session/shell_session.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:barz/features/cart/presentation/bloc/cart_state.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/ui/shell/wireframe_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCart extends Mock implements CartBloc {}

class _MockLocation extends Mock implements LocationCubit {}

class _Probe extends StatefulWidget {
  final String name;
  final List<String> log;
  const _Probe(this.name, this.log);

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init:${widget.name}'); // stands in for requests/listeners
  }

  @override
  void dispose() {
    widget.log.add('dispose:${widget.name}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [for (var i = 0; i < 60; i++) Text('${widget.name} $i')],
  );
}

void main() {
  late List<String> log;
  late ShellSession session;

  setUp(() async {
    log = [];
    session = ShellSession();
    await getItInjector.reset();
    getItInjector.registerSingleton<ShellSession>(session);
    final cart = _MockCart();
    when(() => cart.state).thenReturn(const CartState.initial());
    when(() => cart.stream).thenAnswer((_) => const Stream<CartState>.empty());
    when(() => cart.close()).thenAnswer((_) async {});
    getItInjector.registerSingleton<CartBloc>(cart);
  });
  tearDown(() => getItInjector.reset());

  Future<void> pumpShell(WidgetTester tester) async {
    final location = _MockLocation();
    when(() => location.state).thenReturn(const LocationState());
    when(() => location.restoreIfGranted()).thenAnswer((_) async {});
    when(
      () => location.stream,
    ).thenAnswer((_) => const Stream<LocationState>.empty());
    when(() => location.close()).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: getBarzLightTheme(),
        home: BlocProvider<LocationCubit>.value(
          value: location,
          child: WireframeShell(
            tabBuilders: {
              0: (_) => _Probe('home', log),
              1: (_) => _Probe('find', log),
              3: (_) => _Probe('profile', log),
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> done(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }

  testWidgets('Home entry mounts only Home', (tester) async {
    await pumpShell(tester);
    expect(log, ['init:home']);
    await done(tester);
  });

  testWidgets(
    'switching tabs disposes the hidden tab and mounts the selected one',
    (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pump();
      await tester.pump();
      expect(log, containsAll(['init:home', 'init:find', 'dispose:home']));
      expect(log.where((e) => e == 'init:profile'), isEmpty);
      expect(find.text('home 0'), findsNothing);
      await done(tester);
    },
  );

  testWidgets('scroll offset of the leaving tab is restored on return', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    await tester.pump();
    expect(session.scrollOffsets[0], greaterThan(0));
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    await tester.pump();
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(
      list.controller ??
          PrimaryScrollController.of(tester.element(find.byType(ListView))),
      isNotNull,
    );
    final pos = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(pos, session.scrollOffsets[0]);
    await done(tester);
  });
}
