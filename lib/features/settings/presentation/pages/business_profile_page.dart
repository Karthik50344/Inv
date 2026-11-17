import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile_input.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/stored_image.dart';

/// Name, logo, address and contact details printed on invoices.
class BusinessProfilePage extends StatefulWidget {
  /// Creates the page.
  const BusinessProfilePage({super.key});

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
      context.pop();
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
        return Scaffold(
          appBar: AppBar(title: const Text('Business profile')),
          body: ListView(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            children: [
              Row(
                children: [
                  StoredImage(
                    relativePath: _logoPath,
                    resolvePath: cubit.resolveLogoPath,
                    size: 72,
                    placeholder: const Icon(Icons.storefront_outlined),
                  ),
                  const SizedBox(width: AppDimensions.spaceMd),
                  OutlinedButton.icon(
                    key: const Key('business_pick_logo'),
                    onPressed: () => _pickLogo(cubit),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_logoPath == null ? 'Add logo' : 'Change logo'),
                  ),
                  if (_logoPath != null)
                    TextButton(
                      key: const Key('business_remove_logo'),
                      onPressed: () => setState(() => _logoPath = null),
                      child: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              TextField(
                key: const Key('business_name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Business name *',
                  errorText: errors['name'],
                ),
              ),
              TextField(
                key: const Key('business_address'),
                controller: _address,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Address',
                  errorText: errors['address'],
                ),
              ),
              TextField(
                key: const Key('business_phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  errorText: errors['phone'],
                ),
              ),
              TextField(
                key: const Key('business_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: errors['email'],
                ),
              ),
              TextField(
                key: const Key('business_tax_id'),
                controller: _taxId,
                decoration: InputDecoration(
                  labelText: 'Tax registration number',
                  errorText: errors['taxId'],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                'Printed on new and re-shared invoices. Invoices already '
                'posted keep their amounts and customers.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              FilledButton(
                key: const Key('business_save'),
                onPressed: state.saving ? null : () => _save(cubit),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}
