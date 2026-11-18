import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_categories_cubit.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_category_dialog.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

enum _Action { edit, archive, restore }

/// Lists expense categories with search, archive and restore.
class ExpenseCategoriesPage extends StatelessWidget {
  /// Creates the page. Provide an [ExpenseCategoriesCubit] above it.
  const ExpenseCategoriesPage({super.key});

  Future<void> _openForm(BuildContext context, {ExpenseCategory? category}) {
    final cubit = context.read<ExpenseCategoriesCubit>();
    return showDialog<bool>(
      context: context,
      builder: (_) => ExpenseCategoryDialog(
        category: category,
        onSubmit: (name, description) => category == null
            ? cubit.create(name, description)
            : cubit.update(category.id, name, description),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    _Action action,
    ExpenseCategory category,
  ) async {
    final cubit = context.read<ExpenseCategoriesCubit>();
    switch (action) {
      case _Action.edit:
        await _openForm(context, category: category);
      case _Action.archive:
        final confirmed = await showConfirmationDialog(
          context,
          title: 'Archive category?',
          message:
              '"${category.name}" will be hidden from new expenses. '
              'Recorded expenses keep it, and you can restore it later.',
          confirmLabel: 'Archive',
          destructive: true,
        );
        if (confirmed) {
          await cubit.archive(category.id);
        }
      case _Action.restore:
        await cubit.restore(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseCategoriesCubit, ExpenseCategoriesState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<ExpenseCategoriesCubit>();
        return Scaffold(
          appBar: const AppAppBar(title: 'Expense categories'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_expense_category'),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Category'),
          ),
          body: AppContentWidth(child: Column(
            children: [
              AppSearchField(
                hintText: 'Search categories',
                onChanged: cubit.search,
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                ),
                title: const Text('Show archived'),
                value: state.includeArchived,
                onChanged: (value) => cubit.setIncludeArchived(value: value),
              ),
              Expanded(child: _body(context, state)),
            ],
          )),
        );
      },
    );
  }

  Widget _body(BuildContext context, ExpenseCategoriesState state) {
    final cubit = context.read<ExpenseCategoriesCubit>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load categories.',
          onRetry: cubit.load,
        );
      case ViewStatus.empty:
        return EmptyState(
          icon: Icons.category_outlined,
          title: state.query.isEmpty ? 'No categories yet' : 'No matches',
          message: state.query.isEmpty
              ? 'Create categories to organize your expenses.'
              : 'Try a different search.',
          action: state.query.isEmpty
              ? AppButton(
                  key: const Key('empty_add_expense_category'),
                  label: 'Add category',
                  icon: Icons.add,
                  onPressed: () => _openForm(context),
                )
              : null,
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return AppRefreshIndicator(
          onRefresh: cubit.load,
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              96,
            ),
            itemCount: state.categories.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final category = state.categories[index];
              final colors =
                  (category.isArchived ? AppTone.neutral : AppTone.brand)
                      .colors(context);
              return AppCard(
                key: Key('expense_category_${category.id}'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s12,
                  AppSpacing.s8,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.container,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          category.isArchived
                              ? Icons.archive_outlined
                              : Icons.category_outlined,
                          size: 20,
                          color: colors.onContainer,
                        ),
                      ),
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (category.description != null)
                            Text(
                              category.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (category.isArchived)
                      const AppBadge(label: 'Archived'),
                    PopupMenuButton<_Action>(
                      onSelected: (action) =>
                          _onAction(context, action, category),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: _Action.edit,
                          child: Text('Edit'),
                        ),
                        if (category.isArchived)
                          const PopupMenuItem(
                            value: _Action.restore,
                            child: Text('Restore'),
                          )
                        else
                          const PopupMenuItem(
                            value: _Action.archive,
                            child: Text('Archive'),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}
