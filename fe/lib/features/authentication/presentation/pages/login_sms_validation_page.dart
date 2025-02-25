import 'package:barz/core/utils/constant/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:barz/features/authentication/presentation/bloc/login_event.dart';
import 'package:barz/features/authentication/presentation/bloc/login_state.dart';

class LoginValidatePhoneNumberPage extends StatefulWidget {
  final String verificationId;
  final LoginBloc loginBloc;

  const LoginValidatePhoneNumberPage({super.key, required this.verificationId, required this.loginBloc});

  @override
  State<LoginValidatePhoneNumberPage> createState() =>
      _LoginValidatePhoneNumberPageState();
}

class _LoginValidatePhoneNumberPageState
    extends State<LoginValidatePhoneNumberPage> {
  final TextEditingController _smsCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _smsCodeController.dispose();
    super.dispose();
  }

  void _handleCodeVerification() {
    final smsCode = _smsCodeController.text.trim();
    if (smsCode.isNotEmpty) {
      widget.loginBloc.add(VerifyCodeButtonPressed(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the verification code.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor,
      appBar: AppBar(title: const Text("Verify Phone Number")),
      body: BlocListener<LoginBloc, LoginState>(
        bloc: widget.loginBloc,
        listener: (context, state) {
          if (state is Success) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (Route<dynamic> route) => false);
          } else if (state is Failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _smsCodeController,
                decoration: const InputDecoration(
                  labelText: "Enter Verification Code",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleCodeVerification,
                child: const Text("Verify"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
