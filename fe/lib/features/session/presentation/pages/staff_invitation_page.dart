import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/presentation/cubit/invitation_cubit.dart';
import 'package:barz/features/session/presentation/cubit/invitation_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// B08-FE DOB-90: Staff invitation acceptance page.
/// Route: /staff/invitations/accept?code=<code>
class StaffInvitationPage extends StatelessWidget {
  final String? initialCode;
  const StaffInvitationPage({super.key, this.initialCode});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvitationCubit(
        sessionUsecase: getItInjector<SessionUsecase>(),
        sessionBloc: getItInjector<SessionBloc>(),
        initialCode: initialCode,
      ),
      child: const _StaffInvitationView(),
    );
  }
}

class _StaffInvitationView extends StatelessWidget {
  const _StaffInvitationView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left),
          tooltip: l10n.invitation_header_back,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoute.businessDashboard.path),
        ),
        title: Text('Dobar',
            style: TextStyle(
                color: colors.labelPrimary, fontWeight: FontWeight.bold)),
        actions: const [_ThemeToggle()],
      ),
      body: BlocBuilder<InvitationCubit, InvitationState>(
        builder: (context, state) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.isMobileLayout ? 24 : 0),
                child: AnimatedSwitcher(
                  duration: 350.ms,
                  child: KeyedSubtree(
                    key: ValueKey(state.runtimeType),
                    child: _bodyFor(context, state, l10n),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _bodyFor(
    BuildContext context,
    InvitationState state,
    AppLocalizations l10n,
  ) {
    return switch (state) {
      InvitationManualCode() =>
        _ManualCodeForm(initialCode: state.initialCode),
      InvitationLoading() => _LoadingBody(l10n: l10n),
      InvitationSignedOut() =>
        _SignedOutBody(code: state.code, l10n: l10n),
      InvitationReady() =>
        _ReadyBody(code: state.code, preview: state.preview, l10n: l10n),
      InvitationAccepting() =>
        _AcceptingBody(preview: state.preview, l10n: l10n),
      InvitationAcceptError() => _AcceptErrorBody(
          code: state.code, preview: state.preview, l10n: l10n),
      InvitationAccepted() => _SuccessBody(
          preview: state.preview, access: state.access, isNew: true, l10n: l10n),
      InvitationAlreadyMember() => _SuccessBody(
          preview: null, access: state.access, isNew: false, l10n: l10n),
      InvitationWrongAccount() =>
        _WrongAccountBody(code: state.code, l10n: l10n),
      InvitationUnverified() => _UnverifiedBody(
          code: state.code, contactType: state.contactType, l10n: l10n),
      InvitationExpired() => _TerminalBody(kind: 'expired', l10n: l10n),
      InvitationRevoked() => _TerminalBody(kind: 'revoked', l10n: l10n),
      InvitationInvalid() => _TerminalBody(kind: 'invalid', l10n: l10n),
      InvitationLoadError() =>
        _LoadErrorBody(code: state.code, l10n: l10n),
    };
  }
}

// State bodies

class _LoadingBody extends StatelessWidget {
  final AppLocalizations l10n;
  const _LoadingBody({required this.l10n});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _GenericInvitationFrame(),
      const SizedBox(height: 20),
      Semantics(
        liveRegion: true,
        child: Text(l10n.invitation_loading,
            style: TextStyle(color: context.dobarColors.labelSecondary)),
      ),
      const SizedBox(height: 12),
      const CircularProgressIndicator(),
    ]);
  }
}

