
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:inventrix/features/backup/presentation/widgets/backup_passphrase_dialogs.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// First-time setup, shown after the introduction until company details exist.
///
/// The owner can either:
/// - Enter company details.
/// - Restore an existing backup.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  Future<void> _pickBackup(BuildContext context) async {
    final bloc = context.read<BackupBloc>();

    final result = await FilePicker.pickFiles();

    if (result == null || result.isEmpty) return;

    final path = result.single.path;

    if (path != null) {
      bloc.add(BackupFileSelected(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final brand = AppTone.brand.colors(context);

    return MultiBlocListener(
      listeners: [
        backupPassphraseListener(),
        BlocListener<BackupBloc, BackupState>(
          listenWhen: (previous, current) =>
          previous.error != current.error && current.error != null,
          listener: (context, state) {
            showAppMessage(
              context,
              state.error!,
              type: AppMessageType.error,
            );
          },
        ),
        BlocListener<BackupBloc, BackupState>(
          listenWhen: (previous, current) =>
          previous.preview == null &&
              current.preview != null &&
              current.activity == BackupActivity.idle,
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: busy
                        ? const LinearProgressIndicator(
                      key: Key('setup_progress'),
                      minHeight: 3,
                    )
                        : const SizedBox(
                      key: Key('setup_idle'),
                      height: 3,
                    ),
                  ),
                  Expanded(
                    child: AppContentWidth(
                      maxWidth: 560,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s24,
                          vertical: AppSpacing.s32,
                        ),
                        children: [
                          // Hero section
                          Center(
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: brand.container,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card * 1.5,
                                ),
                                border: Border.all(
                                  color: brand.solid.withValues(alpha: 0.12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: brand.solid.withValues(alpha: 0.10),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 46,
                                color: brand.onContainer,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s24),

                          // Eyebrow label
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: AppSpacing.s8,
                              ),
                              decoration: BoxDecoration(
                                color: brand.container,
                                borderRadius: AppRadius.pillRadius,
                              ),
                              child: Text(
                                'FIRST-TIME SETUP',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: brand.onContainer,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s16),

                          Text(
                            'Set up your business',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: colors.primaryText,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s12),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                            ),
                            child: Text(
                              'Your company details are needed before you '
                                  'start, because they appear on your invoices. '
                                  'Choose how you want to begin.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s32),

                          // Options heading
                          Text(
                            'CHOOSE HOW TO CONTINUE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s16),

                          // Create company option
                          _OptionCard(
                            key: const Key('setup_company'),
                            icon: Icons.business_rounded,
                            title: 'Enter company details',
                            subtitle:
                            'New to Inventrix? Add your business name, '
                                'address and contact details.',
                            badge: 'RECOMMENDED',
                            highlighted: true,
                            onTap: busy
                                ? null
                                : () => context.push(
                              RoutePaths.setupCompany,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s16),

                          // Restore backup option
                          _OptionCard(
                            key: const Key('setup_restore'),
                            icon: Icons.cloud_download_outlined,
                            title: 'Restore from backup',
                            subtitle:
                            'Already used Inventrix? Select a backup '
                                '(.ivxbak) to bring back your data and '
                                'company details.',
                            onTap: busy ? null : () => _pickBackup(context),
                          ),

                          const SizedBox(height: AppSpacing.s24),

                          // Supporting information
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 15,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Flexible(
                                  child: Text(
                                    'You can restore an existing backup at setup.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final brand = AppTone.brand.colors(context);

    return AppCard(
      selected: highlighted,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: brand.container,
                borderRadius: AppRadius.controlRadius,
              ),
              child: Icon(
                icon,
                size: 24,
                color: brand.onContainer,
              ),
            ),

            const SizedBox(width: AppSpacing.s16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: AppSpacing.s4,
                      ),
                      decoration: BoxDecoration(
                        color: brand.container,
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: brand.onContainer,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],

                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s4),

                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.s8),

            // Trailing action
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
