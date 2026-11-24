import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_integrity_cubit.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Checks that no audit event was changed, removed or reordered, and lets
/// the user keep or compare a checkpoint outside the device.
class AuditIntegrityPage extends StatefulWidget {
  /// Creates the page.
  const AuditIntegrityPage({super.key});

  @override
  State<AuditIntegrityPage> createState() => _AuditIntegrityPageState();
}

class _AuditIntegrityPageState extends State<AuditIntegrityPage> {
  final TextEditingController _sequence = TextEditingController();
  final TextEditingController _hash = TextEditingController();

  @override
  void dispose() {
    _sequence.dispose();
    _hash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const AppAppBar(title: 'Check integrity'),
      body: BlocBuilder<AuditIntegrityCubit, AuditIntegrityState>(
        builder: (context, state) {
          final cubit = context.read<AuditIntegrityCubit>();
          return AppContentWidth(
            child: ListView(
              padding: AppSpacing.page,
              children: [
                Text(
                  'Every audit event carries a fingerprint of its own content '
                  'and of the event before it. This check walks the whole log '
                  'and tells you whether anything was changed, removed or '
                  'reordered after it was written.',
                  style: theme.textTheme.bodyMedium,
                ),
                AppSpacing.gap16,
                AppButton(
                  label: state.running ? 'Checking...' : 'Check now',
                  icon: Icons.verified_outlined,
                  loading: state.running,
                  expand: true,
                  onPressed: state.running ? null : cubit.verify,
                ),
                if (state.error != null) ...[
                  AppSpacing.gap12,
                  Text(state.error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ],
                if (state.result != null) ...[
                  AppSpacing.gap16,
                  _Result(result: state.result!, withCheckpoint: state.comparedWithCheckpoint),
                ],
                const AppSectionHeader(
                  title: 'Keep a checkpoint',
                  subtitle: 'Protects against deleted or rebuilt history',
                ),
                Text(
                  'The log lives in the same file as your data. Someone with '
                  'direct access to that file could rewrite it so it still '
                  'looks consistent. Save the code below somewhere outside '
                  'this device (print it, e-mail it to yourself, give it to '
                  'your auditor). Later you can compare it here.',
                  style: theme.textTheme.bodyMedium,
                ),
                AppSpacing.gap12,
                AppButton(
                  label: 'Create a checkpoint',
                  icon: Icons.flag_outlined,
                  variant: AppButtonVariant.outlined,
                  expand: true,
                  onPressed: cubit.makeCheckpoint,
                ),
                if (state.checkpoint != null) ...[
                  AppSpacing.gap12,
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Checkpoint', style: theme.textTheme.titleSmall),
                        AppSpacing.gap4,
                        Text('Taken ${DateFormatter.dateTime(state.checkpoint!.takenAtUtc)}', style: theme.textTheme.bodySmall),
                        AppSpacing.gap8,
                        SelectableText(
                          'Event number: ${state.checkpoint!.sequence}\n'
                          'Code: ${state.checkpoint!.eventHash}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                        ),
                        AppSpacing.gap8,
                        AppButton(
                          label: 'Copy',
                          icon: Icons.copy,
                          variant: AppButtonVariant.text,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: 'Inventrix audit checkpoint\n'
                                    'Event number: ${state.checkpoint!.sequence}\n'
                                    'Code: ${state.checkpoint!.eventHash}\n'
                                    'Taken (UTC): ${state.checkpoint!.takenAtUtc.toIso8601String()}',
                              ),
                            );
                            if (context.mounted) {
                              showAppMessage(context, 'Copied');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const AppSectionHeader(title: 'Compare with a saved checkpoint'),
                AppTextField(
                  label: 'Event number',
                  controller: _sequence,
                  keyboardType: TextInputType.number,
                ),
                AppSpacing.gap12,
                AppTextField(
                  label: 'Code',
                  hint: '64 letters and numbers',
                  controller: _hash,
                  errorText: state.checkpointError,
                ),
                AppSpacing.gap12,
                AppButton(
                  label: 'Check against it',
                  icon: Icons.compare_arrows,
                  variant: AppButtonVariant.outlined,
                  expand: true,
                  onPressed: state.running ? null : () => cubit.verifyAgainst(_sequence.text, _hash.text),
                ),
                AppSpacing.gap16,
                Text(
                  'What this cannot tell you: who the person named in an '
                  'event really is (Inventrix has no sign-in yet), or events '
                  'recorded before the integrity log was introduced.',
                  style: theme.textTheme.bodySmall,
                ),
                AppSpacing.gap24,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.result, required this.withCheckpoint});

  final AuditVerification result;
  final bool withCheckpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = result.isValid;
    return AppCard(
      tone: ok ? AppTone.success : AppTone.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.verified : Icons.gpp_bad),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  ok ? 'No change detected' : 'A problem was found',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          AppSpacing.gap8,
          Text(
            ok
                ? '${result.eventsChecked} events were checked. None was '
                      'changed, removed or reordered'
                      '${withCheckpoint ? ', and your checkpoint is part of the log' : ''}.'
                : _problem(result),
            style: theme.textTheme.bodyMedium,
          ),
          if (!ok) ...[
            AppSpacing.gap8,
            Text(
              'Keep this device as it is and show this screen to whoever '
              'manages your data. Do not restore or delete anything until '
              'the cause is understood.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  static String _problem(AuditVerification v) => switch (v.problem) {
    AuditProblem.hashMismatch =>
      'Event number ${v.problemSequence} no longer matches the fingerprint '
          'recorded when it was written, so its content was changed. '
          '${v.eventsChecked} earlier events were fine.',
    AuditProblem.brokenLink =>
      'An event is missing, or an extra one was added, just before event '
          'number ${v.problemSequence}.',
    AuditProblem.outOfOrder => 'Events are out of order at number ${v.problemSequence}.',
    AuditProblem.checkpointMissing =>
      'The checkpoint you entered is not part of the log. Events after it '
          'may have been removed, or the log was rebuilt.',
    AuditProblem.none => '',
  };
}