class _SignedOutBody extends StatelessWidget {
  final String code;
  final AppLocalizations l10n;
  const _SignedOutBody({required this.code, required this.l10n});
  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _GenericInvitationFrame(),
      const SizedBox(height: 24),
      Text(l10n.invitation_sign_in_title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.labelPrimary)),
      const SizedBox(height: 4),
      Text(l10n.invitation_sign_in_hint,
          style: TextStyle(fontSize: 14, color: colors.labelSecondary)),
      const SizedBox(height: 16),
      _SocialButton(
          icon: LucideIcons.mail,
          label: l10n.invitation_google,
          onTap: () => context.push(AppRoute.login.path,
              extra: {'pendingInvitationCode': code})),
      const SizedBox(height: 8),
      _SocialButton(
          icon: LucideIcons.smartphone,
          label: l10n.invitation_phone,
          onTap: () => context.push(AppRoute.login.path,
              extra: {'pendingInvitationCode': code})),
    ]);
  }
}

class _ReadyBody extends StatelessWidget {
  final String code;
  final InvitationPreview preview;
  final AppLocalizations l10n;
  const _ReadyBody({required this.code, required this.preview, required this.l10n});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InvitationCubit>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _InvitationCard(preview: preview, l10n: l10n),
      const SizedBox(height: 16),
      Text(l10n.invitation_accept_support,
          style: TextStyle(fontSize: 13, color: context.dobarColors.labelSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => cubit.acceptInvitation(code, preview),
        style: FilledButton.styleFrom(
          backgroundColor: barzGold, foregroundColor: barzDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.invitation_accept_cta,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppRoute.businessDashboard.path),
        child: Text(l10n.invitation_dismiss,
            style: TextStyle(color: context.dobarColors.labelSecondary)),
      ),
    ]);
  }
}

class _AcceptingBody extends StatelessWidget {
  final InvitationPreview preview;
  final AppLocalizations l10n;
  const _AcceptingBody({required this.preview, required this.l10n});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _InvitationCard(preview: preview, l10n: l10n),
      const SizedBox(height: 20),
      Semantics(
        liveRegion: true,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(l10n.invitation_accepting,
              style: TextStyle(color: context.dobarColors.labelSecondary)),
        ]),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          backgroundColor: barzGold,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.invitation_accept_cta,
            style: const TextStyle(fontWeight: FontWeight.bold, color: barzDark)),
      ),
    ]);
  }
}

class _AcceptErrorBody extends StatelessWidget {
  final String code;
  final InvitationPreview preview;
  final AppLocalizations l10n;
  const _AcceptErrorBody({required this.code, required this.preview, required this.l10n});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InvitationCubit>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _InvitationCard(preview: preview, l10n: l10n),
      const SizedBox(height: 16),
      _StatusBanner(tone: _StatusTone.error, icon: LucideIcons.wifi_off,
          title: l10n.invitation_accept_error_title),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => cubit.acceptInvitation(code, preview),
        style: FilledButton.styleFrom(
          backgroundColor: barzGold, foregroundColor: barzDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.invitation_retry,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppRoute.businessDashboard.path),
        child: Text(l10n.invitation_dismiss,
            style: TextStyle(color: context.dobarColors.labelSecondary)),
      ),
    ]);
  }
}

