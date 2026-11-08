import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/core/presentation/widgets/barz_loading_widget.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/home/presentation/cubit/profile_account_cubit.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _editing = false;
  bool _allowPop = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _dirty {
    final user = context.read<ProfileAccountCubit>().state.user;
    return _editing &&
        (_name.text != (user?.displayName ?? '') ||
            _email.text != (user?.email ?? '') ||
            _phone.text != (user?.phoneNumber ?? ''));
  }

  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context)!;
    if (context.read<ProfileAccountCubit>().state.saving) return;
    if (!_dirty ||
        await confirmProfileAction(
          context,
          l10n.profile_discard,
          l10n.profile_discard_body,
        )) {
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _startEditing() {
    final user = context.read<ProfileAccountCubit>().state.user!;
    _name.text = user.displayName ?? '';
    _email.text = user.email ?? '';
    _phone.text = user.phoneNumber ?? '';
    setState(() => _editing = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.dobarColors;
    return BlocConsumer<ProfileAccountCubit, ProfileAccountState>(
      listener: (context, state) async {
        if (state.saved) setState(() => _editing = false);
        if (state.deleted) {
          await getItInjector<SessionBloc>().signOut();
          if (context.mounted) AppRoute.login.go(context);
        }
      },
      builder: (context, state) => PopScope(
        canPop: _allowPop || (!_dirty && !state.saving),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: ProfileFrame(
          title: l10n.profile_account,
          actions: [
            if (!_editing && state.user != null)
              TextButton(
                onPressed: state.saving ? null : _startEditing,
                child: Text(l10n.edit),
              ),
          ],
          children: [
            if (state.loading)
              const BarzLoadingWidget()
            else if (state.user == null) ...[
              Text(l10n.profile_load_failed),
              TextButton(
                onPressed: () => context.read<ProfileAccountCubit>().load(),
                child: Text(l10n.retry),
              ),
            ] else ...[
              if (state.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.profile_action_failed,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (state.saved)
                Semantics(liveRegion: true, child: Text(l10n.profile_saved)),
              ProfileGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(BarzSpacing.lg),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_editing) ...[
                            _field(
                              _name,
                              l10n.profile_name,
                              TextInputType.name,
                            ),
                            _field(
                              _email,
                              l10n.profile_email,
                              TextInputType.emailAddress,
                            ),
                            _field(
                              _phone,
                              l10n.profile_phone,
                              TextInputType.phone,
                            ),
                          ] else ...[
                            _detail(l10n.profile_name, state.user!.displayName),
                            _detail(l10n.profile_email, state.user!.email),
                            _detail(
                              l10n.profile_phone,
                              state.user!.phoneNumber,
                            ),
                          ],
                          Text(
                            l10n.profile_contact_note,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.labelSecondary),
                          ),
                          if (_editing) ...[
                            const SizedBox(height: BarzSpacing.lg),
                            ProfilePrimaryButton(
                              label: l10n.save,
                              busy: state.saving,
                              onPressed: () {
                                if (_form.currentState!.validate()) {
                                  context.read<ProfileAccountCubit>().save(
                                    _name.text,
                                  );
                                }
                              },
                            ),
                            TextButton(
                              onPressed: state.saving
                                  ? null
                                  : () async {
                                      if (!_dirty ||
                                          await confirmProfileAction(
                                            context,
                                            l10n.profile_discard,
                                            l10n.profile_discard_body,
                                          )) {
                                        if (mounted) {
                                          setState(() => _editing = false);
                                        }
                                      }
                                    },
                              child: Text(l10n.cancel),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ProfileGroup(
                title: l10n.profile_privacy,
                children: [
                  ProfileRow(
                    icon: LucideIcons.shield,
                    title: l10n.profile_privacy,
                    onTap: state.saving
                        ? null
                        : () => AppRoute.privacyPolicy.push(context),
                  ),
                  ProfileRow(
                    icon: LucideIcons.trash,
                    title: l10n.profile_delete,
                    destructive: true,
                    onTap: state.saving
                        ? null
                        : () async {
                            if (await confirmProfileAction(
                                  context,
                                  l10n.profile_delete,
                                  l10n.profile_delete_body,
                                ) &&
                                context.mounted) {
                              context.read<ProfileAccountCubit>().delete();
                            }
                          },
                  ),
                ],
              ),
              if (state.saving && !_editing) const BarzLoadingWidget(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: BarzSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.dobarColors.labelSecondary,
          ),
        ),
        SelectableText(
          value?.isNotEmpty == true
              ? value!
              : AppLocalizations.of(context)!.profile_not_provided,
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    TextInputType type,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: BarzSpacing.lg),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        enabled:
            type == TextInputType.name &&
            !context.read<ProfileAccountCubit>().state.saving,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return l10n.profile_required;
          }
          if (type == TextInputType.emailAddress &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
            return l10n.profile_invalid_email;
          }
          if (type == TextInputType.phone) {
            final digits = value.replaceAll(RegExp(r'\D'), '');
            final national = digits.startsWith('55') && digits.length > 11
                ? digits.substring(2)
                : digits;
            if (national.length < 10 || national.length > 11) {
              return l10n.profile_invalid_phone;
            }
          }
          return null;
        },
      ),
    );
  }
}
