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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: AppContentWidth(
          maxWidth: 560,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s24,
                  AppSpacing.s16,
                  AppSpacing.s24,
                  AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    Image.asset(
                      dark
                          ? 'assets/branding/inventrix_symbol_dark.png'
                          : 'assets/branding/inventrix_symbol.png',
                      width: 36,
                      height: 36,
                      errorBuilder: (_, _, _) =>
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 30,
                            color: colors.primary,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'INVENTRIX',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    if (!_isLast)
                      TextButton(
                        onPressed: () =>
                            _goTo(_slides.length - 1),
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: PageView.builder(
                  key: const Key('intro_pages'),
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (page) {
                    setState(() => _page = page);
                  },
                  itemBuilder: (context, index) {
                    return _SlideView(
                      slide: _slides[index],
                    );
                  },
                ),
              ),

              // Bottom navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s24,
                  AppSpacing.s12,
                  AppSpacing.s24,
                  AppSpacing.s24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          (_page + 1).toString().padLeft(2, '0'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (_page + 1) / _slides.length,
                              minHeight: 5,
                              backgroundColor:
                              colors.surfaceContainerHighest,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _slides.length.toString().padLeft(2, '0'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s20),

                    AppButton(
                      key: const Key('intro_next'),
                      label: _isLast ? 'Get Started' : 'Continue',
                      icon: _isLast
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_forward_rounded,
                      expand: true,
                      onPressed: _isLast
                          ? _finish
                          : () => _goTo(_page + 1),
                    ),

                    if (!_isLast) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Swipe to explore Inventrix',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
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
    final colors = theme.colorScheme;
    final tokens = context.appColors;
    final tone = slide.tone.colors(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.s32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hero illustration
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: 0.045),
                        ),
                      ),
                      Container(
                        width: 168,
                        height: 168,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tone.container,
                              tone.container.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            slide.icon,
                            size: 76,
                            color: tone.onContainer,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 24,
                        right: 20,
                        child: _FloatingIcon(
                          icon: Icons.check_circle_rounded,
                          color: colors.primary,
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 16,
                        child: _FloatingIcon(
                          icon: Icons.auto_awesome_rounded,
                          color: colors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s24),

                // Slide title
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.8,
                  ),
                ),

                const SizedBox(height: AppSpacing.s16),

                // Description
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 390,
                  ),
                  child: Text(
                    slide.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tokens.textSecondary,
                      height: 1.65,
                    ),
                  ),
                ),

                // Information panel
                if (slide.showsDataNotice) ...[
                  const SizedBox(height: AppSpacing.s32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      AppSpacing.s16,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: AppRadius.controlRadius,
                      border: Border.all(
                        color: colors.outlineVariant,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: colors.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppConstants.localDataWarning,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 20,
        color: color,
      ),
    );
  }
}
