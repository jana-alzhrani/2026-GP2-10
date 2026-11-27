import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_home_page.dart';
import 'Beneficiary_home_page.dart';
import 'courier_home_page.dart';
import 'donor_home_page.dart';

class PhoneUtils {
  PhoneUtils._();

  static final RegExp _localPattern = RegExp(r'^05\d{8}$');

  static String _clean(String input) =>
      input.replaceAll(RegExp(r'[\s\-()]'), '').trim();

  static String toLocal(String input) {
    final value = _clean(input);
    if (value.startsWith('+966')) return '0${value.substring(4)}';
    if (value.startsWith('00966')) return '0${value.substring(5)}';
    if (value.startsWith('966')) return '0${value.substring(3)}';
    if (value.startsWith('5') && value.length == 9) return '0$value';
    return value;
  }

  static String toInternational(String input) {
    final local = toLocal(input);
    if (local.startsWith('0')) return '+966${local.substring(1)}';
    return local;
  }

  static bool isValidLocal(String input) =>
      _localPattern.hasMatch(input.trim());
}

class AppAccount {
  final String userId;
  final String role;
  final String status;
  final Map<String, dynamic> data;

  const AppAccount({
    required this.userId,
    required this.role,
    required this.status,
    required this.data,
  });

  factory AppAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppAccount(
      userId: doc.id,
      role: (data['role'] ?? '').toString().trim().toLowerCase(),
      status: (data['status'] ?? '').toString().trim().toLowerCase(),
      data: data,
    );
  }

  bool get isDeleted => status == 'deleted';
}

class AccountLinkedElsewhereException implements Exception {
  const AccountLinkedElsewhereException();
}

class AuthService {
  AuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('Users');

  static Future<void> sendCode({
    required String phone,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Object error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: PhoneUtils.toInternational(phone),
        forceResendingToken: resendToken,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint('verifyPhoneNumber failed: ${e.code} ${e.message}');
          onError(e);
        },
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      debugPrint('verifyPhoneNumber error: $e');
      onError(e);
    }
  }

  static Future<AppAccount?> resolveCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final linkDoc = await _db.collection('authLinks').doc(user.uid).get();
    if (linkDoc.exists) {
      final linkedId = (linkDoc.data()?['userId'] ?? '').toString();
      if (linkedId.isNotEmpty) {
        final linkedUser = await _users.doc(linkedId).get();
        if (linkedUser.exists) return AppAccount.fromDoc(linkedUser);
      }
    }

    final ownDoc = await _users.doc(user.uid).get();
    if (ownDoc.exists) return AppAccount.fromDoc(ownDoc);

    final authPhone = user.phoneNumber;
    if (authPhone == null || authPhone.isEmpty) return null;

    final candidates = {
      PhoneUtils.toLocal(authPhone),
      PhoneUtils.toInternational(authPhone),
    };

    for (final value in candidates) {
      final match = await _users
          .where('phone', isEqualTo: value)
          .limit(1)
          .get();
      if (match.docs.isEmpty) continue;

      final account = AppAccount.fromDoc(match.docs.first);

      if (account.role != 'courier' && account.role != 'admin') {
        throw const AccountLinkedElsewhereException();
      }

      if (!account.isDeleted) {
        await _db.collection('authLinks').doc(user.uid).set({
          'userId': account.userId,
          'role': account.role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return account;
    }

    return null;
  }

  static Widget? homeFor(AppAccount account) {
    switch (account.role) {
      case 'donor':
        return DonorHomePage(userId: account.userId);
      case 'beneficiary':
        return BeneficiaryHomePage(userId: account.userId);
      case 'courier':
        return CourierHomePage(userId: account.userId);
      case 'admin':
        return AdminHomePage(userId: account.userId);
      default:
        return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }
}

