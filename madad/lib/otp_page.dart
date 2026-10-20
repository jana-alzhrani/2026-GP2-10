import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'donor_home_page.dart';
import 'Beneficiary_home_page.dart';
import 'admin_home_page.dart';
import 'courier_home_page.dart';
import 'app_design.dart';

class OtpPage extends StatefulWidget {
  String correctCode;

  final String firstName;
  final String lastName;
  final String phone;
  final bool isLogin;

  // بيانات إضافية لتسجيل المستفيد
  final String role;
  final String? socialSecurityNumber;
  final String? socialSecurityPdfUrl;
  final Uint8List? socialSecurityPdfBytes;
  final String? socialSecurityPdfName;

  OtpPage({
    super.key,
    required this.correctCode,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.isLogin,
    this.role = 'donor',
    this.socialSecurityNumber,
    this.socialSecurityPdfUrl,
    this.socialSecurityPdfBytes,
    this.socialSecurityPdfName,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController codeController = TextEditingController();

  Timer? _timer;

  int seconds = 60;
  bool canResend = false;
  bool isVerifying = false;
  bool isResending = false;

  int? resendToken;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  String formatPhoneNumber(String phone) {
    final value = phone.trim();

    if (value.startsWith('+966')) {
      return value;
    } else if (value.startsWith('966')) {
      return '+$value';
    } else if (value.startsWith('05')) {
      return '+966${value.substring(1)}';
    } else if (value.startsWith('5')) {
      return '+966$value';
    }

    return value;
  }

  void startTimer() {
    _timer?.cancel();

    setState(() {
      seconds = 60;
      canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (seconds > 0) {
        setState(() {
          seconds--;
        });
      } else {
        setState(() {
          canResend = true;
        });

        timer.cancel();
      }
    });
  }

  Future<void> resendCode() async {
    if (!canResend || isResending) return;

    setState(() {
      isResending = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formatPhoneNumber(widget.phone),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          AppDesign.showErrorSnackBar(
            context,
            e.message ?? 'فشل إرسال رمز التحقق',
          );
        },
        codeSent: (String verificationId, int? token) {
          if (!mounted) return;

          setState(() {
            widget.correctCode = verificationId;
            resendToken = token;
          });

          AppDesign.showSuccessSnackBar(context, 'تم إرسال رمز تحقق جديد');

          startTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          widget.correctCode = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        AppDesign.showErrorSnackBar(
          context,
          'تعذر إعادة إرسال الرمز، حاول مرة أخرى',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  Future<void> verifyCode() async {
    if (isVerifying) return;

    final smsCode = codeController.text.trim();

    if (smsCode.isEmpty) {
      AppDesign.showErrorSnackBar(context, 'أدخل رمز التحقق');
      return;
    }

    if (smsCode.length != 6) {
      AppDesign.showErrorSnackBar(context, 'أدخل رمز التحقق المكون من 6 أرقام');
      return;
    }

    setState(() {
      isVerifying = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.correctCode,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('تعذر تسجيل الدخول');
      }

      final uid = currentUser.uid;
      final users = FirebaseFirestore.instance.collection('Users');

      // تسجيل الدخول: البحث عن الحساب برقم الجوال
      if (widget.isLogin) {
        final localPhone = widget.phone.trim();
        final internationalPhone = formatPhoneNumber(widget.phone);

        QuerySnapshot<Map<String, dynamic>> userCheck = await users
            .where('phone', isEqualTo: localPhone)
            .limit(1)
            .get();

        if (userCheck.docs.isEmpty) {
          userCheck = await users
              .where('phone', isEqualTo: internationalPhone)
              .limit(1)
              .get();
        }

        if (userCheck.docs.isEmpty) {
          userCheck = await users
              .where('phoneNumber', isEqualTo: internationalPhone)
              .limit(1)
              .get();
        }

        if (userCheck.docs.isEmpty) {
          userCheck = await users
              .where('phoneNumber', isEqualTo: localPhone)
              .limit(1)
              .get();
        }

        if (userCheck.docs.isEmpty) {
          await FirebaseAuth.instance.signOut();

          if (mounted) {
            AppDesign.showErrorSnackBar(
              context,
              'رقم الجوال غير مرتبط بحساب مسجل',
            );
          }

          return;
        }

        final matchedUser = userCheck.docs.first;
        final userData = matchedUser.data();
        final appUserId = matchedUser.id;

        final role = (userData['role'] ?? '').toString().trim().toLowerCase();

        if (!mounted) return;

        if (role == 'courier') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => CourierHomePage(userId: appUserId),
            ),
            (route) => false,
          );
        } else if (role == 'donor') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => DonorHomePage(userId: appUserId)),
            (route) => false,
          );
        } else if (role == 'beneficiary') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => BeneficiaryHomePage(userId: appUserId),
            ),
            (route) => false,
          );
        } else if (role == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => AdminHomePage(userId: appUserId)),
            (route) => false,
          );
        } else {
          await FirebaseAuth.instance.signOut();

          if (mounted) {
            AppDesign.showErrorSnackBar(context, 'نوع الحساب غير معروف');
          }
        }

        return;
      }

      // إنشاء حساب جديد: المتبرع أو المستفيد فقط
      final userRef = users.doc(uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        final role = widget.role.trim().toLowerCase();

        if (role != 'donor' && role != 'beneficiary') {
          await FirebaseAuth.instance.signOut();

          if (mounted) {
            AppDesign.showErrorSnackBar(context, 'نوع الحساب غير معروف');
          }

          return;
        }

        String? uploadedPdfUrl = widget.socialSecurityPdfUrl;

        // رفع ملف الضمان للمستفيد بعد التحقق من رقم الجوال
        if (role == 'beneficiary') {
          final pdfBytes = widget.socialSecurityPdfBytes;

          if (pdfBytes == null || pdfBytes.isEmpty) {
            throw Exception('ملف الضمان الاجتماعي غير موجود');
          }

          final storageRef = FirebaseStorage.instance.ref().child(
            'beneficiary_documents/$uid/social_security.pdf',
          );

          await storageRef.putData(
            pdfBytes,
            SettableMetadata(contentType: 'application/pdf'),
          );

          uploadedPdfUrl = await storageRef.getDownloadURL();
        }

        // بيانات المستخدم الأساسية بدون الإيميل
        final userData = <String, dynamic>{
          'userId': uid,
          'firstName': widget.firstName.trim(),
          'lastName': widget.lastName.trim(),
          'phone': widget.phone.trim(),
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // بيانات حالة المستفيد داخل Users
        if (role == 'beneficiary') {
          userData.addAll({'status': 'pending', 'isVerified': false});
        }

        // إنشاء المستخدم داخل Users
        await userRef.set(userData);

        // إنشاء بيانات المستفيد في Collection beneficiaries

        if (role == 'beneficiary') {
          final beneficiaryRef = FirebaseFirestore.instance
              .collection('beneficiaries')
              .doc(uid);

          await beneficiaryRef.set({
            'userId': uid,
            'socialSecurityNumber': widget.socialSecurityNumber ?? '',
            'socialSecurityPdfUrl': uploadedPdfUrl ?? '',
            'status': 'pending',
          });
        }

        if (!mounted) return;

        if (role == 'beneficiary') {
          AppDesign.showSuccessSnackBar(
            context,
            'تم إنشاء حسابك، طلبك قيد المراجعة',
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => BeneficiaryHomePage(userId: uid)),
            (route) => false,
          );
        } else {
          AppDesign.showSuccessSnackBar(context, 'أهلاً وسهلاً بك');

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => DonorHomePage(userId: uid)),
            (route) => false,
          );
        }

        return;
      }

      // إذا كان حساب التسجيل موجودًا مسبقًا
      final userData = userDoc.data() ?? {};
      final role = (userData['role'] ?? '').toString().trim().toLowerCase();

      if (!mounted) return;

      if (role == 'donor') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => DonorHomePage(userId: uid)),
          (route) => false,
        );
      } else if (role == 'beneficiary') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BeneficiaryHomePage(userId: uid)),
          (route) => false,
        );
      } else if (role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => AdminHomePage(userId: uid)),
          (route) => false,
        );
      } else {
        AppDesign.showErrorSnackBar(context, 'نوع الحساب غير معروف');
      }
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

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء التحقق من الرمز');

      codeController.clear();
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // صورة وشعار مدد
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
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
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
