import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile_input.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
import 'package:inventrix/shared/presentation/widgets/stored_image.dart';

/// Name, logo, address and contact details printed on invoices.
///
/// With [isSetup] it is the mandatory first-time step: saving continues to
/// the dashboard instead of going back.
class BusinessProfilePage extends StatefulWidget {
  /// Creates the page.
  const BusinessProfilePage({this.isSetup = false, super.key});

  /// Whether this is the first-time company setup.
  final bool isSetup;

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _taxId;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    final b = context.read<SettingsCubit>().state.business;
    _name = TextEditingController(text: b?.name);
    _address = TextEditingController(text: b?.address);
    _phone = TextEditingController(text: b?.phone);
    _email = TextEditingController(text: b?.email);
    _taxId = TextEditingController(text: b?.taxId);
    _logoPath = b?.logoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _taxId.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(SettingsCubit cubit) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    final stored = await cubit.storeLogo(path);
    if (stored.valueOrNull != null && mounted) {
      setState(() => _logoPath = stored.valueOrNull);
    }
  }

  Future<void> _save(SettingsCubit cubit) async {
    final saved = await cubit.saveBusiness(
      BusinessProfileInput(
        name: _name.text,
        address: _address.text,
        phone: _phone.text,
        email: _email.text,
        taxId: _taxId.text,
        logoPath: _logoPath,
      ),
    );
    if (saved && mounted) {
      if (widget.isSetup) {
        context.go(RoutePaths.dashboard);
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) =>
          b.message != null && a.messageSerial != b.messageSerial,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final errors = state.fieldErrors;
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppAppBar(
            title: widget.isSetup ? 'Company details' : 'Business profile',
          ),
          body: AppContentWidth(child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppSpacing.page,
            children: [
              AppCard(
                child: Row(
                  children: [
                    StoredImage(
                      relativePath: _logoPath,
                      resolvePath: cubit.resolveLogoPath,
                      size: 72,
                      placeholder: const Icon(Icons.storefront_outlined),
                    ),
                    AppSpacing.hGap16,
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        children: [
                          AppButton(
                            key: const Key('business_pick_logo'),
                            label: _logoPath == null
                                ? 'Add logo'
                                : 'Change logo',
                            icon: Icons.image_outlined,
                            variant: AppButtonVariant.outlined,
                            size: AppButtonSize.small,
                            onPressed: () => _pickLogo(cubit),
                          ),
                          if (_logoPath != null)
                            AppButton(
                              key: const Key('business_remove_logo'),
                              label: 'Remove',
                              variant: AppButtonVariant.text,
                              size: AppButtonSize.small,
                              onPressed: () =>
                                  setState(() => _logoPath = null),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const AppSectionHeader(
                title: 'Details',
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s20,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
              ),
              AppTextField(
                key: const Key('business_name'),
                controller: _name,
                label: 'Business name *',
                errorText: errors['name'],
                textCapitalization: TextCapitalization.words,
              ),
              AppSpacing.gap12,
              AppTextField(
                key: const Key('business_address'),
                controller: _address,
                minLines: 2,
                maxLines: 4,
                label: 'Address',
                errorText: errors['address'],
                textCapitalization: TextCapitalization.sentences,
              ),
              AppSpacing.gap12,
              AppTextField(
                key: const Key('business_phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                label: 'Phone',
                errorText: errors['phone'],
              ),
              AppSpacing.gap12,
              AppTextField(
                key: const Key('business_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                label: 'Email',
                errorText: errors['email'],
              ),
              AppSpacing.gap12,
              AppTextField(
                key: const Key('business_tax_id'),
                controller: _taxId,
                label: 'Tax registration number',
                errorText: errors['taxId'],
                textCapitalization: TextCapitalization.characters,
              ),
              AppSpacing.gap12,
              Text(
                widget.isSetup
                    ? 'The business name is required. These details are '
                          'printed on your invoices and can be changed later '
                          'in Settings.'
                    : 'Printed on new and re-shared invoices. Invoices '
                          'already posted keep their amounts and customers.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              AppSpacing.gap16,
              AppButton(
                key: const Key('business_save'),
                label: widget.isSetup ? 'Save and continue' : 'Save',
                icon: Icons.check,
                expand: true,
                loading: state.saving,
                onPressed: state.saving ? null : () => _save(cubit),
              ),
            ],
          )),
        );
      },
    );
  }
}
