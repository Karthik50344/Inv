import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// One slide of the introduction.
class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = AppTone.brand,
    this.showsDataNotice = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final AppTone tone;
  final bool showsDataNotice;
}

const List<_Slide> _slides = [
  _Slide(
    icon: Icons.inventory_2_outlined,
    title: 'Welcome to Inventrix',
    message:
        'Run your stock, billing and accounts from one place, with no '
        'internet needed.',
  ),
  _Slide(
    icon: Icons.category_outlined,
    title: 'Products and stock',
    message:
        'Add products with prices and units, watch stock levels and see '
        'what is running low before it runs out.',
  ),
  _Slide(
    icon: Icons.receipt_long_outlined,
    title: 'Sales and purchases',
    message:
        'Create invoices, record payments and returns, and keep track of '
        'what customers owe and what you owe suppliers.',
  ),
  _Slide(
    icon: Icons.insights_outlined,
    title: 'Expenses and reports',
    message:
        'Record what the business spends and read clear reports on sales, '
        'purchases, stock and profit.',
  ),
  _Slide(
    icon: Icons.shield_outlined,
    title: 'Your data stays with you',
    message:
        'Everything is saved on this device, so it works offline and is '
        'private to you.',
    tone: AppTone.success,
    showsDataNotice: true,
  ),
];

/// First-launch introduction: a few swipeable slides ending in "Continue".
///
/// It opens once on a fresh install and can be shown again from Settings.
class IntroPage extends StatefulWidget {
  /// Creates the page.
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  Future<void> _finish() async {
    SettingsCubit? settings;
    try {
      settings = context.read<SettingsCubit>();
    } on Object {
      // No settings provider (for example in a widget test): just move on.
      settings = null;
    }
    await settings?.markIntroSeen();
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: AppContentWidth(
          maxWidth: 560,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s8,
                  AppSpacing.s12,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      dark
                          ? 'assets/branding/inventrix_symbol_dark.png'
                          : 'assets/branding/inventrix_symbol.png',
                      width: 32,
                      height: 32,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 32, height: 32),
                    ),
                    Visibility(
                      visible: !_isLast,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: AppButton(
                        key: const Key('intro_skip'),
                        label: 'Skip',
                        variant: AppButtonVariant.text,
                        onPressed: () => _goTo(_slides.length - 1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const Key('intro_pages'),
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) =>
                      _SlideView(slide: _slides[index]),
                ),
              ),
              Row(
                key: const Key('intro_dots'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    _Dot(active: i == _page),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: AppButton(
                  key: const Key('intro_next'),
                  label: _isLast ? 'Continue' : 'Next',
                  icon: _isLast ? Icons.check : Icons.arrow_forward,
                  expand: true,
                  onPressed: _isLast ? _finish : () => _goTo(_page + 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? AppTone.brand.colors(context).solid
            : tokens.borderStrong,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final colors = slide.tone.colors(context);
    final info = AppTone.info.colors(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.container,
                  borderRadius: BorderRadius.circular(AppRadius.card * 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s32),
                  child: Icon(slide.icon, size: 56, color: colors.onContainer),
                ),
              ),
              const SizedBox(height: AppSpacing.s32),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              AppSpacing.gap12,
              Text(
                slide.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              if (slide.showsDataNotice) ...[
                AppSpacing.gap24,
                DecoratedBox(
                  key: const Key('intro_data_notice'),
                  decoration: BoxDecoration(
                    color: info.container,
                    borderRadius: AppRadius.controlRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.backup_outlined,
                          size: 20,
                          color: info.onContainer,
                        ),
                        AppSpacing.hGap12,
                        Expanded(
                          child: Text(
                            AppConstants.localDataWarning,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: info.onContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
