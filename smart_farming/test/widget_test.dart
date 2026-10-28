import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_farming/main.dart';
import 'package:smart_farming/screens/home_shell.dart';
import 'package:smart_farming/state/app_state.dart';
import 'package:smart_farming/theme/palette.dart';
import 'package:smart_farming/widgets/brand_logos.dart';

void main() {
  testWidgets('login menampilkan kedua logo dalam dark mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      const SmartFarmingApp(enableFirebase: false),
    );
    await tester.pump();

    // Logo perusahaan dan komunitas tampil di layar login.
    expect(find.byType(MikikoTechnologyLogo), findsOneWidget);
    expect(find.byType(PetaniMudaKerenLogo), findsOneWidget);

    // Tema default adalah dark mode dengan palet moodboard.
    final theme = Theme.of(tester.element(find.byType(MikikoTechnologyLogo)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.surface, Palette.ink);
    expect(theme.colorScheme.primary, Palette.sage);
    expect(theme.colorScheme.secondary, Palette.rust);
  });

  testWidgets('login demo membawa pengguna ke dasbor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const SmartFarmingApp(enableFirebase: false),
    );
    await tester.pump();

    expect(find.text('Masuk cepat sebagai demo'), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);

    await tester.tap(find.text('Masuk cepat sebagai demo'));
    await tester.pump();

    // Hentikan simulasi live agar test tidak menunggu timer.
    final context = tester.element(find.byType(HomeShell));
    Provider.of<AppState>(context, listen: false).stopLive();
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Skor Kesehatan Lahan'), findsOneWidget);
    expect(find.text('Monitor Sensor'), findsOneWidget);
    expect(find.text('Kelembapan Tanah'), findsWidgets);
  });

  testWidgets('navigasi bawah membuka tab irigasi', (WidgetTester tester) async {
    await tester.pumpWidget(
      const SmartFarmingApp(enableFirebase: false),
    );
    await tester.pump();

  await tester.tap(find.text('Masuk cepat sebagai demo'));
  await tester.tap(find.text('Masuk cepat sebagai demo'));
  await tester.pumpAndSettle();

  expect(
    find.byType(HomeShell),
    findsOneWidget,
    reason: 'HomeShell belum muncul setelah tombol demo ditekan',
  );

  expect(
    find.byType(HomeShell),
    findsOneWidget,
    reason: 'HomeShell belum muncul setelah tombol demo ditekan',
  );
    final context = tester.element(find.byType(HomeShell));
    Provider.of<AppState>(context, listen: false).stopLive();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Irigasi'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kontrol Manual'), findsOneWidget);
    expect(find.text('Irigasi Otomatis'), findsOneWidget);
  });
}
