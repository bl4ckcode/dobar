import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/presentation/bloc/bar_bloc.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:barz/shared/presentation/widget/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BarsPage extends StatelessWidget {
  final double latitude;
  final double longitude;

  const BarsPage({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getItInjector<BarBloc>()
            ..add(LoadNearbyBars(latitude: latitude, longitude: longitude)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Nearby Bars')),
        body: BlocBuilder<BarBloc, BarState>(
          builder: (context, state) {
            if (state is BarLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is BarError) {
              return Center(child: Text(state.message));
            }
            if (state is BarsLoaded) {
              final bars = state.bars;
              if (bars.isEmpty) {
                return const Center(child: Text('No bars found nearby'));
              }
              return ListView.builder(
                itemCount: bars.length,
                itemBuilder: (context, index) {
                  final bar = bars[index];
                  return ListTile(
                    leading: SafeNetworkAvatar(
                      imageUrl: bar.imageUrl,
                      radius: 24,
                      fallbackIcon: const Icon(Icons.local_bar),
                    ),
                    title: Text(bar.name),
                    subtitle: Text(bar.address),
                    trailing: bar.approximateLocation != null
                        ? Text(
                            '${(bar.approximateLocation! / 1000).toStringAsFixed(1)} km',
                          )
                        : null,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/bar_detail',
                        arguments: bar.id,
                      );
                    },
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
