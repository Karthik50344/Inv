import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// First-time setup, shown after the introduction until the company details
/// exist. The owner chooses one of two ways to get started:
///
/// * enter the company details, or
/// * restore a backup file (which brings the company details with it).
///
/// Needs a [BackupBloc] above it. After a successful restore the whole app
/// is rebuilt, so this page does not navigate by itself.
class SetupPage extends StatelessWidget {
  /// Creates the page.
  const SetupPage({super.key});

  Future<void> _pickBackup(BuildContext context) async {
    final bloc = context.read<BackupBloc>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = result?.files.single.path;
    if (path != null) {
      bloc.add(BackupFileSelected(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final brand = AppTone.brand.colors(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<BackupBloc, BackupState>(
          listenWhen: (a, b) => a.error != b.error && b.error != null,
          listener: (context, state) =>
              showAppMessage(context, state.error!, type: AppMessageType.error),
        ),
        BlocListener<BackupBloc, BackupState>(
          listenWhen: (a, b) =>
              a.preview == null &&
              b.preview != null &&
              b.activity == BackupActivity.idle,
          listener: (context, state) async {
            final bloc = context.read<BackupBloc>();
            final confirmed = await showRestoreConfirmationDialog(
              context,
              state.preview!,
              firstSetup: true,
            );
            bloc.add(
              confirmed
                  ? const BackupRestoreConfirmed()
                  : const BackupPreviewDiscarded(),
            );
          },
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<BackupBloc, BackupState>(
            builder: (context, state) {
              final busy = state.busy;
              return Column(
                children: [
                  if (busy)
                    const LinearProgressIndicator(
                      key: Key('setup_progress'),
                      minHeight: 3,
                    ),
                  Expanded(
                    child: AppContentWidth(
                      maxWidth: 560,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.s24),
                        children: [
                          AppSpacing.gap24,
                          Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: brand.container,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card * 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.s24),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  size: 48,
                                  color: brand.onContainer,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s24),
                          Text(
                            'Set up your business',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall,
                          ),
                          AppSpacing.gap12,
                          Text(
                            'Your company details are needed before you '
                            'start, because they appear on your invoices. '
                            'Choose how you want to begin.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s32),
                          _OptionCard(
                            key: const Key('setup_company'),
                            icon: Icons.edit_note_outlined,
                            title: 'Enter company details',
                            subtitle:
                                'New to Inventrix? Add your business name, '
                                'address and contact details.',
                            highlighted: true,
                            onTap: busy
                                ? null
                                : () => context.push(RoutePaths.setupCompany),
                          ),
                          AppSpacing.gap12,
                          _OptionCard(
                            key: const Key('setup_restore'),
                            icon: Icons.restore_outlined,
                            title: 'Use a backup file',
                            subtitle:
                                'Already used Inventrix? Pick a backup (.zip) '
                                'to bring back your data and company '
                                'details.',
                            onTap: busy ? null : () => _pickBackup(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final brand = AppTone.brand.colors(context);
    return AppCard(
      selected: highlighted,
      onTap: onTap,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: brand.container,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Icon(icon, size: 24, color: brand.onContainer),
            ),
          ),
          AppSpacing.hGap16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hGap8,
          Icon(Icons.chevron_right, color: tokens.textSecondary),
        ],
      ),
    );
  }
}