class _SuccessBody extends StatelessWidget {
  final InvitationPreview? preview;
  final BarAccess access;
  final bool isNew;
  final AppLocalizations l10n;
  const _SuccessBody({this.preview, required this.access, required this.isNew, required this.l10n});
  @override
  Widget build(BuildContext context) {
    final venueName = preview?.venueName ?? access.barName;
    final role = _localizedRole(preview?.role ?? access.role.name, l10n);
    return Semantics(
      liveRegion: true,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: pixGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(LucideIcons.circle_check, size: 44, color: pixGreen),
        ).animate().scale(duration: 350.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          isNew ? l10n.invitation_success_title : l10n.invitation_already_member_title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
              color: context.dobarColors.labelPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isNew
              ? l10n.invitation_success_body(venueName, role)
              : l10n.invitation_already_member_body(venueName, role),
          style: TextStyle(fontSize: 14, color: context.dobarColors.labelSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              context.read<SessionBloc>()
                  .add(SessionEvent.switchActiveBar(barId: access.barId));
              context.go(AppRoute.businessDashboard.path);
            },
            style: FilledButton.styleFrom(
              backgroundColor: barzGold, foregroundColor: barzDark,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.invitation_enter_workspace,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _WrongAccountBody extends StatelessWidget {
  final String code;
  final AppLocalizations l10n;
  const _WrongAccountBody({required this.code, required this.l10n});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _GenericInvitationFrame(),
      const SizedBox(height: 16),
      _StatusBanner(tone: _StatusTone.warning, icon: LucideIcons.shield_alert,
          title: l10n.invitation_wrong_account_title,
          body: l10n.invitation_wrong_account_body),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => context.push(AppRoute.login.path,
            extra: {'pendingInvitationCode': code}),
        style: FilledButton.styleFrom(
          backgroundColor: barzGold, foregroundColor: barzDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.invitation_switch_account,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppRoute.businessDashboard.path),
        child: Text(l10n.invitation_dismiss,
            style: TextStyle(color: context.dobarColors.labelSecondary)),
      ),
    ]);
  }
}

class _UnverifiedBody extends StatelessWidget {
  final String code;
  final String contactType;
  final AppLocalizations l10n;
  const _UnverifiedBody({required this.code, required this.contactType, required this.l10n});
  @override
  Widget build(BuildContext context) {
    final isEmail = contactType == 'email';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _GenericInvitationFrame(),
      const SizedBox(height: 16),
      _StatusBanner(
          tone: _StatusTone.warning,
          icon: LucideIcons.mail_warning,
          title: l10n.invitation_unverified_title,
          body: isEmail
              ? l10n.invitation_unverified_body_email
              : l10n.invitation_unverified_body_phone),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => context.push(AppRoute.profileEdit.path),
        style: FilledButton.styleFrom(
          backgroundColor: barzGold, foregroundColor: barzDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          isEmail ? l10n.invitation_verify_email : l10n.invitation_verify_phone,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppRoute.businessDashboard.path),
        child: Text(l10n.invitation_dismiss,
            style: TextStyle(color: context.dobarColors.labelSecondary)),
      ),
    ]);
  }
}

class _TerminalBody extends StatelessWidget {
  final String kind;
  final AppLocalizations l10n;
  const _TerminalBody({required this.kind, required this.l10n});
  @override
  Widget build(BuildContext context) {
    final isInvalid = kind == 'invalid';
    final title = kind == 'expired'
        ? l10n.invitation_expired_title
        : kind == 'revoked'
            ? l10n.invitation_revoked_title
            : l10n.invitation_invalid_title;
    final body = isInvalid ? l10n.invitation_invalid_body : l10n.invitation_request_new;
    final icon = kind == 'expired'
        ? LucideIcons.clock
        : kind == 'revoked'
            ? LucideIcons.ban
            : LucideIcons.circle_x;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _GenericInvitationFrame(),
      const SizedBox(height: 16),
      _StatusBanner(
          tone: isInvalid ? _StatusTone.error : _StatusTone.neutral,
          icon: icon, title: title, body: body),
      const SizedBox(height: 16),
      TextButton(
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppRoute.businessDashboard.path),
        child: Text(l10n.invitation_back_to_onboarding,
            style: TextStyle(color: context.dobarColors.labelSecondary)),
      ),
    ]);
  }
}

class _LoadErrorBody extends StatelessWidget {
  final String code;
  final AppLocalizations l10n;
  const _LoadErrorBody({required this.code, required this.l10n});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InvitationCubit>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _GenericInvitationFrame(),
      const SizedBox(height: 16),
      _StatusBanner(tone: _StatusTone.error, icon: LucideIcons.wifi_off,
          title: l10n.invitation_load_error_title),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => cubit.retry(code),
        style: FilledButton.styleFrom(
          backgroundColor: barzGold, foregroundColor: barzDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.invitation_retry,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(AppRoute.businessDashboard.path),
        child: Text(l10n.invitation_dismiss,
            style: TextStyle(color: context.dobarColors.labelSecondary)),
      ),
    ]);
  }
}

