import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrify/main.dart';
import 'package:qrify/models/history_item.dart';
import 'package:qrify/screens/barcode_generator_screen.dart';
import 'package:qrify/screens/history_screen.dart';
import 'package:qrify/screens/home_screen.dart';
import 'package:qrify/screens/qr_generator_screen.dart';
import 'package:qrify/screens/result_screen.dart';
import 'package:qrify/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Common phone sizes (logical): normal and a small one to catch overflows.
const _sizes = {
  'normal': Size(1080, 2400), // 360x800 @3x
  'small': Size(960, 1600), // 320x533 @3x
};

Future<void> _setSize(WidgetTester t, Size physical) async {
  t.view.physicalSize = physical;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Widget _app(Widget home, {bool dark = true}) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    );

Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text).first;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

HistoryItem _item(String content,
        {ScanType type = ScanType.qrCode,
        ActionType action = ActionType.scanned,
        String? format}) =>
    HistoryItem(
      id: content.hashCode.toString(),
      content: content,
      scanType: type,
      actionType: action,
      barcodeFormat: format,
      createdAt: DateTime.now(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ─── Model / parsing ───────────────────────────────────────────────────────
  group('QrPayload', () {
    test('WiFi fields with escaped characters', () {
      const c = r'WIFI:T:WPA;S:My\;Net\:5G;P:pa\\ss\,word;;';
      expect(QrPayload.wifiField(c, 'S'), 'My;Net:5G');
      expect(QrPayload.wifiField(c, 'P'), r'pa\ss,word');
      expect(QrPayload.wifiField(c, 'T'), 'WPA');
    });

    test('open WiFi has no password', () {
      const c = 'WIFI:T:nopass;S:Cafe;;';
      expect(QrPayload.wifiField(c, 'S'), 'Cafe');
      expect(QrPayload.wifiField(c, 'P'), '');
    });

    test('vCard fields', () {
      const c = 'BEGIN:VCARD\nVERSION:3.0\nN:;Doe\\, John;;;\nFN:Doe\\, John\n'
          'TEL;TYPE=CELL:+880123\nEMAIL:a@b.com\nEND:VCARD';
      expect(QrPayload.vcardField(c, 'FN'), 'Doe, John');
      expect(QrPayload.vcardField(c, 'TEL'), '+880123');
      expect(QrPayload.vcardField(c, 'EMAIL'), 'a@b.com');
    });
  });

  group('HistoryItem', () {
    test('category + title detection', () {
      expect(_item('https://google.com/x').category, ContentCategory.url);
      expect(_item('https://google.com/x').displayTitle, 'google.com');
      expect(_item('mailto:a@b.com').displayTitle, 'a@b.com');
      expect(_item('tel:+880').displayTitle, '+880');
      expect(_item('WIFI:T:WPA;S:Home;P:12345678;;').displayTitle, 'Home');
      expect(_item('SMSTO:+8801:hello').category, ContentCategory.sms);
      expect(_item('SMSTO:+8801:hello').displayTitle, '+8801');
      expect(_item('5901234123457').category, ContentCategory.barcode);
      expect(_item('hello').category, ContentCategory.text);
    });

    test('HistoryService add / dedupe / favorite / delete', () async {
      await HistoryService.add(
          content: 'a',
          scanType: ScanType.qrCode,
          actionType: ActionType.scanned);
      await HistoryService.add(
          content: 'a',
          scanType: ScanType.qrCode,
          actionType: ActionType.scanned);
      var all = await HistoryService.getAll();
      expect(all.length, 1);
      await HistoryService.toggleFavorite(all.first.id);
      all = await HistoryService.getAll();
      expect(all.first.isFavorite, isTrue);
      await HistoryService.delete(all.first.id);
      expect(await HistoryService.getAll(), isEmpty);
    });

    test('corrupt history entry does not crash', () async {
      SharedPreferences.setMockInitialValues({
        'history_items': ['not json', '{"bad":1}']
      });
      expect(await HistoryService.getAll(), isEmpty);
    });
  });

  // ─── App start ─────────────────────────────────────────────────────────────
  testWidgets('splash → home, theme toggle persists', (t) async {
    await _setSize(t, _sizes['normal']!);
    await themeProvider.load();
    await t.pumpWidget(const QRifyApp());
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('QR Scanner'), findsOneWidget);

    expect(themeProvider.isDark, isTrue);
    await t.tap(find.byIcon(Icons.light_mode_rounded));
    await t.pumpAndSettle();
    expect(themeProvider.isDark, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('is_dark_theme'), isFalse);
    themeProvider.setDark(true);
    await t.pumpAndSettle();
  });

  // ─── Every screen renders without overflow, both themes, both sizes ───────
  for (final entry in _sizes.entries) {
    for (final dark in [true, false]) {
      final tag = '${entry.key}/${dark ? 'dark' : 'light'}';

      testWidgets('home renders [$tag]', (t) async {
        SharedPreferences.setMockInitialValues({});
        await HistoryService.add(
            content: 'https://example.com/a-very-long-path-that-keeps-going',
            scanType: ScanType.qrCode,
            actionType: ActionType.scanned);
        await _setSize(t, entry.value);
        await t.pumpWidget(_app(const HomeScreen(), dark: dark));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('RECENT'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('RECENT'), findsOneWidget);
        await t.tap(find.text('History').last);
        await t.pumpAndSettle();
        expect(find.text('1 total'), findsOneWidget);
      });

      testWidgets('QR generator all types [$tag]', (t) async {
        await _setSize(t, entry.value);
        await t.pumpWidget(_app(const QRGeneratorScreen(), dark: dark));
        await t.pumpAndSettle();
        for (final type in [
          'URL',
          'Text',
          'Contact',
          'WiFi',
          'Email',
          'Phone'
        ]) {
          await t.ensureVisible(find.text(type).first);
          await t.tap(find.text(type).first);
          await t.pumpAndSettle();
          expect(find.byType(TextFormField), findsWidgets);
        }
      });

      testWidgets('barcode generator all formats [$tag]', (t) async {
        await _setSize(t, entry.value);
        await t.pumpWidget(_app(const BarcodeGeneratorScreen(), dark: dark));
        await t.pumpAndSettle();
        const valid = {
          'EAN-13': '590123412345',
          'EAN-8': '9638507',
          'Code 128': 'ABC-12345',
          'Code 39': 'HELLO',
          'UPC-A': '01234567890',
          'PDF417': 'hello pdf',
        };
        for (final e in valid.entries) {
          await _tapText(t, e.key);
          await t.enterText(find.byType(TextFormField), e.value);
          await _tapText(t, 'Generate Barcode');
          expect(find.byType(BarcodeWidget), findsOneWidget,
              reason: '${e.key} should generate');
        }
      });

      testWidgets('result screen every category [$tag]', (t) async {
        await _setSize(t, entry.value);
        final items = [
          _item('https://flutter.dev'),
          _item('mailto:hello@example.com'),
          _item('tel:+8801700000000'),
          _item('WIFI:T:WPA;S:Home Network;P:supersecret;;'),
          _item('WIFI:T:nopass;S:Cafe;;'),
          _item(
              'BEGIN:VCARD\nVERSION:3.0\nFN:John Doe\nTEL:+880\nEMAIL:j@d.com\nEND:VCARD'),
          _item('SMSTO:+8801700000000:Hi there'),
          _item('5901234123457', type: ScanType.barcode, format: 'ean13'),
          _item('Just some plain text ' * 20, action: ActionType.generated),
        ];
        for (final it in items) {
          await t.pumpWidget(
              _app(ResultScreen(key: UniqueKey(), item: it), dark: dark));
          await t.pumpAndSettle();
          expect(find.text('Copy'), findsOneWidget);
        }
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 2));
      });
    }
  }

  // ─── Behaviour ─────────────────────────────────────────────────────────────
  testWidgets('invalid barcode never shows a preview (nothing to save)',
      (t) async {
    await _setSize(t, _sizes['normal']!);
    await t.pumpWidget(_app(const BarcodeGeneratorScreen()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'ABC');
    await _tapText(t, 'Generate Barcode');
    expect(find.byType(BarcodeWidget), findsNothing);
    expect(find.textContaining('EAN-13 needs 12 digits'), findsWidgets);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('editing data hides stale barcode preview', (t) async {
    await _setSize(t, _sizes['normal']!);
    await t.pumpWidget(_app(const BarcodeGeneratorScreen()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), '590123412345');
    await _tapText(t, 'Generate Barcode');
    expect(find.byType(BarcodeWidget), findsOneWidget);
    await t.enterText(find.byType(TextFormField), '59012341234X');
    await t.pumpAndSettle();
    expect(find.byType(BarcodeWidget), findsNothing);
  });

  testWidgets('too-long QR text shows error toast, no preview', (t) async {
    await _setSize(t, _sizes['normal']!);
    await t.pumpWidget(_app(const QRGeneratorScreen(initialType: 'Text')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'x' * 3500);
    await _tapText(t, 'Generate QR Code');
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('too long'), findsOneWidget);
  });

  testWidgets('QR URL generates and adds https scheme', (t) async {
    await _setSize(t, _sizes['normal']!);
    await t.pumpWidget(_app(const QRGeneratorScreen()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'httpbin.org');
    await _tapText(t, 'Generate QR Code');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('https://httpbin.org'), findsOneWidget);
  });

  testWidgets('WiFi WPA requires 8+ char password; open network works',
      (t) async {
    await _setSize(t, _sizes['normal']!);
    await t.pumpWidget(_app(const QRGeneratorScreen(initialType: 'WiFi')));
    await t.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Home;Net');
    await t.enterText(fields.at(1), '123');
    await _tapText(t, 'Generate QR Code');
    expect(find.textContaining('at least 8'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    await _tapText(t, 'None');
    await _tapText(t, 'Generate QR Code');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(r'WIFI:T:nopass;S:Home\;Net;;'), findsOneWidget);
  });

  testWidgets('toast replaces previous one immediately', (t) async {
    await _setSize(t, _sizes['normal']!);
    await t.pumpWidget(_app(ResultScreen(item: _item('hello'))));
    await t.pumpAndSettle();
    await t.tap(find.text('Copy'));
    await t.pump();
    await t.tap(find.text('Copy'));
    await t.pump(const Duration(milliseconds: 50));
    // Only one toast on screen, no waiting in a queue
    expect(find.text('Copied to clipboard!'), findsOneWidget);
  });

  testWidgets('history: filter, search, swipe delete, clear', (t) async {
    await _setSize(t, _sizes['normal']!);
    await HistoryService.add(
        content: 'https://one.com',
        scanType: ScanType.qrCode,
        actionType: ActionType.scanned);
    await HistoryService.add(
        content: '5901234123457',
        scanType: ScanType.barcode,
        actionType: ActionType.generated);
    await t.pumpWidget(_app(const HistoryScreen()));
    await t.pumpAndSettle();
    expect(find.text('2 total'), findsOneWidget);

    await t.tap(find.text('Barcode').first);
    await t.pumpAndSettle();
    expect(find.text('one.com'), findsNothing);
    await t.dragUntilVisible(
        find.text('Saved'), find.byType(ListView).first, const Offset(-120, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('Saved'));
    await t.pumpAndSettle();
    expect(find.text('Nothing here'), findsOneWidget);
    await t.dragUntilVisible(
        find.text('All'), find.byType(ListView).first, const Offset(120, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('All'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'one');
    await t.pumpAndSettle();
    expect(find.text('one.com'), findsOneWidget);
    expect(find.text('5901234123457'), findsNothing);
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();

    await t.drag(find.text('one.com'), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('one.com'), findsNothing);
    expect(find.text('1 total'), findsOneWidget);
    expect((await HistoryService.getAll()).length, 1);

    await t.tap(find.text('Clear'));
    await t.pumpAndSettle();
    await t.tap(find.text('Clear All'));
    await t.pumpAndSettle();
    expect(find.text('No history yet'), findsOneWidget);
  });

  testWidgets('back on History tab returns Home without exit dialog',
      (t) async {
    await _setSize(t, _sizes['normal']!);
    await t.pumpWidget(_app(const HomeScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('History').last);
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Exit QRify?'), findsNothing);
    expect(find.text('FEATURES'), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Exit QRify?'), findsOneWidget);
  });
}
