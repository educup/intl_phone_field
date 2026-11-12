import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

void main() {
  group('Peru national phone numbers', () {
    test('validates nine national digits separately from the dial code', () {
      final phone = PhoneNumber(
        countryISOCode: 'PE',
        countryCode: '+51',
        number: '912345678',
      );

      expect(phone.isValidNumber(), isTrue);
      expect(phone.completeNumber, '+51912345678');
      expect(phone.number, '912345678');
    });

    for (final completeNumber in ['+51912345678', '51912345678']) {
      test('round-trips $completeNumber without duplicating the dial code', () {
        final phone = PhoneNumber.fromCompleteNumber(
          completeNumber: completeNumber,
        );

        expect(phone.countryISOCode, 'PE');
        expect(phone.countryCode, '51');
        expect(phone.number, '912345678');
        expect(phone.completeNumber, '51912345678');
        expect(phone.isValidNumber(), isTrue);
      });
    }

    for (final number in ['91234567', '9123456789', '91234567890']) {
      test(
        'rejects ${number.length} national digits without changing them',
        () {
          final phone = PhoneNumber(
            countryISOCode: 'PE',
            countryCode: '+51',
            number: number,
          );

          expect(
            phone.isValidNumber,
            throwsA(
              number.length < 9
                  ? isA<NumberTooShortException>()
                  : isA<NumberTooLongException>(),
            ),
          );
          expect(phone.number, number);
          expect(phone.completeNumber, '+51$number');
        },
      );
    }
  });

  group('other countries retain their national lengths', () {
    for (final number in ['+12025550123', '+34612345678', '+50371234567']) {
      test('still accepts $number', () {
        final phone = PhoneNumber.fromCompleteNumber(completeNumber: number);

        expect(phone.isValidNumber(), isTrue);
      });
    }

    for (final number in ['+1202555012', '+3461234567', '+5037123456']) {
      test('still rejects short $number', () {
        final phone = PhoneNumber.fromCompleteNumber(completeNumber: number);

        expect(phone.isValidNumber, throwsA(isA<NumberTooShortException>()));
      });
    }
  });

  group('Peru field validation', () {
    for (final nationalNumber in [
      '91234567',
      '912345678',
      '9123456789',
      '91234567890',
    ]) {
      testWidgets(
        'validates ${nationalNumber.length} initial national digits',
        (tester) async {
          final form = GlobalKey<FormState>();
          PhoneNumber? savedPhone;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: form,
                  child: IntlPhoneField(
                    initialCountryCode: 'PE',
                    initialValue: nationalNumber,
                    autovalidateMode: AutovalidateMode.disabled,
                    onSaved: (phone) => savedPhone = phone,
                  ),
                ),
              ),
            ),
          );

          final valid = form.currentState!.validate();
          await tester.pump();

          expect(valid, nationalNumber.length == 9);
          // Initial values exercise validation without the keyboard formatter
          // shortening an overlong value before the validator can inspect it.
          expect(find.text(nationalNumber), findsOneWidget);
          expect(
            find.text('Invalid Mobile Number'),
            nationalNumber.length == 9 ? findsNothing : findsOneWidget,
          );
          if (valid) {
            form.currentState!.save();
            expect(savedPhone!.countryISOCode, 'PE');
            expect(savedPhone!.countryCode, '+51');
            expect(savedPhone!.number, nationalNumber);
            expect(savedPhone!.completeNumber, '+51$nationalNumber');
            expect(savedPhone!.isValidNumber(), isTrue);
          }
        },
      );
    }

    testWidgets('changing from US to Peru applies the selected country rules', (
      tester,
    ) async {
      final form = GlobalKey<FormState>();
      PhoneNumber? savedPhone;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: IntlPhoneField(
                countries: const ['US', 'PE'],
                initialCountryCode: 'US',
                initialValue: '912345678',
                autovalidateMode: AutovalidateMode.disabled,
                onSaved: (phone) => savedPhone = phone,
              ),
            ),
          ),
        ),
      );

      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peru'));
      await tester.pumpAndSettle();

      expect(find.text('+51'), findsOneWidget);
      expect(find.text('912345678'), findsOneWidget);
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      expect(savedPhone!.completeNumber, '+51912345678');
      expect(savedPhone!.isValidNumber(), isTrue);
    });
  });
}
