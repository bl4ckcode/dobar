import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tokens/colors.dart';

class DobarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuTap;
  final List<Widget>? actions;

  const DobarAppBar({super.key, this.onMenuTap, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: onMenuTap != null
          ? Container(
              margin: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu, color: barzDark, size: 22),
                ),
                onPressed: onMenuTap,
              ),
            )
          : null,
      title:
          Text(
                'dobar',
                style: GoogleFonts.poppins(
                  color: barzDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 600.ms, delay: 100.ms)
              .slideY(
                begin: -0.2,
                end: 0,
                duration: 600.ms,
                delay: 100.ms,
                curve: Curves.easeOutCubic,
              )
              .then(delay: 2000.ms)
              .shimmer(
                duration: 1200.ms,
                color: barzGold.withValues(alpha: 0.3),
              ),
      actions: actions,
    );
  }
}
