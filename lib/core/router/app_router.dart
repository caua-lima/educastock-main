import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/controllers/auth_provider.dart';
import 'app_navigation_shell.dart';
import 'donor_navigation_shell.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/scanner/presentation/pages/scanner_page.dart';
import '../../features/scanner/presentation/pages/product_review_page.dart';
import '../../features/products/presentation/pages/product_list_page.dart';
import '../../features/products/presentation/pages/product_detail_page.dart';
import '../../features/products/presentation/pages/product_form_page.dart';
import '../../features/batches/presentation/pages/batch_form_page.dart';
import '../../features/stock/presentation/pages/movement_page.dart';
import '../../features/stock/presentation/pages/adjustment_approvals_page.dart';
import '../../features/alerts/presentation/pages/alerts_page.dart';
import '../../features/audit/presentation/pages/audit_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/locations/presentation/pages/locations_page.dart';
import '../../features/locations/presentation/pages/location_create_page.dart';
import '../../features/settings/presentation/pages/users_management_page.dart';
import '../../features/settings/presentation/pages/categories_settings_page.dart';
import '../../features/settings/presentation/pages/alerts_settings_page.dart';
import '../../features/ml/presentation/pages/ml_insights_page.dart';
import '../../features/ml/presentation/pages/forecast_page.dart';
import '../../features/recipes/presentation/pages/recipes_page.dart';
import '../../features/recipes/presentation/pages/recipe_create_page.dart';
import '../../features/recipes/domain/entities/stock_recipe.dart';
import '../../features/stock/presentation/pages/history_page.dart';
import '../../features/donations/presentation/pages/donor_home_page.dart';
import '../../features/donations/presentation/pages/donation_needs_page.dart';
import '../../features/donations/presentation/pages/donation_need_detail_page.dart';
import '../../features/donations/presentation/pages/donation_form_page.dart';
import '../../features/donations/presentation/pages/my_donations_page.dart';
import '../../features/donations/presentation/pages/donation_detail_page.dart';
import '../../features/donations/presentation/pages/donor_profile_page.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const register = '/doador/cadastro';
  static const otpVerification = '/otp-verify';
  static const dashboard = '/dashboard';
  static const scanner = '/scanner';
  static const productReview = '/scanner/review';
  static const productList = '/products';
  static const productDetail = '/products/:id';
  static const productForm = '/products/form';
  static const batchForm = '/batches/form';
  static const movement = '/movement';
  static const adjustmentApprovals = '/movement/approvals';
  static const alerts = '/alerts';
  static const audit = '/audit';
  static const reports = '/reports';
  static const settings = '/settings';
  static const locations = '/locations';
  static const locationCreate = '/locations/new';
  static const usersManagement = '/settings/users';
  static const categoriesSettings = '/settings/categories';
  static const alertsSettings = '/settings/alerts';
  static const mlInsights = '/ml/insights';
  static const mlForecast = '/ml/forecast';
  static const recipes = '/recipes';
  static const recipeCreate = '/recipes/new';
  static const history = '/history';

  // ─── Portal do Doador (Sprint 2/3: telas D01–D12) ─────────────────────────
  static const donorHome = '/doador';
  static const donorNeeds = '/doador/necessidades';
  static const donorNeedDetail = '/doador/necessidades/:id';
  static const donorDonate = '/doador/doar';
  static const donorDonations = '/doador/doacoes';
  static const donorDonationDetail = '/doador/doacoes/:id';
  static const donorProfile = '/doador/perfil';

  static String donorNeedDetailPath(String id) => '$donorNeeds/$id';
  static String donorDonationDetailPath(String id) => '$donorDonations/$id';
  static String donorDonatePath({String? needId}) =>
      (needId == null || needId.isEmpty)
          ? donorDonate
          : Uri(path: donorDonate, queryParameters: {'needId': needId}).toString();
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  ref.watch(pendingOtpProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      if (auth.isLoading) return null;

      final user = auth.valueOrNull;
      final isLoggedIn = user != null;
      final isDonor = user?.isDonor ?? false;
      final location = state.matchedLocation;
      final pendingOtp = ref.read(pendingOtpProvider);
      final homeForRole = isDonor ? AppRoutes.donorHome : AppRoutes.dashboard;

      final isPublicRoute = {
        AppRoutes.login,
        AppRoutes.register,
      }.contains(location);

      final isDonorArea = location == AppRoutes.donorHome ||
          location.startsWith('${AppRoutes.donorHome}/');

      // Guard: OTP page
      if (location == AppRoutes.otpVerification) {
        if (!isLoggedIn) return AppRoutes.login;
        if (!pendingOtp) return homeForRole;
        return null;
      }

      // If authenticated with pending OTP, force to OTP page
      if (isLoggedIn && pendingOtp) return AppRoutes.otpVerification;

      if (!isLoggedIn && !isPublicRoute) return AppRoutes.login;
      if (isLoggedIn && isPublicRoute) return homeForRole;

      // Isolamento por papel: doador só circula em /doador/*; a equipe não
      // entra na área do doador (RN-D13, achado F3).
      if (isLoggedIn && isDonor && !isDonorArea) return AppRoutes.donorHome;
      if (isLoggedIn && !isDonor && isDonorArea) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        builder: (_, __) => const OtpVerificationPage(),
      ),
      // Rotas fora do ShellRoute — não exibem TabBar nem AppNavigationShell.
      // Isso evita conflitos de GlobalKey ao navegar entre rotas de shell e
      // não-shell (erro: '!keyReservation.contains(key)': is not true).
      GoRoute(
        path: AppRoutes.scanner,
        builder: (_, __) => const ScannerPage(),
      ),
      GoRoute(
        path: AppRoutes.productReview,
        builder: (_, state) {
          final barcode = state.uri.queryParameters['barcode'] ?? '';
          return ProductReviewPage(barcode: barcode);
        },
      ),
      // productForm e batchForm também fora do ShellRoute: são formulários
      // de tela cheia que não precisam da TabBar, e são acessados a partir
      // de ProductReviewPage (fora do shell), evitando o conflito de keys.
      GoRoute(
        path: AppRoutes.productForm,
        builder: (_, state) {
          final productId = state.uri.queryParameters['id'];
          final barcode = state.uri.queryParameters['barcode'];
          final prefillName = state.uri.queryParameters['name'];
          final prefillBrand = state.uri.queryParameters['brand'];
          final prefillCategory = state.uri.queryParameters['category'];
          final prefillImageUrl = state.uri.queryParameters['imageUrl'];
          final prefillIsPerishable = state.uri.queryParameters['isPerishable'];
          final prefillUnit = state.uri.queryParameters['unit'];
          final prefillUnitSize = state.uri.queryParameters['unitSize'];
          final prefillDescription = state.uri.queryParameters['desc'];
          return ProductFormPage(
            productId: productId,
            barcode: barcode,
            prefillName: prefillName,
            prefillBrand: prefillBrand,
            prefillCategory: prefillCategory,
            prefillImageUrl: prefillImageUrl,
            prefillIsPerishable: prefillIsPerishable,
            prefillUnit: prefillUnit,
            prefillUnitSize: prefillUnitSize,
            prefillDescription: prefillDescription,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.batchForm,
        builder: (_, state) {
          final productId = state.uri.queryParameters['productId'] ?? '';
          final batchId = state.uri.queryParameters['id'] ?? '';
          return BatchFormPage(productId: productId, batchId: batchId);
        },
      ),
      // Formulário de doação (D06–D07): tela cheia, fora de qualquer shell.
      GoRoute(
        path: AppRoutes.donorDonate,
        builder: (_, state) =>
            DonationFormPage(needId: state.uri.queryParameters['needId']),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppNavigationShell(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.productList,
            builder: (_, __) => const ProductListPage(),
          ),
          GoRoute(
            path: AppRoutes.productDetail,
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '';
              return ProductDetailPage(productId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.movement,
            builder: (_, state) {
              final batchId = state.uri.queryParameters['batchId'] ?? '';
              final productId = state.uri.queryParameters['productId'];
              final reason = state.uri.queryParameters['reason'];
              return MovementPage(
                batchId: batchId,
                prefillProductId: productId,
                prefillReason: reason,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.adjustmentApprovals,
            builder: (_, __) => const AdjustmentApprovalsPage(),
          ),
          GoRoute(
            path: AppRoutes.alerts,
            builder: (_, __) => const AlertsPage(),
          ),
          GoRoute(
            path: AppRoutes.audit,
            builder: (_, __) => const AuditPage(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (_, __) => const ReportsPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.locations,
            builder: (_, __) => const LocationsPage(),
          ),
          GoRoute(
            path: AppRoutes.locationCreate,
            builder: (_, __) => const LocationCreatePage(),
          ),
          GoRoute(
            path: AppRoutes.usersManagement,
            builder: (_, __) => const UsersManagementPage(),
          ),
          GoRoute(
            path: AppRoutes.categoriesSettings,
            builder: (_, __) => const CategoriesSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.alertsSettings,
            builder: (_, __) => const AlertsSettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.mlInsights,
            builder: (_, __) => const MlInsightsPage(),
          ),
          GoRoute(
            path: AppRoutes.mlForecast,
            builder: (_, __) => const ForecastPage(),
          ),
          GoRoute(
            path: AppRoutes.recipes,
            builder: (_, __) => const RecipesPage(),
          ),
          GoRoute(
            path: AppRoutes.recipeCreate,
            builder: (context, state) {
              final recipe = state.extra as StockRecipe?;
              return RecipeCreatePage(editRecipe: recipe);
            },
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (_, __) => const HistoryPage(),
          ),
        ],
      ),
      // Shell próprio do doador (5 abas), independente do shell da equipe.
      ShellRoute(
        builder: (context, state, child) {
          return DonorNavigationShell(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.donorHome,
            builder: (_, __) => const DonorHomePage(),
          ),
          GoRoute(
            path: AppRoutes.donorNeeds,
            builder: (_, __) => const DonationNeedsPage(),
          ),
          GoRoute(
            path: AppRoutes.donorNeedDetail,
            builder: (_, state) =>
                DonationNeedDetailPage(needId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: AppRoutes.donorDonations,
            builder: (_, __) => const MyDonationsPage(),
          ),
          GoRoute(
            path: AppRoutes.donorDonationDetail,
            builder: (_, state) =>
                DonationDetailPage(donationId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: AppRoutes.donorProfile,
            builder: (_, __) => const DonorProfilePage(),
          ),
        ],
      ),
    ],
  );
});
