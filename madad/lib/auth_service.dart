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
  final bool isDeleted;
  final Map<String, dynamic> data;

  const AppAccount({
    required this.userId,
    required this.role,
    required this.isDeleted,
    required this.data,
  });

  factory AppAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppAccount(
      userId: doc.id,
      role: (data['role'] ?? '').toString().trim().toLowerCase(),
      isDeleted: false,
      data: data,
    );
  }

  AppAccount markDeleted(bool deleted) =>
      AppAccount(userId: userId, role: role, isDeleted: deleted, data: data);
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

    final account = await _findAccount(user);
    if (account == null || account.isDeleted) return account;

    return account.markDeleted(await _isDeleted(account));
  }

  static Future<AppAccount?> _findAccount(User user) async {
    final ownDoc = await _users.doc(user.uid).get();
    if (ownDoc.exists) return AppAccount.fromDoc(ownDoc);

    final authPhone = user.phoneNumber;
    if (authPhone == null || authPhone.isEmpty) return null;

    final invites = _db.collection('couriers');
    final inviteRef = invites.doc(PhoneUtils.toLocal(authPhone));
    final invite = await inviteRef.get();
    if (!invite.exists) return null;

    final data = invite.data() ?? <String, dynamic>{};
    final userData = {
      'firstName': (data['firstName'] ?? '').toString(),
      'lastName': (data['lastName'] ?? '').toString(),
      'phone': (data['phone'] ?? '').toString(),
      'role': 'courier',
    };
    final account = AppAccount(
      userId: user.uid,
      role: 'courier',
      isDeleted: false,
      data: userData,
    );

    if ((data['status'] ?? '').toString().trim().toLowerCase() == 'deleted') {
      return account.markDeleted(true);
    }

    final batch = _db.batch();
    batch.set(_users.doc(user.uid), userData);
    batch.set(invites.doc(user.uid), {
      'userID': user.uid,
      'status': (data['status'] ?? 'active').toString(),
      'city': (data['city'] ?? '').toString(),
      'completedDeliveries': 0,
    });
    batch.delete(inviteRef);
    await batch.commit();

    return account;
  }

  static Future<bool> _isDeleted(AppAccount account) async {
    if (account.role == 'beneficiary') {
      final doc = await _db
          .collection('beneficiaries')
          .doc(account.userId)
          .get();
      return (doc.data()?['status'] ?? '').toString().trim().toLowerCase() ==
          'deleted';
    }

    if (account.role == 'courier') {
      final doc = await _db.collection('couriers').doc(account.userId).get();
      return (doc.data()?['status'] ?? '').toString().trim().toLowerCase() ==
          'deleted';
    }

    return false;
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
