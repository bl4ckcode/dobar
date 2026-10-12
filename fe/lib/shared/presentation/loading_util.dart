import 'package:flutter/material.dart';
import 'package:barz/core/utils/constant/colors.dart';

class LoadingUtil {
  /// Shows a loading dialog that prevents user interaction.
  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents dismissing by tapping outside.
      builder: (context) => const _LoadingDialog(),
    );
  }

  /// Hides the loading dialog.
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(mainColor),
      ),
    );
  }
}
