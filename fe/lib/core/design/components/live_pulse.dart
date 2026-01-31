import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../tokens/spacing.dart';

class LivePulse extends StatefulWidget {
  final String venueName;
  final int energyLevel;
  final String waitTime;
  final String trendingSince;

  const LivePulse({
    super.key,
    required this.venueName,
    required this.energyLevel,
    required this.waitTime,
    this.trendingSince = '11PM',
  });

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse> with TickerProviderStateMixin {
  late AnimationController _energyController;
  late AnimationController _soundController;
  late Animation<double> _energyAnimation;
  final List<AnimationController> _barControllers = [];
  final List<Animation<double>> _barAnimations = [];

  @override
  void initState() {
    super.initState();

    _energyController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _energyAnimation =
        Tween<double>(begin: 0.0, end: widget.energyLevel / 100.0).animate(
          CurvedAnimation(parent: _energyController, curve: Curves.easeOut),
        );

    _energyController.forward();

    _soundController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    for (int i = 0; i < 12; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );

      final animation = Tween<double>(
        begin: 0.3,
        end: 0.3 + (0.7 * (i % 3) / 3),
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      _barControllers.add(controller);
      _barAnimations.add(animation);

      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _energyController.dispose();
    _soundController.dispose();
    for (var controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BarzSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xCC121212),
        borderRadius: BorderRadius.circular(BarzRadii.md),
        border: Border.all(color: const Color(0x1AFFD700), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: barzGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: BarzSpacing.xs),
                  const Text(
                    'LIVE PULSE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: barzGold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Text(
                '~${widget.waitTime} wait',
                style: const TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: BarzSpacing.md),
          Text(
            widget.venueName.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textOnDark,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: BarzSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 16,
                color: barzGold,
              ),
              const SizedBox(width: BarzSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Energy',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        Text(
                          '${widget.energyLevel}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textOnDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: barzDarkLight,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: AnimatedBuilder(
                        animation: _energyAnimation,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _energyAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: barzGold,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BarzSpacing.sm),
          Row(
            children: [
              const Icon(Icons.volume_up, size: 16, color: barzGold),
              const SizedBox(width: BarzSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: List.generate(12, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: AnimatedBuilder(
                            animation: _barAnimations[index],
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: _barAnimations[index].value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: barzGold,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BarzSpacing.sm),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: barzGold),
              const SizedBox(width: BarzSpacing.sm),
              Text(
                'Trending up since ${widget.trendingSince}',
                style: const TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
