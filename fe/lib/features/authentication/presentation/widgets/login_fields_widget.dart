import 'package:barz/core/utils/constant/colors.dart';
import 'package:barz/shared/presentation/widget/barz_black_elevated_button.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class LoginFieldsWidget extends StatefulWidget {
  final void Function(String? phoneNumber) onLoginPressed;

  const LoginFieldsWidget({super.key, required this.onLoginPressed});

  @override
  State<LoginFieldsWidget> createState() => _LoginFieldsWidgetState();
}

class _LoginFieldsWidgetState extends State<LoginFieldsWidget> {
  String? completePhoneNumber;
  bool isPhoneNumberValid = false; // State variable to track validity

  void _onLoginButtonPressed() {
    widget.onLoginPressed(
      completePhoneNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24),
      child: Column(
        children: [
          IntlPhoneField(
            decoration: const InputDecoration(
              hintText: 'Enter your phone number',
              // Use hintText instead of labelText
              hintStyle: TextStyle(color: Colors.white),
              // Customize hint style
              border: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Colors.white), // Adjust border color if needed
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Colors.white), // Set the border color when focused
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: mainColor), // Set the border color when not focused
              ),
              contentPadding: EdgeInsets.all(16),
              // Add padding if needed
              // Customize the character count label (counter)
              counterStyle: TextStyle(color: Colors.white),
              // Set counter label to white
              // Customize error colors
              errorStyle: TextStyle(height: 1),
              // Set error text to yellow
              errorBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.red), // Set error border to yellow
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Colors
                        .blueGrey), // Border color when focused and error is present
              ),
            ),
            initialCountryCode: 'BR', // Set the initial country code
            onChanged: (phone) {
              setState(() {
                completePhoneNumber = phone.completeNumber;
              });
            },
            validator: (value) {
              try {
                setState(() {
                  isPhoneNumberValid = value?.isValidNumber() ?? false;
                });
              } catch (e) {
                setState(() {
                  isPhoneNumberValid = false;
                });
              }

              return " ";
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
