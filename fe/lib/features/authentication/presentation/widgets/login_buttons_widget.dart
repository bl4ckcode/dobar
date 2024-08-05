import 'package:flutter/material.dart';

class LoginButtonsWidget extends StatefulWidget {
  const LoginButtonsWidget({super.key});

  @override
  State<LoginButtonsWidget> createState() => _LoginButtonsWidgetState();
}

class _LoginButtonsWidgetState extends State<LoginButtonsWidget> {
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
                "assets/images/icons/apple.png",
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
