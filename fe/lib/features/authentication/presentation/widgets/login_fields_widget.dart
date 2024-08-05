import 'package:barz/shared/presentation/widget/barz_black_elevated_button.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class LoginFieldsWidget extends StatefulWidget {
  const LoginFieldsWidget({super.key});

  @override
  State<LoginFieldsWidget> createState() => _LoginFieldsWidgetState();
}

class _LoginFieldsWidgetState extends State<LoginFieldsWidget> {
  final phoneNumber = PhoneNumber(dialCode: '+55', isoCode: "BR");

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24),
      child: Column(
        children: [
          InternationalPhoneNumberInput(
            initialValue: phoneNumber,
            hintText: '(XX) XXXXX-XXXX',
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            formatInput: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            onInputChanged: (PhoneNumber number) {},
            selectorConfig: const SelectorConfig(
              selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
              leadingPadding: 24,
              trailingSpace: false,
              setSelectorButtonAsPrefixIcon: true,
              useEmoji: true,
            ),
            ignoreBlank: false,
            autoValidateMode: AutovalidateMode.onUserInteraction,
            onSaved: (PhoneNumber number) {},
          ),
          Container(
            padding: const EdgeInsets.only(top: 24),
            width: MediaQuery.of(context).size.width,
            child: BarzBlackElevatedButton(
              onPressed: () {},
              text: "Continue",
            ),
          ),
        ],
      ),
    );
  }
}
