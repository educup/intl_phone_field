import 'package:intl_phone_field/countries.dart';

bool isNumeric(String s) => s.isNotEmpty && double.tryParse(s) != null;

extension CountryExtensions on List<Country> {
  List<Country> stringSearch(String search) {
    return where(
      (country) => isNumeric(search)
          ? country.dialCode.contains(search.replaceAll('+', ''))
          : country.name.toLowerCase().contains(search.toLowerCase()) ||
              country.nameTranslations.values.any(
                (element) =>
                    element.toLowerCase().contains(search.toLowerCase()),
              ),
    ).toList();
  }
}