// Shared reusable widgets

class _GenericInvitationFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 140, width: double.infinity,
        decoration: BoxDecoration(
            color: colors.surface, borderRadius: BorderRadius.circular(16)),
        child: const Center(
            child: Icon(LucideIcons.store, size: 40, color: barzGold)),
      ),
      const SizedBox(height: 16),
      Text(l10n.invitation_eyebrow,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 1.2, color: barzGold)),
      const SizedBox(height: 4),
      Text(l10n.invitation_title,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold,
              color: colors.labelPrimary)),
      const SizedBox(height: 4),
      Text(l10n.invitation_generic_hint,
          style: TextStyle(fontSize: 13, color: colors.labelSecondary)),
    ]);
  }
}

class _InvitationCard extends StatelessWidget {
  final InvitationPreview preview;
  final AppLocalizations l10n;
  const _InvitationCard({required this.preview, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final roleName = _localizedRole(preview.role, l10n);
    final expiry = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR')
        .format(preview.expiresAt.toLocal());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: preview.venueImageUrl != null
            ? Image.network(preview.venueImageUrl!,
                height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, err, stack) => _fallback(colors))
            : _fallback(colors),
      ),
      const SizedBox(height: 16),
      Text(l10n.invitation_eyebrow,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 1.2, color: barzGold)),
      const SizedBox(height: 4),
      Text(l10n.invitation_title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
              color: colors.labelPrimary)),
      const SizedBox(height: 4),
      Text(preview.venueName,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: colors.labelPrimary)),
      if (preview.venueAddress != null) ...[
        const SizedBox(height: 4),
        Row(children: [
          Icon(LucideIcons.map_pin, size: 14, color: colors.labelSecondary),
          const SizedBox(width: 4),
          Expanded(child: Text(preview.venueAddress!,
              style: TextStyle(fontSize: 13, color: colors.labelSecondary))),
        ]),
      ],
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.navBackground),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.invitation_role_label,
                  style: TextStyle(fontSize: 12, color: colors.labelSecondary)),
              const SizedBox(height: 4),
              _RoleBadge(role: roleName),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.invitation_sent_to,
                  style: TextStyle(fontSize: 12, color: colors.labelSecondary)),
              const SizedBox(height: 4),
              Text(preview.maskedRecipient,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: colors.labelPrimary)),
            ])),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(LucideIcons.calendar_clock, size: 14, color: colors.labelSecondary),
            const SizedBox(width: 4),
            Text(l10n.invitation_valid_until(expiry),
                style: TextStyle(fontSize: 12, color: colors.labelSecondary)),
          ]),
        ]),
      ),
      if (preview.permissions.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(l10n.invitation_permissions_title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: colors.labelPrimary)),
        const SizedBox(height: 8),
        ...preview.permissions.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            const Icon(LucideIcons.check, size: 14, color: barzGold),
            const SizedBox(width: 8),
            Text(_localizedPermission(p),
                style: TextStyle(fontSize: 13, color: colors.labelPrimary)),
          ]),
        )),
      ],
    ]);
  }

  Widget _fallback(DobarColors colors) => Container(
    height: 140, width: double.infinity,
    decoration: BoxDecoration(
        color: colors.surface, borderRadius: BorderRadius.circular(16)),
    child: const Center(child: Icon(LucideIcons.store, size: 40, color: barzGold)),
  );
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: barzGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20)),
    child: Text(role, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold, color: barzGold)),
  );
}

enum _StatusTone { error, warning, success, neutral }

