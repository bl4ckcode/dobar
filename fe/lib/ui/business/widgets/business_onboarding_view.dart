import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';

/// Onboarding view shown to business users who don't have any bars yet.
/// 
/// Provides options to:
/// - Create a new bar
/// - Accept a staff invitation
/// - Switch to client mode to explore
class BusinessOnboardingView extends StatelessWidget {
  const BusinessOnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: barzCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 48),
                  _buildCreateBarCard(context)
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 16),
                  _buildAcceptInvitationCard(context)
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 32),
                  _buildDivider()
                      .animate(delay: 400.ms)
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                  _buildSwitchToClientButton(context)
                      .animate(delay: 500.ms)
                      .fadeIn(duration: 400.ms)
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: barzBlack,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: barzBlack.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.store_rounded,
            size: 48,
            color: barzYellow,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Welcome, Bar Owner! 🎉',
          style: barzTextTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: barzBlack,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "Let's get your bar set up on Dobar",
          style: barzTextTheme.bodyLarge?.copyWith(
            color: textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCreateBarCard(BuildContext context) {
    return _ActionCard(
      icon: Icons.add_business_rounded,
      iconColor: barzYellow,
      backgroundColor: barzBlack,
      title: 'Create New Bar',
      subtitle: 'Register your establishment and start receiving orders',
      onTap: () {
        // TODO: Navigate to create bar flow
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Create bar flow coming soon!'),
            backgroundColor: barzBlack,
          ),
        );
      },
    );
  }

  Widget _buildAcceptInvitationCard(BuildContext context) {
    return _ActionCard(
      icon: Icons.mail_outline_rounded,
      iconColor: barzBlack,
      backgroundColor: surfaceWhite,
      textColor: barzBlack,
      title: 'Accept Invitation',
      subtitle: "Join an existing bar's team as staff",
      onTap: () {
        _showInvitationDialog(context);
      },
      outlined: true,
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or explore as',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildSwitchToClientButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        context.read<SessionBloc>().add(const SessionEvent.switchToClientMode());
      },
      icon: Icon(Icons.person_outline, color: barzBlack),
      label: Text(
        'Switch to Client Mode',
        style: barzTextTheme.bodyLarge?.copyWith(
          color: barzBlack,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  void _showInvitationDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Invitation Code'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste your invitation code',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Invitation acceptance coming soon!'),
                  backgroundColor: barzBlack,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: barzYellow,
              foregroundColor: barzBlack,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

/// Reusable action card for onboarding options
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color? textColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.textColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? Colors.white;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: outlined
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: backgroundColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: outlined ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: effectiveTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: effectiveTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: effectiveTextColor.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
