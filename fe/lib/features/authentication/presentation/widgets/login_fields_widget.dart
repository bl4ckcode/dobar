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

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: isDark ? 0.6 : 0.7),
        borderRadius: BorderRadius.circular(BarzRadii.md),
        boxShadow: [
          BoxShadow(
            color: colors.labelPrimary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PhoneFormField(
        initialValue: PhoneNumber.parse('+55'),
        decoration: InputDecoration(
          hintText: 'Enter your phone number',
          hintStyle: TextStyle(color: colors.labelSecondary.withValues(alpha: 0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
            borderSide: const BorderSide(color: barzGold, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BarzRadii.md),
            borderSide: const BorderSide(color: barzGold, width: 2),
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
          contentPadding: const EdgeInsets.all(InputSpacing.paddingHorizontal),
          counterStyle: TextStyle(color: colors.labelSecondary.withValues(alpha: 0.6)),
          filled: true,
          fillColor: Colors.transparent, // Controlled by parent container
        ),
        style: TextStyle(color: colors.labelPrimary, fontSize: 16),
        onChanged: (phone) {
          setState(() {
            completePhoneNumber = phone.international;
            isPhoneNumberValid = phone.isValid();
          });
          widget.onLoginPressed(phone.isValid() ? phone.international : null);
        },
        validator: (phone) {
          if (phone == null || !phone.isValid()) {
            return " ";
          }
          return null;
        },
      ),
    );
  }
}
