import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'donor_home_page.dart';
import 'Beneficiary_home_page.dart';
import 'app_design.dart';
import 'auth_service.dart';

class OtpPage extends StatefulWidget {
  final String verificationId;
  final int? resendToken;

  final String firstName;
  final String lastName;
  final String phone;
  final bool isLogin;

  final String role;
  final String? socialSecurityNumber;
  final Uint8List? socialSecurityPdfBytes;
  final String? socialSecurityPdfName;

  const OtpPage({
    super.key,
    required this.verificationId,
    this.resendToken,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.isLogin,
    this.role = 'donor',
    this.socialSecurityNumber,
    this.socialSecurityPdfBytes,
    this.socialSecurityPdfName,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController codeController = TextEditingController();

  Timer? _timer;

  late String _verificationId = widget.verificationId;
  late int? _resendToken = widget.resendToken;

  int seconds = 60;
  bool canResend = false;
  bool isVerifying = false;
  bool isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    seconds = 60;
    canResend = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (seconds > 0) {
        setState(() => seconds--);
      } else {
        setState(() => canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> resendCode() async {
    if (!canResend || isResending) return;

    setState(() => isResending = true);

    await AuthService.sendCode(
      phone: widget.phone,
      resendToken: _resendToken,
      onCodeSent: (verificationId, token) {
        if (!mounted) return;

        setState(() {
          _verificationId = verificationId;
          _resendToken = token;
          isResending = false;
          _startTimer();
        });

        AppDesign.showSuccessSnackBar(context, 'تم إرسال رمز تحقق جديد');
      },
      onError: (error) {
        if (!mounted) return;

        setState(() => isResending = false);

        AppDesign.showErrorSnackBar(
          context,
          error is FirebaseAuthException
              ? (error.message ?? 'فشل إرسال رمز التحقق')
              : 'تعذر إعادة إرسال الرمز، حاول مرة أخرى',
        );
      },
    );
  }

  void _goTo(Widget page) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  Future<void> _failAndSignOut(String message) async {
    await AuthService.signOut();
    if (!mounted) return;
    AppDesign.showErrorSnackBar(context, message);
  }

  Future<void> verifyCode() async {
    if (isVerifying) return;

    final smsCode = codeController.text.trim();

    if (smsCode.isEmpty) {
      AppDesign.showErrorSnackBar(context, 'أدخل رمز التحقق');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      AppDesign.showErrorSnackBar(context, 'أدخل رمز التحقق المكون من 6 أرقام');
      return;
    }

    setState(() => isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final account = await AuthService.resolveCurrentAccount();

      if (account != null) {
        await _openExistingAccount(account);
        return;
      }

      if (widget.isLogin) {
        await _failAndSignOut('رقم الجوال غير مرتبط بحساب مسجل');
        return;
      }

      final role = widget.role.trim().toLowerCase();

      if (role == 'donor') {
        await _createDonor();
      } else if (role == 'beneficiary') {
        await _createBeneficiary();
      } else {
        await _failAndSignOut('نوع الحساب غير معروف');
      }
    } on AccountLinkedElsewhereException {
      await _failAndSignOut('رقم الجوال مستخدم مسبقاً');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'invalid-verification-code') {
        AppDesign.showErrorSnackBar(context, 'رمز التحقق غير صحيح');
      } else if (e.code == 'session-expired') {
        AppDesign.showErrorSnackBar(
          context,
          'انتهت صلاحية الرمز، أعد إرسال رمز جديد',
        );
      } else {
        AppDesign.showErrorSnackBar(
          context,
          e.message ?? 'تعذر التحقق من الرمز',
        );
      }

      codeController.clear();
    } catch (e) {
      debugPrint('OTP verification error: $e');

      await AuthService.signOut();

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء التحقق من الرمز');

      codeController.clear();
    } finally {
      if (mounted) {
        setState(() => isVerifying = false);
      }
    }
  }

  Future<void> _openExistingAccount(AppAccount account) async {
    if (account.isDeleted) {
      await _failAndSignOut('تم إيقاف هذا الحساب');
      return;
    }

    final home = AuthService.homeFor(account);

    if (home == null) {
      await _failAndSignOut('نوع الحساب غير معروف');
      return;
    }

    if (!mounted) return;
    _goTo(home);
  }

  Future<void> _createDonor() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('Users').doc(uid).set({
      'userId': uid,
      'firstName': widget.firstName.trim(),
      'lastName': widget.lastName.trim(),
      'phone': PhoneUtils.toLocal(widget.phone),
      'role': 'donor',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    AppDesign.showSuccessSnackBar(context, 'أهلاً وسهلاً بك');
    _goTo(DonorHomePage(userId: uid));
  }

  Future<void> _createBeneficiary() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    final socialSecurityNumber = (widget.socialSecurityNumber ?? '').trim();
    final pdfBytes = widget.socialSecurityPdfBytes;

    if (socialSecurityNumber.isEmpty || pdfBytes == null || pdfBytes.isEmpty) {
      throw Exception('بيانات المستفيد غير مكتملة');
    }

    final pdfPath = 'beneficiary_documents/$uid/social_security.pdf';
    final storageRef = FirebaseStorage.instance.ref(pdfPath);

    await storageRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    final pdfUrl = await storageRef.getDownloadURL();

    final batch = db.batch();

    batch.set(db.collection('Users').doc(uid), {
      'userId': uid,
      'firstName': widget.firstName.trim(),
      'lastName': widget.lastName.trim(),
      'phone': PhoneUtils.toLocal(widget.phone),
      'role': 'beneficiary',
      'status': 'pending',
      'isVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(db.collection('beneficiaries').doc(uid), {
      'userId': uid,
      'socialSecurityNumber': socialSecurityNumber,
      'socialSecurityPdfUrl': pdfUrl,
      'socialSecurityPdfPath': pdfPath,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (e) {
      try {
        await storageRef.delete();
      } catch (_) {}
      rethrow;
    }

    if (!mounted) return;

    AppDesign.showSuccessSnackBar(context, 'تم إنشاء حسابك، طلبك قيد المراجعة');
    _goTo(BeneficiaryHomePage(userId: uid));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/madad_icon.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: () {
                      codeController.clear();
                      FocusScope.of(context).unfocus();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: AppPadding.screen,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 70, color: AppDesign.primary),
                  AppGap.md,
                  Text(
                    'أدخل رمز التحقق',
                    style: AppDesign.h2Style.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppGap.md,
                  Text(
                    'أدخل الرمز المرسل إلى رقم جوالك',
                    textAlign: TextAlign.center,
                    style: AppDesign.bodySecondaryStyle,
                  ),
                  AppGap.md,
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: TextStyle(
                        fontFamily: AppDesign.fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppDesign.white,
                        hintText: '••••••',
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: AppDesign.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: AppDesign.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: AppDesign.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppGap.lg,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.primary,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                    onPressed: isVerifying ? null : verifyCode,
                    child: isVerifying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'تأكيد',
                            style: AppDesign.buttonOnPrimaryStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  AppGap.md,
                  TextButton(
                    onPressed: canResend && !isResending ? resendCode : null,
                    child: Text(
                      isResending
                          ? 'جارٍ إرسال الرمز...'
                          : canResend
                          ? 'إعادة إرسال الكود'
                          : 'إعادة الإرسال خلال $seconds ثانية',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
