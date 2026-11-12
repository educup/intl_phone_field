import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text']! as String;
          return null;
        case 'Clipboard.getData':
          return {'text': clipboardText};
        case 'Clipboard.hasStrings':
          return {'value': clipboardText?.isNotEmpty ?? false};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final paste in [false, true]) {
    for (final number in [
      '91234567',
      '912345678',
      '9123456789',
      '91234567890',
    ]) {
      testWidgets(
        '${paste ? 'pasting' : 'typing'} ${number.length} Peru digits preserves '
        'the input and validates its actual length',
        (tester) async {
          final form = GlobalKey<FormState>();
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          final changed = <PhoneNumber>[];
          PhoneNumber? saved;

          await tester.pumpWidget(
            _phoneForm(
              form: form,
              controller: controller,
              country: 'PE',
              onChanged: changed.add,
              onSaved: (phone) => saved = phone,
            ),
          );

          await _enterNumber(tester, number, paste: paste);

          expect(controller.text, number);
          expect(find.text(number), findsOneWidget);
          expect(changed, isNotEmpty);
          expect(changed.last.countryISOCode, 'PE');
          expect(changed.last.countryCode, '+51');
          expect(changed.last.number, number);
          expect(changed.last.completeNumber, '+51$number');
          expect(form.currentState!.validate(), number.length == 9);
          await tester.pump();
          expect(
            find.text('Invalid Mobile Number'),
            number.length == 9 ? findsNothing : findsOneWidget,
          );
          if (number.length == 9) {
            form.currentState!.save();
            expect(saved!.number, number);
            expect(saved!.completeNumber, '+51$number');
            expect(saved!.isValidNumber(), isTrue);
          }
        },
      );
    }
  }

  testWidgets('switching US and Peru retains the text and rechecks its length',
      (tester) async {
    final form = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changed = <PhoneNumber>[];

    await tester.pumpWidget(
      _phoneForm(
        form: form,
        controller: controller,
        country: 'US',
        onChanged: changed.add,
      ),
    );

    await _enterNumber(tester, '9123456789', paste: false);
    expect(form.currentState!.validate(), isTrue);
    await _selectCountry(tester, '+1', 'Peru');
    expect(controller.text, '9123456789');
    expect(form.currentState!.validate(), isFalse);

    await _enterNumber(tester, '91234567890', paste: true);
    expect(controller.text, '91234567890');
    expect(changed.last.completeNumber, '+5191234567890');
    expect(form.currentState!.validate(), isFalse);

    await _selectCountry(tester, '+51', 'United States');
    expect(controller.text, '91234567890');
    expect(form.currentState!.validate(), isFalse);
    await _enterNumber(tester, '9123456789', paste: true);
    expect(controller.text, '9123456789');
    expect(form.currentState!.validate(), isTrue);

    await _selectCountry(tester, '+1', 'Peru');
    expect(controller.text, '9123456789');
    expect(form.currentState!.validate(), isFalse);
    await _enterNumber(tester, '912345678', paste: false);
    expect(form.currentState!.validate(), isTrue);
    expect(changed.last.completeNumber, '+51912345678');
  });

  for (final country in [
    (code: 'US', dial: '+1', length: 10),
    (code: 'ES', dial: '+34', length: 9),
    (code: 'SV', dial: '+503', length: 8),
  ]) {
    testWidgets('${country.code} retains its existing input length enforcement',
        (tester) async {
      final form = GlobalKey<FormState>();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changed = <PhoneNumber>[];
      const overlong = '912345678901';
      final expected = overlong.substring(0, country.length);

      await tester.pumpWidget(
        _phoneForm(
          form: form,
          controller: controller,
          country: country.code,
          onChanged: changed.add,
        ),
      );
      await _enterNumber(tester, overlong, paste: true);

      expect(controller.text, expected);
      expect(changed.last.number, expected);
      expect(changed.last.completeNumber, '${country.dial}$expected');
      expect(form.currentState!.validate(), isTrue);
    });
  }
}

Widget _phoneForm({
  required GlobalKey<FormState> form,
  required TextEditingController controller,
  required String country,
  ValueChanged<PhoneNumber>? onChanged,
  FormFieldSetter<PhoneNumber>? onSaved,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Form(
        key: form,
        child: IntlPhoneField(
          countries: const ['US', 'PE', 'ES', 'SV'],
          controller: controller,
          initialCountryCode: country,
          autovalidateMode: AutovalidateMode.disabled,
          onChanged: onChanged,
          onSaved: onSaved,
        ),
      ),
    ),
  );
}

Future<void> _enterNumber(
  WidgetTester tester,
  String number, {
  required bool paste,
}) async {
  final field = find.byType(TextField);
  if (paste) {
    await tester.showKeyboard(field);
    await Clipboard.setData(ClipboardData(text: number));
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    editable.selectAll(SelectionChangedCause.toolbar);
    await editable.pasteText(SelectionChangedCause.toolbar);
    await tester.pump();
  } else {
    await tester.enterText(field, '');
    for (var length = 1; length <= number.length; length++) {
      await tester.enterText(field, number.substring(0, length));
      await tester.pump();
    }
  }
}

Future<void> _selectCountry(
  WidgetTester tester,
  String currentDial,
  String country,
) async {
  await tester.tap(find.text(currentDial));
  await tester.pumpAndSettle();
  await tester.tap(find.text(country));
  await tester.pumpAndSettle();
}
