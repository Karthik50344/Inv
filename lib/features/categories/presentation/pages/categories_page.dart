import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_cubit.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_state.dart';
import 'package:inventrix/features/categories/presentation/widgets/category_form_dialog.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

enum _CategoryAction { edit, archive, restore }

/// Lists categories with search, archive and restore.
class CategoriesPage extends StatelessWidget {
  /// Creates the page. Provide a [CategoryCubit] above it.
  const CategoriesPage({super.key});

  Future<void> _openForm(BuildContext context, {Category? category}) {
    final cubit = context.read<CategoryCubit>();
    return showDialog<bool>(
      context: context,
      builder: (_) => CategoryFormDialog(
        category: category,
        onSubmit: (name, description) => category == null
            ? cubit.create(name, description)
            : cubit.update(category.id, name, description),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    _CategoryAction action,
    Category category,
  ) async {
    final cubit = context.read<CategoryCubit>();
    switch (action) {
      case _CategoryAction.edit:
        await _openForm(context, category: category);
      case _CategoryAction.archive:
        final confirmed = await showConfirmationDialog(
          context,
          title: 'Archive category?',
          message:
              '"${category.name}" will be hidden from new products. '
              'You can restore it later.',
          confirmLabel: 'Archive',
          destructive: true,
        );
        if (confirmed) {
          await cubit.archive(category.id);
        }
      case _CategoryAction.restore:
        await cubit.restore(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CategoryCubit, CategoryState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Categories')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_category'),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Category'),
          ),
          body: Column(
            children: [
              SearchField(
                hintText: 'Search categories',
                onChanged: context.read<CategoryCubit>().search,
              ),
              SwitchListTile(
                title: const Text('Show archived'),
                value: state.includeArchived,
                onChanged: (value) => context
                    .read<CategoryCubit>()
                    .setIncludeArchived(value: value),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CategoryState state) {
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load categories.',
          onRetry: context.read<CategoryCubit>().load,
        );
      case ViewStatus.empty:
        return EmptyState(
          icon: Icons.category_outlined,
          title: state.query.isEmpty ? 'No categories yet' : 'No matches',
          message: state.query.isEmpty
              ? 'Create categories to organize your products.'
              : 'Try a different search.',
        );
      case ViewStatus.loaded:
        return ListView.separated(
          itemCount: state.categories.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = state.categories[index];
            return ListTile(
              title: Text(category.name),
              subtitle: category.description == null
                  ? null
                  : Text(category.description!),
              leading: Icon(
                category.isArchived
                    ? Icons.archive_outlined
                    : Icons.category_outlined,
              ),
              trailing: PopupMenuButton<_CategoryAction>(
                onSelected: (action) => _onAction(context, action, category),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _CategoryAction.edit,
                    child: Text('Edit'),
                  ),
                  if (category.isArchived)
                    const PopupMenuItem(
                      value: _CategoryAction.restore,
                      child: Text('Restore'),
                    )
                  else
                    const PopupMenuItem(
                      value: _CategoryAction.archive,
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