class _StatusBanner extends StatelessWidget {
  final _StatusTone tone;
  final IconData icon;
  final String title;
  final String? body;
  const _StatusBanner(
      {required this.tone, required this.icon, required this.title, this.body});
  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final (borderColor, bgColor, iconColor) = switch (tone) {
      _StatusTone.error => (
          const Color(0xFFFF4B4B), const Color(0x14FF4B4B), const Color(0xFFFF4B4B)),
      _StatusTone.warning => (
          barzGold, barzGold.withValues(alpha: 0.1), barzGoldDark),
      _StatusTone.success => (
          pixGreen, pixGreen.withValues(alpha: 0.1), pixGreen),
      _StatusTone.neutral => (
          colors.navBackground, colors.surface, colors.labelSecondary),
    };
    return Semantics(
      container: true,
      liveRegion: tone == _StatusTone.error,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600,
                fontSize: 15, color: colors.labelPrimary)),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(body!, style: TextStyle(fontSize: 13, color: colors.labelSecondary)),
            ],
          ])),
        ]),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return OutlinedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.labelPrimary,
        side: BorderSide(color: colors.surface),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ManualCodeForm extends StatefulWidget {
  final String initialCode;
  const _ManualCodeForm({this.initialCode = ''});
  @override
  State<_ManualCodeForm> createState() => _ManualCodeFormState();
}

class _ManualCodeFormState extends State<_ManualCodeForm> {
  late final TextEditingController _ctrl;
  String? _error;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialCode);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    final v = _ctrl.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (v.isEmpty) {
      setState(() => _error = l10n.invitation_manual_error_empty);
      return;
    }
    setState(() => _error = null);
    context.read<InvitationCubit>().submitCode(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
            color: barzGold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(LucideIcons.key_round, color: barzDark, size: 24),
      ),
      const SizedBox(height: 16),
      Text(l10n.invitation_manual_title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
              color: colors.labelPrimary)),
      const SizedBox(height: 4),
      Text(l10n.invitation_manual_intro,
          style: TextStyle(fontSize: 14, color: colors.labelSecondary)),
      const SizedBox(height: 20),
      Text(l10n.invitation_manual_label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: colors.labelPrimary)),
      const SizedBox(height: 4),
      Text(l10n.invitation_manual_help,
          style: TextStyle(fontSize: 12, color: colors.labelSecondary)),
      const SizedBox(height: 8),
      TextField(
        controller: _ctrl,
        autocorrect: false,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(fontFamily: 'monospace', letterSpacing: 1.5,
            color: colors.labelPrimary),
        decoration: InputDecoration(
          hintText: l10n.invitation_manual_placeholder,
          hintStyle: TextStyle(color: colors.labelSecondary,
              fontFamily: 'sans-serif', letterSpacing: 0),
          errorText: _error,
          filled: true, fillColor: colors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _submit,
        style: FilledButton.styleFrom(
          backgroundColor: barzGold, foregroundColor: barzDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.invitation_manual_submit,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return IconButton(
      icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
      tooltip: isDark ? 'Ativar tema claro' : 'Ativar tema escuro',
      onPressed: () {},
    );
  }
}

// Helpers

String _localizedRole(String role, AppLocalizations l10n) {
  switch (role.toLowerCase()) {
    case 'owner': return l10n.invitation_role_owner;
    case 'admin': return l10n.invitation_role_admin;
    case 'manager': return l10n.invitation_role_manager;
    case 'cashier': return l10n.invitation_role_cashier;
    default: return l10n.invitation_role_staff;
  }
}

String _localizedPermission(String permission) {
  switch (permission) {
    case 'order:view': return 'Ver e acompanhar pedidos';
    case 'order:process': return 'Lancar e editar pedidos';
    case 'billing:manage': return 'Fechar contas e receber pagamentos';
    case 'menu:edit': return 'Editar cardapio e precos';
    case 'staff:manage': return 'Convidar e gerenciar a equipe';
    case 'analytics:view': return 'Ver relatorios de vendas';
    default: return permission;
  }
}
