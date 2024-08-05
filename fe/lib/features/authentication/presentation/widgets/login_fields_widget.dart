import 'package:flutter/material.dart';

class LoginFieldsWidget extends StatefulWidget {
  const LoginFieldsWidget({super.key});

  @override
  State<LoginFieldsWidget> createState() => _LoginFieldsWidgetState();
}

class _LoginFieldsWidgetState extends State<LoginFieldsWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              icon: Image.asset(
                "assets/images/icons/email.png",
                height: 64,
                width: 64,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              icon: Image.asset(
                "assets/images/icons/google.png",
                height: 64,
                width: 64,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              icon: Image.asset(
                "assets/images/icons/apple.svg",
                height: 64,
                width: 64,
              ),
            ),
          ],
        )
      ],
    );
  }
}
