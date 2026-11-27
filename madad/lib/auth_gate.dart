import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'welcome_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Widget> _homeFuture = _getHome();

  Future<Widget> _getHome() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return const WelcomePage();
    }

    try {
      final account = await AuthService.resolveCurrentAccount();

      if (account == null || account.isDeleted) {
        await AuthService.signOut();
        return const WelcomePage();
      }

      final home = AuthService.homeFor(account);

      if (home == null) {
        await AuthService.signOut();
        return const WelcomePage();
      }

      return home;
    } catch (e) {
      debugPrint("AuthGate Error: $e");
      return const WelcomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("حدث خطأ")));
        }

        return snapshot.data ?? const WelcomePage();
      },
    );
  }
}
