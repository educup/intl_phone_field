import 'package:intl_phone_field/countries.dart';

class NumberTooLongException implements Exception {}

class NumberTooShortException implements Exception {}

class InvalidCharactersException implements Exception {}

class PhoneNumber {

  PhoneNumber({
    required this.countryISOCode,
    required this.countryCode,
    required this.number,
  });

  factory PhoneNumber.fromCompleteNumber({required String completeNumber}) {
    if (completeNumber == '') {
      return PhoneNumber(countryISOCode: '', countryCode: '', number: '');
    }

    try {
      final Country country = getCountry(completeNumber);
      String number;
      if (completeNumber.startsWith('+')) {
        number = completeNumber
            .substring(1 + country.dialCode.length + country.regionCode.length);
      } else {
        number = completeNumber
            .substring(country.dialCode.length + country.regionCode.length);
      }
      return PhoneNumber(
          countryISOCode: country.code,
          countryCode: country.dialCode + country.regionCode,
          number: number,);
    } on InvalidCharactersException {
      rethrow;
    } on Exception catch (_) {
      return PhoneNumber(countryISOCode: '', countryCode: '', number: '');
    }
  }
  String countryISOCode;
  String countryCode;
  String number;

  bool isValidNumber() {
    final Country country = getCountry(completeNumber);
    if (number.length < country.minLength) {
      throw NumberTooShortException();
    }

    if (number.length > country.maxLength) {
      throw NumberTooLongException();
    }
    return true;
  }

  String get completeNumber {
    return countryCode + number;
  }

  static Country getCountry(String phoneNumber) {
    if (phoneNumber == '') {
      throw NumberTooShortException();
    }

    final validPhoneNumber = RegExp(r'^[+0-9]*[0-9]*$');

    if (!validPhoneNumber.hasMatch(phoneNumber)) {
      throw InvalidCharactersException();
    }

    if (phoneNumber.startsWith('+')) {
      return countries.firstWhere(
        (country) => phoneNumber.substring(1).startsWith(
              country.dialCode + country.regionCode,
            ),
      );
    }
    return countries.firstWhere((country) =>
        phoneNumber.startsWith(country.dialCode + country.regionCode),);
  }

  @override
  String toString() =>
      'PhoneNumber(countryISOCode: $countryISOCode, countryCode: $countryCode, number: $number)';
}
