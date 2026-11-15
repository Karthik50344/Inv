import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_categories_cubit.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_category_dialog.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

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
          appBar: AppBar(title: const Text('Expense categories')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_expense_category'),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Category'),
          ),
          body: Column(
            children: [
              SearchField(
                hintText: 'Search categories',
                onChanged: cubit.search,
              ),
              SwitchListTile(
                title: const Text('Show archived'),
                value: state.includeArchived,
                onChanged: (value) => cubit.setIncludeArchived(value: value),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
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
        );
      case ViewStatus.loaded:
        return ListView.separated(
          itemCount: state.categories.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = state.categories[index];
            return ListTile(
              key: Key('expense_category_${category.id}'),
              title: Text(category.name),
              subtitle: category.description == null
                  ? null
                  : Text(category.description!),
              leading: Icon(
                category.isArchived
                    ? Icons.archive_outlined
                    : Icons.category_outlined,
              ),
              trailing: PopupMenuButton<_Action>(
                onSelected: (action) => _onAction(context, action, category),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
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
            );
          },
        );
    }
  }
}
