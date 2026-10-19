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
import 'add_donation_page.dart';
import 'delivery_method_page.dart';
import 'courier_home_page.dart';
import 'admin_home_page.dart';
import 'admin_beneficiaries_page.dart';
import 'courier_management_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppDesign.lightTheme,

      home: user == null ? const WelcomePage() : const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/roleSelection': (context) => const RoleSelectionPage(),
        '/signup': (context) => SignUpPage(),
        '/welcome': (context) => const WelcomePage(),

        '/donorHome': (context) {
          final uid =
              (ModalRoute.of(context)?.settings.arguments as String?) ??
              FirebaseAuth.instance.currentUser?.uid ??
              '';

          return DonorHomePage(userId: uid);
        },

        '/beneficiaryHome': (context) {
          final uid =
              (ModalRoute.of(context)?.settings.arguments as String?) ?? userId;

          return BeneficiaryHomePage(userId: uid);
        },

        '/addDonation': (context) {
          final uid =
              (ModalRoute.of(context)?.settings.arguments as String?) ??
              FirebaseAuth.instance.currentUser?.uid ??
              '';

          return AddDonationPage(userId: uid);
        },
        '/viewDonation': (context) {
          final uid =
              (ModalRoute.of(context)?.settings.arguments as String?) ??
              FirebaseAuth.instance.currentUser?.uid ??
              '';

          return ViewDonationPage(userId: uid);
        },

        '/donorMore': (context) {
          final uid =
              (ModalRoute.of(context)?.settings.arguments as String?) ??
              FirebaseAuth.instance.currentUser?.uid ??
              '';

          return DonorMorePage(userId: uid);
        },

        '/deliveryMethod': (context) {
          final donationId =
              ModalRoute.of(context)?.settings.arguments as String? ?? '';

          return DeliveryMethodPage(donationId: donationId);
        },

        '/courierHome': (context) {
          final uid =
              (ModalRoute.of(context)?.settings.arguments as String?) ??
              FirebaseAuth.instance.currentUser?.uid ??
              '';

          return CourierHomePage(userId: uid);
        },
        // صفحة إدارة المستفيدين
        '/adminBeneficiaries': (context) {
          final uid =
              (ModalRoute.of(context)?.settings.arguments as String?) ??
              FirebaseAuth.instance.currentUser?.uid ??
              '';

          return AdminBeneficiariesPage(userId: uid);
        },

        // صفحة إدارة المناديب
        '/adminCouriers': (context) {
          return const CourierManagementPage();
        },
      },
    );
  }
}
