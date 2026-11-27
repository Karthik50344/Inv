import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_cubit.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_state.dart';
import 'package:inventrix/features/categories/presentation/widgets/category_form_dialog.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

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
          appBar: const AppAppBar(title: 'Categories'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_category'),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Category'),
          ),
          body: Column(
            children: [
              AppSearchField(
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
          action: state.query.isEmpty
              ? AppButton(
                  key: const Key('empty_add_category'),
                  label: 'Add category',
                  icon: Icons.add,
                  onPressed: () => _openForm(context),
                )
              : null,
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        return AppRefreshIndicator(
          onRefresh: context.read<CategoryCubit>().load,
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
              return AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s8,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    Icon(
                      category.isArchived
                          ? Icons.archive_outlined
                          : Icons.category_outlined,
                      color: tokens.textSecondary,
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (category.description != null)
                            Text(
                              category.description!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<_CategoryAction>(
                      tooltip: 'Category actions',
                      onSelected: (action) =>
                          _onAction(context, action, category),
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
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}
