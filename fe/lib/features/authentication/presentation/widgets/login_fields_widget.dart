import 'package:barz/core/design/design_system.dart';
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
    return Column(
      children: [
        // Phone input field
        Container(
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(BarzRadii.md),
            boxShadow: [
              BoxShadow(
                color: barzDark.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: PhoneFormField(
            initialValue: PhoneNumber.parse('+55'),
            decoration: InputDecoration(
              hintText: 'Enter your phone number',
              hintStyle: TextStyle(color: barzDark.withValues(alpha: 0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: const BorderSide(color: barzDark, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BarzRadii.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(InputSpacing.paddingHorizontal),
              counterStyle: TextStyle(color: barzDark.withValues(alpha: 0.6)),
              filled: true,
              fillColor: surfaceWhite,
            ),
            style: const TextStyle(
              color: barzDark,
              fontSize: 16,
            ),
            onChanged: (phone) {
              setState(() {
                completePhoneNumber = phone.international;
                isPhoneNumberValid = phone.isValid();
              });
            },
            validator: (phone) {
              if (phone == null || !phone.isValid()) {
                return " ";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: BarzSpacing.lg),
        // Continue button
        SizedBox(
          width: double.infinity,
          child: BarzButton.primary(
            onPressed: isPhoneNumberValid ? _onLoginButtonPressed : null,
            label: "Continue",
          ),
        ),
      ],
    );
  }
}
