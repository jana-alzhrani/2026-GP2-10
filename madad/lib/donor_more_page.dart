import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_design.dart';

class DonorMorePage extends StatefulWidget {
  final String userId;

  const DonorMorePage({super.key, required this.userId});

  @override
  State<DonorMorePage> createState() => _DonorMorePageState();
}

class _DonorMorePageState extends State<DonorMorePage> {
  int _bottomNavIndex = 2;

  String firstName = '';
  String lastName = '';
  String phone = '';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();

      if (!mounted) return;

      final data = userDoc.data() ?? {};

      setState(() {
        firstName = (data['firstName'] ?? '').toString().trim();
        lastName = (data['lastName'] ?? '').toString().trim();
        phone = (data['phone'] ?? '').toString().trim();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');

      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // فتح نافذة تعديل البيانات
  Future<void> _showEditNameSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DonorEditNameSheet(
        userId: widget.userId,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      firstName = result['firstName'] ?? firstName;
      lastName = result['lastName'] ?? lastName;
      phone = result['phone'] ?? phone;
    });

    AppDesign.showSuccessSnackBar(context, 'تم تحديث البيانات بنجاح');
  }

  // تسجيل الخروج
  Future<void> _showLogoutDialog() async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد من تسجيل الخروج؟',
      confirmText: 'تسجيل الخروج',
      cancelText: 'إلغاء',
    );

    if (!confirm) return;

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: AppPadding.screen.copyWith(
                          top: 18,
                          bottom: 18,
                        ),
                        child: Column(
                          children: [
                            _buildPersonalCard(),
                            const SizedBox(height: 26),
                            _buildDivider(),
                            const SizedBox(height: 24),
                            _buildAboutMadadCard(),
                            const SizedBox(height: 26),
                            _buildLogoutButton(),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      height: 150,
      child: Image.asset('assets/images/madad_identity.png', fit: BoxFit.cover),
    );
  }

  // بطاقة البيانات الشخصية
  Widget _buildPersonalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'البيانات الشخصية',
                  textAlign: TextAlign.right,
                  style: AppDesign.h1Style.copyWith(
                    color: AppDesign.primary,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // زر تعديل مطابق للمستفيد
              InkWell(
                onTap: _showEditNameSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesign.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppDesign.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'تعديل',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppDesign.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          _buildInfoField(
            label: 'الاسم الأول',
            value: firstName,
            icon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 16),

          _buildInfoField(
            label: 'الاسم الأخير',
            value: lastName,
            icon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 16),

          _buildInfoField(
            label: 'رقم الجوال',
            value: phone,
            icon: Icons.phone_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: TextAlign.right,
          style: AppDesign.bodyStyle.copyWith(
            color: AppDesign.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          height: AppDesign.inputHeight,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppDesign.white,
            borderRadius: BorderRadius.circular(AppDesign.radiusLG),
            border: Border.all(color: AppDesign.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesign.subtitleStyle.copyWith(
                    color: AppDesign.primary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Icon(icon, color: AppDesign.primary, size: 22),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppDesign.primary.withValues(alpha: 0.35),
            thickness: 1.1,
            endIndent: 12,
          ),
        ),
        Icon(Icons.local_florist_outlined, color: AppDesign.primary, size: 30),
        Expanded(
          child: Divider(
            color: AppDesign.primary.withValues(alpha: 0.35),
            thickness: 1.1,
            indent: 12,
          ),
        ),
      ],
    );
  }

  // حول مدد
  Widget _buildAboutMadadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              _circleIcon(Icons.info_outline_rounded),
              const SizedBox(width: 12),
              Text(
                'حول مدد',
                style: AppDesign.h1Style.copyWith(
                  color: AppDesign.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: AppDesign.border, thickness: 1),
          const SizedBox(height: 20),

          // موقع المستودع
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _circleIcon(Icons.storefront_outlined),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'موقع المستودع',
                        textAlign: TextAlign.right,
                        style: AppDesign.subtitleStyle.copyWith(
                          color: AppDesign.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'مستودع مدد - واجهة الرياض',
                        textAlign: TextAlign.right,
                        style: AppDesign.bodyStyle.copyWith(
                          color: AppDesign.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              SizedBox(
                height: 48,
                width: 140,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=24.768932,46.728328',
                    );

                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },

                  icon: Icon(
                    Icons.location_on_outlined,
                    color: AppDesign.primary,
                    size: 18,
                  ),

                  label: Text(
                    'فتح الخريطة',
                    style: AppDesign.bodyStyle.copyWith(
                      color: AppDesign.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    side: BorderSide(
                      color: AppDesign.primary.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesign.radiusLG),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: AppDesign.border, thickness: 1),
          const SizedBox(height: 20),

          // ساعات العمل
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _circleIcon(Icons.access_time_rounded),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'ساعات العمل',
                        textAlign: TextAlign.right,
                        style: AppDesign.subtitleStyle.copyWith(
                          color: AppDesign.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الأحد - الخميس: 9:00 ص - 5:00 م\n'
                        'الجمعة والسبت: مغلق',
                        textAlign: TextAlign.right,
                        style: AppDesign.bodyStyle.copyWith(
                          color: AppDesign.textSecondary,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
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

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppDesign.secondary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppDesign.primary, size: 24),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _showLogoutDialog,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'تسجيل الخروج',
            style: AppDesign.subtitleStyle.copyWith(
              color: Colors.red,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppDesign.white,
      borderRadius: BorderRadius.circular(AppDesign.radiusXL),
      border: Border.all(color: AppDesign.border),
      boxShadow: [
        BoxShadow(
          color: AppDesign.black.withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppDesign.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: NavigationBar(
        height: 78,
        selectedIndex: _bottomNavIndex,
        backgroundColor: Colors.transparent,
        indicatorColor: AppDesign.secondary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == _bottomNavIndex && index == 2) {
            return;
          }

          setState(() {
            _bottomNavIndex = index;
          });

          if (index == 0) {
            Navigator.pushReplacementNamed(
              context,
              '/donorHome',
              arguments: widget.userId,
            );
          } else if (index == 1) {
            Navigator.pushReplacementNamed(
              context,
              '/viewDonation',
              arguments: widget.userId,
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppDesign.primary),
            selectedIcon: Icon(Icons.home_rounded, color: AppDesign.primary),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.volunteer_activism_outlined,
              color: AppDesign.primary,
            ),
            selectedIcon: Icon(
              Icons.volunteer_activism_rounded,
              color: AppDesign.primary,
            ),
            label: 'تبرعاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded, color: AppDesign.primary),
            selectedIcon: Icon(
              Icons.more_horiz_rounded,
              color: AppDesign.primary,
            ),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}

// ======================================================
// نافذة تعديل البيانات الشخصية
// تغيير رقم الجوال مع التحقق من OTP عبر Firebase Auth
// ======================================================

class _DonorEditNameSheet extends StatefulWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;

  const _DonorEditNameSheet({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  @override
  State<_DonorEditNameSheet> createState() => _DonorEditNameSheetState();
}

class _DonorEditNameSheetState extends State<_DonorEditNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _phoneCtrl;
  final _otpCtrl = TextEditingController();

  String? _verificationId;
  int? _resendToken;
  Timer? _timer;
  int _seconds = 60;

  bool _otpSent = false;
  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;
  String? _error;

  // true بعد نجاح تحديث الرقم في Firebase Auth.
  // إذا فشل بعدها حفظ Firestore نعيد المحاولة لـ Firestore فقط
  // بدون إعادة التحقق من الرمز (لأنه استُهلك).
  bool _authPhoneUpdated = false;
  String? _pendingLocalPhone;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.firstName);
    _lastCtrl = TextEditingController(text: widget.lastName);
    _phoneCtrl = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'هذا الحقل مطلوب';
    if (text.length < 2) return 'الاسم قصير جداً';
    return null;
  }

  String _normalizePhone(String input) {
    final value = input.replaceAll(RegExp(r'[\s\-()]'), '').trim();

    if (value.startsWith('+966')) return value;
    if (value.startsWith('00966')) return '+${value.substring(2)}';
    if (value.startsWith('966')) return '+$value';
    if (value.startsWith('05') && value.length == 10) {
      return '+966${value.substring(1)}';
    }
    if (value.startsWith('5') && value.length == 9) {
      return '+966$value';
    }
    return value;
  }

  String _toLocalPhone(String input) {
    final normalized = _normalizePhone(input);
    if (normalized.startsWith('+966')) {
      return '0${normalized.substring(4)}';
    }
    return input.trim();
  }

  bool _isValidSaudiPhone(String input) {
    final normalized = _normalizePhone(input);
    return RegExp(r'^\+9665\d{8}$').hasMatch(normalized);
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        timer.cancel();
      }
    });
  }

  // استعلامان فقط (phone و phoneNumber للحسابات القديمة)
  // باستخدام whereIn بدل أربعة استعلامات.
  // ملاحظة: هذا فحص من جهة التطبيق فقط، والأفضل دعمه بقاعدة أمان أو Cloud Function.
  Future<bool> _phoneAlreadyUsed(
    String localPhone,
    String internationalPhone,
  ) async {
    final users = FirebaseFirestore.instance.collection('Users');
    final values = [localPhone, internationalPhone];

    final checks = await Future.wait([
      users.where('phone', whereIn: values).limit(2).get(),
      users.where('phoneNumber', whereIn: values).limit(2).get(),
    ]);

    for (final result in checks) {
      if (result.docs.any((doc) => doc.id != widget.userId)) {
        return true;
      }
    }
    return false;
  }

  User _requireCurrentUser() {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != widget.userId) {
      throw Exception('انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى.');
    }
    return authUser;
  }

  Future<void> _saveWithoutPhoneChange() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final authUser = _requireCurrentUser();
      final first = _firstCtrl.text.trim();
      final last = _lastCtrl.text.trim();
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .set({'firstName': first, 'lastName': last}, SetOptions(merge: true));
      try {
        await authUser.updateDisplayName('$first $last');
      } catch (e) {
        debugPrint('Auth displayName update failed: $e');
      }
      if (!mounted) return;
      Navigator.pop(context, {
        'firstName': first,
        'lastName': last,
        'phone': widget.phone,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendOtp({bool resend = false}) async {
    if (_sending || _verifying || _saving) return;

    if (!resend && !_formKey.currentState!.validate()) return;

    final internationalPhone = _normalizePhone(_phoneCtrl.text);
    final localPhone = _toLocalPhone(_phoneCtrl.text);
    final oldPhone = _normalizePhone(widget.phone);

    if (internationalPhone == oldPhone) {
      await _saveWithoutPhoneChange();
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      _requireCurrentUser();

      if (!resend && await _phoneAlreadyUsed(localPhone, internationalPhone)) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _error = 'رقم الجوال مرتبط بحساب آخر';
        });
        return;
      }

      // verifyPhoneNumber يرجع بمجرد بدء الطلب، وليس عند وصول الرمز.
      // لذلك يبقى _sending = true حتى يُستدعى أحد الـ callbacks أدناه.
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: internationalPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _completePhoneUpdate(credential, localPhone);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _sending = false;
            _error = _authErrorMessage(e);
          });
        },
        codeSent: (String verificationId, int? token) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = token;
            _otpSent = true;
            _sending = false;
            _error = null;
          });
          _startTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
        },
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = _authErrorMessage(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_verifying || _saving) return;

    final code = _otpCtrl.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }

    final verificationId = _verificationId;
    if (verificationId == null) {
      setState(() => _error = 'انتهت جلسة التحقق. أرسل الرمز مرة أخرى');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      await _completePhoneUpdate(credential, _toLocalPhone(_phoneCtrl.text));
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = _authErrorMessage(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = 'تعذّر تحديث رقم الجوال. حاول مرة أخرى';
        });
      }
    }
  }

  // الخطوة 1: تحديث رقم الهاتف في Firebase Auth
  Future<void> _completePhoneUpdate(
    PhoneAuthCredential credential,
    String localPhone,
  ) async {
    if (_saving || !mounted) return;

    setState(() {
      _sending = false; // مهم عند التحقق التلقائي حتى لا تبقى الواجهة مشغولة
      _saving = true;
      _verifying = true;
      _error = null;
    });

    try {
      final authUser = _requireCurrentUser();

      // يغيّر رقم الهاتف للحساب الحالي ولا ينشئ/يفتح حسابًا آخر.
      if (!_authPhoneUpdated) {
        await authUser.updatePhoneNumber(credential);
        _authPhoneUpdated = true;
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _verifying = false;
        _error = _authErrorMessage(e);
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _verifying = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    _pendingLocalPhone = localPhone;
    await _saveProfileToFirestore();
  }

  Future<void> _notifyAssignedCouriersOfPhoneChange({
    required String donorName,
    required String oldPhone,
    required String newPhone,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Find this donor's donations.
      final donationsSnapshot = await firestore
          .collection('donations')
          .where('donorId', isEqualTo: widget.userId)
          .get();

      // Collect couriers assigned to unfinished donation tasks.
      final courierIds = <String>{};

      for (final doc in donationsSnapshot.docs) {
        final data = doc.data();

        final courierId = (data['courierId'] ?? '').toString().trim();
        final taskStatus = (data['courierTaskStatus'] ?? '').toString();

        if (courierId.isNotEmpty && taskStatus != 'completed') {
          courierIds.add(courierId);
        }
      }

      if (courierIds.isEmpty) return;

      // Create a notification for each assigned courier.
      final batch = firestore.batch();

      for (final courierId in courierIds) {
        final notificationRef = firestore.collection('notifications').doc();

        batch.set(notificationRef, {
          'userId': courierId,
          'type': 'donor_phone_updated',
          'title': 'تحديث رقم جوال المتبرع',
          'message':
              'قام المتبرع $donorName بتغيير رقم جواله.\n'
              'الرقم السابق: $oldPhone\n'
              'الرقم الجديد: $newPhone',
          'donorId': widget.userId,
          'donorName': donorName,
          'oldPhone': oldPhone,
          'newPhone': newPhone,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      debugPrint(
        'Donor phone update notifications sent to ${courierIds.length} couriers',
      );
    } catch (e) {
      debugPrint('Donor phone notification error: $e');
    }
  }

  // الخطوة 2: حفظ البيانات في Firestore (بعد نجاح Auth فقط)
  Future<void> _saveProfileToFirestore() async {
    if (!mounted) return;

    final localPhone = _pendingLocalPhone ?? _toLocalPhone(_phoneCtrl.text);

    try {
      final authUser = _requireCurrentUser();

      final first = _firstCtrl.text.trim();
      final last = _lastCtrl.text.trim();

      final oldPhone = widget.phone.trim();
      final donorName = '$first $last'.trim();

      // Save the updated profile first.
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .set({
            'firstName': first,
            'lastName': last,
            'phone': localPhone,
            'phoneUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Notify assigned couriers only when the phone actually changes.
      if (_normalizePhone(oldPhone) != _normalizePhone(localPhone)) {
        await _notifyAssignedCouriersOfPhoneChange(
          donorName: donorName,
          oldPhone: oldPhone,
          newPhone: localPhone,
        );
      }

      try {
        await authUser.updateDisplayName('$first $last');
      } catch (e) {
        debugPrint('Auth displayName update failed: $e');
      }

      if (!mounted) return;

      _timer?.cancel();

      Navigator.pop(context, {
        'firstName': first,
        'lastName': last,
        'phone': localPhone,
      });
    } catch (e) {
      debugPrint('Firestore profile update failed: $e');

      if (!mounted) return;

      setState(() {
        _saving = false;
        _verifying = false;
        _error =
            'تم تحديث رقم الجوال، لكن تعذّر حفظ بياناتك. تحقق من الاتصال ثم اضغط إعادة المحاولة';
      });
    }
  }

  // إعادة محاولة حفظ Firestore فقط بدون رمز جديد
  Future<void> _retryProfileSave() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    await _saveProfileToFirestore();
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'رقم الجوال غير صحيح';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح';
      case 'session-expired':
        return 'انتهت صلاحية رمز التحقق. أرسل رمزًا جديدًا';
      case 'too-many-requests':
        return 'تم تجاوز عدد المحاولات. حاول لاحقًا';
      case 'quota-exceeded':
        return 'تعذّر إرسال الرسائل حاليًا. حاول لاحقًا';
      case 'credential-already-in-use':
      case 'phone-number-already-exists':
        return 'رقم الجوال مرتبط بحساب آخر';
      case 'requires-recent-login':
        return 'لأمان حسابك، سجّل الخروج ثم الدخول مجددًا قبل تغيير الرقم';
      case 'provider-already-linked':
        return 'تعذّر ربط رقم الجوال الجديد بهذا الحساب';
      default:
        return e.message ?? 'حدث خطأ أثناء التحقق. حاول مرة أخرى';
    }
  }

  InputDecoration _decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppDesign.primary),
      filled: true,
      fillColor: AppDesign.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: BorderSide(color: AppDesign.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: BorderSide(color: AppDesign.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: const BorderSide(color: AppDesign.primary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _verifying || _saving;

    final String primaryLabel = _authPhoneUpdated
        ? 'إعادة المحاولة'
        : (_otpSent ? 'تحقق وحفظ التعديلات' : 'حفظ');

    final VoidCallback primaryAction = _authPhoneUpdated
        ? _retryProfileSave
        : (_otpSent ? _verifyOtp : _sendOtp);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _otpSent
                        ? 'التحقق من رقم الجوال'
                        : 'تعديل البيانات الشخصية',
                    style: AppDesign.h1Style.copyWith(
                      color: AppDesign.primary,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_otpSent) ...[
                    Text(
                      'الاسم الأول',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstCtrl,
                      enabled: !busy,
                      maxLength: 30,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        'الاسم الأول',
                        Icons.person_outline,
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الاسم الأخير',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastCtrl,
                      enabled: !busy,
                      maxLength: 30,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        'الاسم الأخير',
                        Icons.person_outline,
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'رقم الجوال',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtrl,
                      enabled: !busy,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      maxLength: 13,
                      decoration: _decoration(
                        '05XXXXXXXX',
                        Icons.phone_outlined,
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        final input = (value ?? '').trim();
                        if (input.isEmpty) return 'أدخل رقم الجوال';
                        if (!_isValidSaudiPhone(input)) {
                          return 'أدخل رقمًا سعوديًا صحيحًا يبدأ بـ 05';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _otpCtrl,
                      enabled: !busy && !_authPhoneUpdated,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      decoration: _decoration(
                        '••••••',
                        Icons.lock_outline,
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: (!busy && _seconds == 0 && !_authPhoneUpdated)
                          ? () => _sendOtp(resend: true)
                          : null,
                      child: Text(
                        _seconds > 0
                            ? 'إعادة إرسال الرمز بعد $_seconds ثانية'
                            : 'إعادة إرسال الرمز',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: (busy || _authPhoneUpdated)
                            ? null
                            : () {
                                setState(() {
                                  _otpSent = false;
                                  _verificationId = null;
                                  _otpCtrl.clear();
                                  _error = null;
                                });
                                _timer?.cancel();
                              },
                        child: const Text('تغيير رقم الجوال المدخل'),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDesign.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: busy ? null : primaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusLG,
                          ),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(primaryLabel),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppDesign.primary,
                        side: const BorderSide(color: AppDesign.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusLG,
                          ),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
