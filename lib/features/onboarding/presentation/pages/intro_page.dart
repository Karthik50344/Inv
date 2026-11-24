
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';

import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';

// =============================================================================
// INTRO SLIDES
// =============================================================================

class _IntroSlide {
  const _IntroSlide({
    required this.title,
    required this.description,
    required this.animationType,
    this.showDataNotice = false,
  });

  final String title;
  final String description;
  final int animationType;
  final bool showDataNotice;
}

// =============================================================================
// INTRO PAGE
// =============================================================================

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  static const List<_IntroSlide> _slides = [
    _IntroSlide(
      title: 'Everything your business needs.',
      description:
      'Welcome to Inventrix. Manage your products, sales, purchases, '
          'expenses and business insights in one place.',
      animationType: 0,
    ),
    _IntroSlide(
      title: 'Stay in control of your stock.',
      description:
      'Organise your products, track stock levels and always know '
          'exactly what is available in your inventory.',
      animationType: 1,
    ),
    _IntroSlide(
      title: 'Simplify your billing.',
      description:
      'Create invoices, manage purchases and keep track of payments '
          'without unnecessary complexity.',
      animationType: 2,
    ),
    _IntroSlide(
      title: 'Understand your business better.',
      description:
      'Monitor expenses, review sales and use meaningful reports '
          'to make better business decisions.',
      animationType: 3,
    ),
    _IntroSlide(
      title: 'Your business data matters.',
      description:
      'Inventrix helps you manage your business information '
          'through an organised workspace.',
      animationType: 4,
      showDataNotice: true,
    ),
  ];

  bool get _isLastPage => _currentPage == _slides.length - 1;

  void _nextPage() {
    if (_isLastPage) {
      _finishIntro();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  void _skipIntro() {
    _finishIntro();
  }

  Future<void> _finishIntro() async {
    await context.read<SettingsCubit>().markIntroSeen();

    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.dashboard);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, appColors),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _IntroSlideView(
                    key: ValueKey('intro_slide_$index'),
                    slide: _slides[index],
                    index: index,
                    isActive: index == _currentPage,
                  );
                },
              ),
            ),

            _buildFooter(theme, appColors),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(
      ThemeData theme,
      AppColorTokens colors,
      ) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s16,
      ),
      child: Row(
        children: [
          Image.asset(
            isDark
                ? 'assets/branding/inventrix_symbol_dark.png'
                : 'assets/branding/inventrix_symbol.png',
            height: 38,
            width: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return Icon(
                Icons.inventory_2_rounded,
                size: 34,
                color: colors.brand.solid,
              );
            },
          ),

          const SizedBox(width: AppSpacing.s8),

          Text(
            'Inventrix',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colors.primaryText,
            ),
          ),

          const Spacer(),

          TextButton(
            key: const ValueKey('intro_skip'),
            onPressed: _skipIntro,
            child: Text(
              'Skip',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER
  // ---------------------------------------------------------------------------

  Widget _buildFooter(
      ThemeData theme,
      AppColorTokens colors,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s12,
        AppSpacing.s24,
        AppSpacing.s24,
      ),
      child: Column(
        children: [
          // Page progress indicators.
          Row(
            children: List.generate(
              _slides.length,
                  (index) {
                final isActive = index == _currentPage;

                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? colors.brand.solid
                          : colors.border,
                      borderRadius: BorderRadius.circular(
                        AppRadius.pill,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.s24),

          Row(
            children: [
              Text(
                '${_currentPage + 1} / ${_slides.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              FilledButton(
                key: const ValueKey('intro_next'),
                onPressed: _nextPage,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s24,
                    vertical: AppSpacing.s16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.controlRadius,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLastPage ? 'Get Started' : 'Continue',
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Icon(
                      _isLastPage
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INTRO SLIDE CONTENT
// =============================================================================

class _IntroSlideView extends StatelessWidget {
  const _IntroSlideView({
    super.key,
    required this.slide,
    required this.index,
    required this.isActive,
  });

  final _IntroSlide slide;
  final int index;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s24,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.s16),

            SizedBox(
              height: 280,
              width: double.infinity,
              child: _SlideAnimation(
                key: ValueKey('slide_animation_$index'),
                index: index,
                isActive: isActive,
              ),
            ),

            const SizedBox(height: AppSpacing.s32),

            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.2,
                color: colors.primaryText,
              ),
            ),

            const SizedBox(height: AppSpacing.s16),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                slide.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                  height: 1.7,
                ),
              ),
            ),

            if (slide.showDataNotice) ...[
              const SizedBox(height: AppSpacing.s24),
              _DataNotice(),
            ],

            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DATA NOTICE
// =============================================================================

class _DataNotice extends StatelessWidget {
  const _DataNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      key: const ValueKey('intro_data_notice'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: colors.brand.container,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: colors.brand.solid.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colors.brand.solid,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              AppConstants.localDataWarning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.brand.onContainer,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CONTEXT-BASED ANIMATIONS
// =============================================================================

class _SlideAnimation extends StatefulWidget {
  const _SlideAnimation({
    super.key,
    required this.index,
    required this.isActive,
  });

  final int index;
  final bool isActive;

  @override
  State<_SlideAnimation> createState() => _SlideAnimationState();
}

class _SlideAnimationState extends State<_SlideAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _SlideAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        switch (widget.index) {
          case 0:
            return _buildWelcome();

          case 1:
            return _buildInventory();

          case 2:
            return _buildBilling();

          case 3:
            return _buildReports();

          case 4:
            return _buildSecurity();

          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 1: WELCOME
  // Animated Inventrix symbol with orbiting elements.
  // ---------------------------------------------------------------------------

  Widget _buildWelcome() {
    final colors = context.appColors;
    final primary = colors.brand.solid;

    final progress = Curves.easeOutBack.transform(
      _controller.value,
    );

    final rotation = _controller.value * math.pi * 2;

    return Center(
      child: SizedBox(
        height: 250,
        width: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 210,
              width: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.05),
              ),
            ),

            Transform.rotate(
              angle: rotation,
              child: Container(
                height: 175,
                width: 175,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _bubble(
                    Icons.star_rounded,
                    primary,
                    36,
                  ),
                ),
              ),
            ),

            Transform.scale(
              scale: (0.5 + progress * 0.5).toDouble(),
              child: Container(
                height: 115,
                width: 115,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.15),
                      blurRadius: 35,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'assets/branding/inventrix_symbol_dark.png'
                          : 'assets/branding/inventrix_symbol.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return Icon(
                          Icons.inventory_2_rounded,
                          size: 58,
                          color: primary,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              right: 12,
              top: 35,
              child: Transform.scale(
                scale: progress.clamp(0.0, 1.0).toDouble(),
                child: _bubble(
                  Icons.check_circle_rounded,
                  colors.success.solid,
                  42,
                ),
              ),
            ),

            Positioned(
              left: 12,
              bottom: 35,
              child: Transform.scale(
                scale: progress.clamp(0.0, 1.0).toDouble(),
                child: _bubble(
                  Icons.bolt_rounded,
                  colors.warning.solid,
                  42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 2: INVENTORY
  // Product categories and stock cards appear separately.
  // ---------------------------------------------------------------------------

  Widget _buildInventory() {
    final colors = context.appColors;
    final primary = colors.success.solid;

    final progress = Curves.easeOutBack.transform(
      _controller.value,
    );

    return Center(
      child: SizedBox(
        height: 250,
        width: 290,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 190,
              width: 250,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(35),
              ),
            ),

            Positioned(
              bottom: 30,
              child: Transform.scale(
                scale: progress.clamp(0.0, 1.0).toDouble(),
                child: _productBox(
                  primary,
                  Icons.inventory_2_rounded,
                  'Products',
                ),
              ),
            ),

            Positioned(
              top: 20,
              left: 15,
              child: Transform.translate(
                offset: Offset(
                  -35 * (1 - progress.clamp(0.0, 1.0)),
                  0,
                ),
                child: Opacity(
                  opacity: progress.clamp(0.0, 1.0).toDouble(),
                  child: _smallProduct(
                    primary,
                    Icons.category_rounded,
                    'Categories',
                  ),
                ),
              ),
            ),

            Positioned(
              top: 20,
              right: 15,
              child: Transform.translate(
                offset: Offset(
                  35 * (1 - progress.clamp(0.0, 1.0)),
                  0,
                ),
                child: Opacity(
                  opacity: progress.clamp(0.0, 1.0).toDouble(),
                  child: _smallProduct(
                    colors.warning.solid,
                    Icons.warehouse_rounded,
                    'Stock',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productBox(
      Color color,
      IconData icon,
      String label,
      ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 65, color: color),
          const SizedBox(height: AppSpacing.s8),
          _miniLabel(label),
        ],
      ),
    );
  }

  Widget _smallProduct(
      Color color,
      IconData icon,
      String label,
      ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.appColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: AppSpacing.s4),
          _miniLabel(label),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 3: BILLING
  // Invoice slides into view, then payment confirmation appears.
  // ---------------------------------------------------------------------------

  Widget _buildBilling() {
    final colors = context.appColors;
    final primary = colors.info.solid;

    final progress = Curves.easeOutCubic.transform(
      _controller.value,
    );

    final paymentProgress = Curves.elasticOut.transform(
      ((_controller.value - 0.55) / 0.45)
          .clamp(0.0, 1.0)
          .toDouble(),
    );

    return Center(
      child: SizedBox(
        height: 260,
        width: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, 45 * (1 - progress)),
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0).toDouble(),
                child: Container(
                  width: 190,
                  height: 215,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(
                      color: colors.border,
                    ),
                    boxShadow: colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        color: primary,
                        size: 30,
                      ),

                      const SizedBox(height: AppSpacing.s16),

                      _invoiceLine(100),
                      _invoiceLine(75),
                      _invoiceLine(90),

                      const Spacer(),

                      Divider(color: colors.divider),

                      Text(
                        'TOTAL',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),

                      Text(
                        '₹ 2,450',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              right: 5,
              bottom: 20,
              child: Transform.scale(
                scale: paymentProgress,
                child: Container(
                  height: 65,
                  width: 65,
                  decoration: BoxDecoration(
                    color: colors.success.solid,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.success.solid.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              top: 25,
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0).toDouble(),
                child: _bubble(
                  Icons.currency_rupee_rounded,
                  colors.success.solid,
                  45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceLine(double width) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Container(
        height: 7,
        width: width,
        decoration: BoxDecoration(
          color: context.appColors.border,
          borderRadius: AppRadius.pillRadius,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 4: REPORTS
  // Dashboard chart bars grow from the bottom.
  // ---------------------------------------------------------------------------

  Widget _buildReports() {
    final colors = context.appColors;
    final primary = colors.warning.solid;

    final progress = Curves.easeOutCubic.transform(
      _controller.value,
    );

    const heights = [65.0, 110.0, 85.0, 145.0, 125.0];

    return Center(
      child: Container(
        height: 220,
        width: 280,
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.border),
          boxShadow: colors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: primary,
                  size: 25,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  'Business overview',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s24),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  heights.length,
                      (index) {
                    final delay = index * 0.12;

                    final value = ((progress - delay) / 0.55)
                        .clamp(0.0, 1.0)
                        .toDouble();

                    return Container(
                      width: 27,
                      height: heights[index] * value,
                      decoration: BoxDecoration(
                        color: colors.chartColor(index),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.small),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLIDE 5: SECURITY
  // Shield appears with expanding protective rings.
  // ---------------------------------------------------------------------------

  Widget _buildSecurity() {
    final colors = context.appColors;
    final primary = colors.brand.solid;

    final progress = Curves.easeOutCubic.transform(
      _controller.value,
    );

    return Center(
      child: SizedBox(
        height: 250,
        width: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 220 * progress,
              width: 220 * progress,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
            ),

            Container(
              height: 175 * progress,
              width: 175 * progress,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.06),
              ),
            ),

            Transform.scale(
              scale: (0.4 + progress * 0.6).toDouble(),
              child: Icon(
                Icons.shield_rounded,
                size: 125,
                color: primary,
              ),
            ),

            Positioned(
              right: 30,
              top: 35,
              child: Transform.scale(
                scale: progress,
                child: _bubble(
                  Icons.lock_rounded,
                  colors.success.solid,
                  42,
                ),
              ),
            ),

            Positioned(
              left: 25,
              bottom: 35,
              child: Transform.scale(
                scale: progress,
                child: _bubble(
                  Icons.verified_user_rounded,
                  primary,
                  42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED VISUAL HELPERS
  // ---------------------------------------------------------------------------

  Widget _bubble(
      IconData icon,
      Color color,
      double size,
      ) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.55,
      ),
    );
  }

  Widget _miniLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.appColors.primaryText,
      ),
    );
  }
}
