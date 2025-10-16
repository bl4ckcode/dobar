import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/shared/presentation/widget/barz_black_elevated_button.dart';
import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';

class LoginFieldsWidget extends StatefulWidget {
  final void Function(String? phoneNumber) onLoginPressed;

  const LoginFieldsWidget({super.key, required this.onLoginPressed});

  @override
  State<LoginFieldsWidget> createState() => _LoginFieldsWidgetState();
}

class _LoginFieldsWidgetState extends State<LoginFieldsWidget> {
  String? completePhoneNumber;
  bool isPhoneNumberValid = false;

  void _onLoginButtonPressed() {
    widget.onLoginPressed(completePhoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          PhoneFormField(
            initialValue: PhoneNumber.parse('+55'),
            decoration: InputDecoration(
              hintText: 'Enter your phone number',
              hintStyle: const TextStyle(color: Colors.white),
              border: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: mainColor),
              ),
              contentPadding: const EdgeInsets.all(16),
              counterStyle: const TextStyle(color: Colors.white),
              focusedErrorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueGrey),
              ),
            ),
            onChanged: (phone) {
              setState(() {
                completePhoneNumber = phone.international;
                isPhoneNumberValid = phone.isValid();
              });
            },
            // Custom validator (you can tweak this logic as needed)
            validator: (phone) {
              if (phone == null || !phone.isValid()) {
                return " "; // Return an empty error so that error text isn't shown immediately
              }
              return null;
            },
          ),
          Container(
            padding: const EdgeInsets.only(top: 24),
            width: MediaQuery.of(context).size.width,
            child: BarzBlackElevatedButton(
              onPressed: _onLoginButtonPressed,
              text: "Continue",
              isEnabled: isPhoneNumberValid,
            ),
          ),
        ],
      ),
    );
  }
}
