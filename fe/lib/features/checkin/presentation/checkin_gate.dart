import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'bloc/checkin_bloc.dart';

class CheckinArguments {
  final BarModel? initialBar;
  final bool returnOnCheckin;
  const CheckinArguments({this.initialBar, this.returnOnCheckin = false});
}

class CheckinGate {
  static Future<bool> ensure(BuildContext context, int barId) async {
    final bloc = getItInjector<CheckinBloc>();
    try {
      if (await bloc.refresh(barId: barId)) return true;
      final bar = (await getItInjector<BarUsecase>().getBar(
        barId,
      )).fold((_) => null, (value) => value);
      if (!context.mounted) return false;
      if (bar == null) {
        _error(context);
        return false;
      }
      final confirmed = await context.push<bool>(
        AppRoute.checkin.path,
        extra: CheckinArguments(initialBar: bar, returnOnCheckin: true),
      );
      if (confirmed != true || !context.mounted) return false;
      return await bloc.refresh(barId: barId);
    } catch (_) {
      if (context.mounted) _error(context);
      return false;
    }
  }

  static void _error(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.checkin_retry_message),
        ),
      );
}
