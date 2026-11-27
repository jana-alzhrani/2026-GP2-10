import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_design.dart';

class ProfileEditSheet extends StatefulWidget {
  final String userId;
  final String role;
  final String firstName;
  final String lastName;
  final String phone;

  const ProfileEditSheet({
    super.key,
    required this.userId,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
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

  bool _authPhoneUpdated = false;
  String? _pendingLocalPhone;

  String? _authUidAtOpen;

  @override
  void initState() {
    super.initState();
    _authUidAtOpen = FirebaseAuth.instance.currentUser?.uid;
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

  User _requireCurrentUser() {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null ||
        _authUidAtOpen == null ||
        authUser.uid != _authUidAtOpen) {
      throw Exception('انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى.');
    }
    return authUser;
  }

  Future<void> _ensureNoActiveWork() async {
    final reason = await PhoneChangeGuard.blockReason(
      role: widget.role,
      userId: widget.userId,
    );
    if (reason != null) throw Exception(reason);
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

      await _ensureNoActiveWork();

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

  Future<void> _completePhoneUpdate(
    PhoneAuthCredential credential,
    String localPhone,
  ) async {
    if (_saving || !mounted) return;

    setState(() {
      _sending = false;
      _saving = true;
      _verifying = true;
      _error = null;
    });

    try {
      final authUser = _requireCurrentUser();

      if (!_authPhoneUpdated) {
        await _ensureNoActiveWork();
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

  Future<void> _saveProfileToFirestore() async {
    if (!mounted) return;

    final localPhone = _pendingLocalPhone ?? _toLocalPhone(_phoneCtrl.text);

    try {
      final authUser = _requireCurrentUser();

      final first = _firstCtrl.text.trim();
      final last = _lastCtrl.text.trim();

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .set({
            'firstName': first,
            'lastName': last,
            'phone': localPhone,
            'phoneUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

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

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppDesign.textPrimary,
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
                    _label('الاسم الأول'),
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
                    _label('الاسم الأخير'),
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
                    _label('رقم الجوال'),
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

class PhoneChangeGuard {
  PhoneChangeGuard._();

  static const Set<String> _finished = {
    'completed',
    'delivered',
    'done',
    'cancelled',
    'canceled',
    'rejected',
  };

  static bool _isActive(Map<String, dynamic> data) {
    final courierId = (data['courierId'] ?? '').toString().trim();
    if (courierId.isEmpty) return false;

    final task = (data['courierTaskStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final status = (data['status'] ?? '').toString().trim().toLowerCase();

    return !_finished.contains(task) && !_finished.contains(status);
  }

  static Future<bool> _anyActive(Query<Map<String, dynamic>> query) async {
    final snap = await query.get();
    return snap.docs.any((d) => _isActive(d.data()));
  }

  static Future<String?> blockReason({
    required String role,
    required String userId,
  }) async {
    final db = FirebaseFirestore.instance;

    try {
      switch (role) {
        case 'donor':
          final active = await _anyActive(
            db.collection('donations').where('donorId', isEqualTo: userId),
          );
          return active
              ? 'لا يمكنك تغيير رقم الجوال لوجود تبرع نشط مسند إلى مندوب. '
                    'يمكنك التغيير بعد اكتمال التبرع أو إلغاء إسناده للمندوب.'
              : null;

        case 'beneficiary':
          final active = await _anyActive(
            db.collection('requests').where('beneficiaryId', isEqualTo: userId),
          );
          return active
              ? 'لا يمكنك تغيير رقم الجوال لوجود طلب نشط مسند إلى مندوب. '
                    'يمكنك التغيير بعد اكتمال الطلب أو إلغاء إسناده للمندوب.'
              : null;

        case 'courier':
          final results = await Future.wait([
            _anyActive(
              db.collection('donations').where('courierId', isEqualTo: userId),
            ),
            _anyActive(
              db.collection('requests').where('courierId', isEqualTo: userId),
            ),
          ]);
          return results.any((r) => r)
              ? 'لا يمكنك تغيير رقم الجوال لوجود مهمة نشطة مسندة إليك. '
                    'يمكنك التغيير بعد اكتمال المهمة أو إلغاء إسنادها.'
              : null;

        default:
          return null;
      }
    } catch (_) {
      throw Exception('تعذّر التحقق من وجود مهام نشطة. حاول مرة أخرى');
    }
  }
}
