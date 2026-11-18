/// One import for the shared UI kit.
///
/// Naming: the design brief calls some components `AppEmptyState`,
/// `AppErrorState` and `AppLoadingState`. Those widgets already existed under
/// shorter names and are used by every screen, so the aliases below give both
/// names without a risky rename.
library;

import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

export 'package:inventrix/shared/presentation/snackbar.dart';
export 'package:inventrix/shared/presentation/widgets/app_app_bar.dart';
export 'package:inventrix/shared/presentation/widgets/app_badge.dart';
export 'package:inventrix/shared/presentation/widgets/app_bottom_navigation.dart';
export 'package:inventrix/shared/presentation/widgets/app_bottom_sheet.dart';
export 'package:inventrix/shared/presentation/widgets/app_button.dart';
export 'package:inventrix/shared/presentation/widgets/app_card.dart';
export 'package:inventrix/shared/presentation/widgets/app_content_width.dart';
export 'package:inventrix/shared/presentation/widgets/app_chip.dart';
export 'package:inventrix/shared/presentation/widgets/app_currency_text.dart';
export 'package:inventrix/shared/presentation/widgets/app_data_table.dart';
export 'package:inventrix/shared/presentation/widgets/app_date_picker.dart';
export 'package:inventrix/shared/presentation/widgets/app_dropdown.dart';
export 'package:inventrix/shared/presentation/widgets/app_facts_card.dart';
export 'package:inventrix/shared/presentation/widgets/app_filter_button.dart';
export 'package:inventrix/shared/presentation/widgets/app_form_dialog.dart';
export 'package:inventrix/shared/presentation/widgets/app_icon_button.dart';
export 'package:inventrix/shared/presentation/widgets/app_refresh_indicator.dart';
export 'package:inventrix/shared/presentation/widgets/app_search_field.dart';
export 'package:inventrix/shared/presentation/widgets/app_section_header.dart';
export 'package:inventrix/shared/presentation/widgets/app_stat_card.dart';
export 'package:inventrix/shared/presentation/widgets/app_text_field.dart';
export 'package:inventrix/shared/presentation/widgets/app_tone.dart';
export 'package:inventrix/shared/presentation/widgets/chart_style.dart';
export 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
export 'package:inventrix/shared/presentation/widgets/document_status_chip.dart';
export 'package:inventrix/shared/presentation/widgets/empty_state.dart';
export 'package:inventrix/shared/presentation/widgets/error_state.dart';
export 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// Alias of [EmptyState].
typedef AppEmptyState = EmptyState;

/// Alias of [ErrorState].
typedef AppErrorState = ErrorState;

/// Alias of [LoadingIndicator].
typedef AppLoadingState = LoadingIndicator;
