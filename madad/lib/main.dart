import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:madad_app/firebase_options.dart';
import 'auth_gate.dart';
import 'welcome_page.dart';
import 'login_page.dart';
import 'role_selection_page.dart';
import 'signup_page.dart';
import 'donor_home_page.dart';
import 'view_donation_page.dart';
import 'donor_more_page.dart';
import 'app_design.dart';
import 'Beneficiary_home_page.dart';
import 'donor_delivery_method_page.dart';
import 'add_donation_page.dart';
import 'courier_home_page.dart';
import 'admin_home_page.dart';
import 'admin_beneficiaries_page.dart';
import 'courier_management_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

String _routeUserId(BuildContext context) {
  return (ModalRoute.of(context)?.settings.arguments as String?) ??
      FirebaseAuth.instance.currentUser?.uid ??
      '';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppDesign.lightTheme,

      home: user == null ? const WelcomePage() : const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/roleSelection': (context) => const RoleSelectionPage(),
        '/signup': (context) => const SignUpPage(),
        '/welcome': (context) => const WelcomePage(),

        '/donorHome': (context) => DonorHomePage(userId: _routeUserId(context)),

        '/beneficiaryHome': (context) =>
            BeneficiaryHomePage(userId: _routeUserId(context)),

        '/addDonation': (context) =>
            AddDonationPage(userId: _routeUserId(context)),

        '/viewDonation': (context) =>
            ViewDonationPage(userId: _routeUserId(context)),

        '/donorMore': (context) => DonorMorePage(userId: _routeUserId(context)),

        '/donorDelivery': (context) {
          final donationId =
              ModalRoute.of(context)?.settings.arguments as String? ?? '';

          return DonorDeliveryPage(donationId: donationId);
        },

        '/courierHome': (context) =>
            CourierHomePage(userId: _routeUserId(context)),

        '/adminBeneficiaries': (context) =>
            AdminBeneficiariesPage(userId: _routeUserId(context)),

        '/adminCouriers': (context) => const CourierManagementPage(),
      },
    );
  }
}
