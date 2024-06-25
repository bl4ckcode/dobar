import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TitleSubtitleWidget extends StatelessWidget {
  const TitleSubtitleWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
        children:
        [
          Container(
            alignment: Alignment.topCenter,
            margin: const EdgeInsets.only(top: 16),
            child: Text(
              AppLocalizations.of(context)!.app_title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JuliusSansOne',
                fontSize: 24.sp,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  "Conheça nossos parceiros",
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium!
                      .copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 16),
                child: Text(
                  "Aqui estão os parceiros mais próximos de você :)",
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: Colors.black, fontWeight: FontWeight.w300),
                ),
              ),
            ],
          )
        ]
    );
  }
}