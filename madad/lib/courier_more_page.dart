import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_design.dart';
import 'welcome_page.dart';

class CourierMorePage extends StatefulWidget {
  final String userId;

  const CourierMorePage({super.key, required this.userId});

  @override
  State<CourierMorePage> createState() => _CourierMorePageState();
}

class _CourierMorePageState extends State<CourierMorePage> {
  String firstName = '';
  String lastName = '';
  String phone = '';

  bool isLoading = true;

  // ✅ حالة طلب تغيير رقم الجوال
  String _phoneRequestStatus = '';
  String? _approvedRequestId;
  DateTime? _phoneApprovalExpiresAt;
  bool _requestBusy = false;

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
      await _loadPhoneRequestStatus(); // ✅ جديد
      if (!mounted) return;

      setState(() {
        firstName = (data['firstName'] ?? '').toString().trim();
        lastName = (data['lastName'] ?? '').toString().trim();
        phone = (data['phone'] ?? data['phoneNumber'] ?? '').toString().trim();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ───────────────────────── طلب تغيير رقم الجوال ─────────────────────────

  // قراءة أحدث طلب لهذا المستخدم.
  // نجلب طلبات المستخدم فقط ثم نرتبها داخل التطبيق لتجنب الحاجة
  // إلى Composite Index في Firestore (userId + requestedAt).
  Future<void> _loadPhoneRequestStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('phone_change_requests')
          .where('userId', isEqualTo: widget.userId)
          .get();

      if (snapshot.docs.isEmpty) {
        _phoneRequestStatus = '';
        _approvedRequestId = null;
        _phoneApprovalExpiresAt = null;
        return;
      }

      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aValue = a.data()['requestedAt'];
          final bValue = b.data()['requestedAt'];
          final aDate = aValue is Timestamp
              ? aValue.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = bValue is Timestamp
              ? bValue.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      final doc = docs.first;
      final data = doc.data();
      var status = (data['status'] ?? '').toString();
      DateTime? expiresAt;
      final expiryValue = data['expiresAt'];
      if (expiryValue is Timestamp) {
        expiresAt = expiryValue.toDate();
      }

      // تنتهي الموافقة بعد 7 أيام. لا نسمح بالتغيير إذا لم يوجد تاريخ انتهاء.
      if (status == 'approved' &&
          (expiresAt == null || !DateTime.now().isBefore(expiresAt))) {
        status = 'expired';
        try {
          await doc.reference.update({'status': 'expired'});
        } catch (e) {
          debugPrint('Could not mark request as expired: $e');
        }
      }

      _phoneRequestStatus = status;
      _approvedRequestId = status == 'approved' ? doc.id : null;
      _phoneApprovalExpiresAt = status == 'approved' ? expiresAt : null;

      debugPrint(
        'Phone request loaded: userId=${widget.userId}, '
        'requestId=${doc.id}, status=$status, expiresAt=$expiresAt',
      );
    } catch (e) {
      debugPrint('Error loading phone change request: $e');
      _phoneRequestStatus = '';
      _approvedRequestId = null;
      _phoneApprovalExpiresAt = null;
    }
  }

  String _remainingText() {
    final exp = _phoneApprovalExpiresAt;
    if (exp == null) return '';
    final left = exp.difference(DateTime.now());
    if (left.inHours >= 24) {
      final days = (left.inHours / 24).ceil();
      if (days == 1) return 'باقي يوم واحد';
      if (days == 2) return 'باقي يومان';
      return 'باقي $days أيام';
    }
    if (left.inHours >= 1) return 'باقي ${left.inHours} ساعة';
    return 'باقي أقل من ساعة';
  }

  Future<void> _submitPhoneChangeRequest() async {
    if (_requestBusy) return;
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'تأكيد طلب تغيير الجوال',
      message:
          'هل أنت متأكد من رغبتك في إرسال طلب تغيير رقم الجوال؟\nسيتم إرسال الطلب للأدمن للمراجعة.',
      confirmText: 'إرسال الطلب',
      cancelText: 'إلغاء',
    );

    if (confirm != true || !mounted) return;
    setState(() => _requestBusy = true);
    try {
      // لا نستخدم whereIn مع where على أكثر من حقل؛ لتجنب طلب Composite Index.
      final existingRequests = await FirebaseFirestore.instance
          .collection('phone_change_requests')
          .where('userId', isEqualTo: widget.userId)
          .get();

      final now = DateTime.now();
      final hasActive = existingRequests.docs.any((doc) {
        final data = doc.data();
        if (data['status'] == 'pending') return true;

        final expiry = data['expiresAt'];
        return data['status'] == 'approved' &&
            expiry is Timestamp &&
            expiry.toDate().isAfter(now);
      });

      if (hasActive) {
        await _loadPhoneRequestStatus();
        if (!mounted) return;
        setState(() => _requestBusy = false);
        AppDesign.showSuccessSnackBar(
          context,
          'لديك طلب تغيير رقم جوال قيد المراجعة أو موافقة سارية',
        );
        return;
      }

      await FirebaseFirestore.instance.collection('phone_change_requests').add({
        'userId': widget.userId,
        'userRole': 'courier',
        'userName': '$firstName $lastName'.trim(), // ✅ جديد: يظهر عند الأدمن
        'oldPhone': phone, // ✅ جديد: يظهر عند الأدمن
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      await _loadPhoneRequestStatus();
      if (!mounted) return;
      setState(() => _requestBusy = false);
      AppDesign.showSuccessSnackBar(
        context,
        'تم إرسال طلب تغيير رقم الجوال للأدمن',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إرسال الطلب. حاول مرة أخرى')),
      );
      debugPrint('Phone change request error: $e');
    }
  }

  Future<void> _startApprovedPhoneChange() async {
    await _loadPhoneRequestStatus();
    if (!mounted) return;

    if (_phoneRequestStatus != 'approved' ||
        _approvedRequestId == null ||
        _phoneApprovalExpiresAt == null ||
        DateTime.now().isAfter(_phoneApprovalExpiresAt!)) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الموافقة غير متاحة أو انتهت صلاحيتها')),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CourierEditSheet(
        userId: widget.userId,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        allowPhoneChange: true,
        phoneRequestId: _approvedRequestId,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      firstName = result['firstName'] ?? firstName;
      lastName = result['lastName'] ?? lastName;
      phone = result['phone'] ?? phone; // ✅ تصليح: يحدّث الرقم في الشاشة
    });
    await _loadPhoneRequestStatus();
    if (mounted) setState(() {});
    AppDesign.showSuccessSnackBar(context, 'تم تحديث البيانات بنجاح');
  }

  Widget _buildPhoneRequestAction() {
    String label;
    String helper;
    IconData icon;
    VoidCallback? action;

    if (_phoneRequestStatus == 'pending') {
      label = 'طلبك قيد المراجعة';
      helper = 'سيصلك إشعار عند مراجعة الأدمن للطلب';
      icon = Icons.hourglass_top_rounded;
    } else if (_phoneRequestStatus == 'approved') {
      label = 'تغيير رقم الجوال';
      helper = 'تمت الموافقة على طلبك، ${_remainingText()} لإكمال التغيير';
      icon = Icons.phone_android;
      action = _startApprovedPhoneChange;
    } else {
      label = 'طلب تغيير رقم الجوال';
      icon = Icons.send_rounded;
      if (_phoneRequestStatus == 'rejected') {
        helper = 'تم رفض الطلب السابق. يمكنك تقديم طلب جديد';
      } else if (_phoneRequestStatus == 'expired') {
        helper = 'انتهت مدة التغيير. قدّم طلباً جديداً لتغيير رقم الجوال';
      } else {
        helper = 'يتطلب تغيير رقم الجوال موافقة الأدمن أولاً';
      }
      action = _requestBusy ? null : _submitPhoneChangeRequest;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _requestBusy ? null : action,
            icon: _requestBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 19),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesign.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppDesign.primary.withOpacity(0.6),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesign.radiusLG),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          textAlign: TextAlign.right,
          style: AppDesign.bodyStyle.copyWith(
            color: AppDesign.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── تعديل البيانات ─────────────────────────
  Future<void> _showEditNameSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CourierEditSheet(
        userId: widget.userId,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        allowPhoneChange: false,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      firstName = result['firstName'] ?? firstName;
      lastName = result['lastName'] ?? lastName;
    });

    AppDesign.showSuccessSnackBar(context, 'تم تحديث البيانات بنجاح');
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد من تسجيل الخروج؟',
      confirmText: 'تسجيل الخروج',
      cancelText: 'إلغاء',
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
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
              // زر تعديل الاسم
              InkWell(
                onTap: _showEditNameSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesign.secondary.withOpacity(0.14),
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

          // ✅ جديد: زر طلب تغيير رقم الجوال (الجوال يبقى للقراءة فقط)
          const SizedBox(height: 14),
          _buildPhoneRequestAction(),
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
            color: AppDesign.primary.withOpacity(0.35),
            thickness: 1.1,
            endIndent: 12,
          ),
        ),
        Icon(Icons.local_florist_outlined, color: AppDesign.primary, size: 30),
        Expanded(
          child: Divider(
            color: AppDesign.primary.withOpacity(0.35),
            thickness: 1.1,
            indent: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutMadadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          Divider(color: AppDesign.border),
          const SizedBox(height: 20),

          // ===== الموقع =====
          Row(
            textDirection: TextDirection.rtl,
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
                        style: AppDesign.subtitleStyle.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'مستودع مدد - واجهة الرياض',
                        style: AppDesign.bodyStyle.copyWith(fontSize: 13),
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
                    const url =
                        'https://www.google.com/maps/search/?api=1&query=24.768932,46.728328';

                    final uri = Uri.parse(url);

                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: Icon(
                    Icons.location_on_outlined,
                    color: AppDesign.primary,
                    size: 18,
                  ),
                  label: Text(
                    'فتح الخريطة',
                    style: AppDesign.bodyStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppDesign.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesign.radiusLG),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: AppDesign.border),
          const SizedBox(height: 20),

          // ===== ساعات العمل =====
          Row(
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
                        style: AppDesign.subtitleStyle.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الأحد - الخميس: 9:00 ص - 5:00 م\nالجمعة والسبت: مغلق',
                        style: AppDesign.bodyStyle.copyWith(
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
        color: AppDesign.secondary.withOpacity(0.14),
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
          color: AppDesign.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

// ======================================================
// نافذة تعديل البيانات الشخصية
// - الوضع العادي: تعديل الاسم فقط
// - وضع تغيير الجوال (بعد موافقة الأدمن): تغيير الرقم مع OTP عبر Firebase Auth
// ======================================================

class _CourierEditSheet extends StatefulWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final bool allowPhoneChange;
  final String? phoneRequestId;

  const _CourierEditSheet({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.allowPhoneChange = false,
    this.phoneRequestId,
  });

  @override
  State<_CourierEditSheet> createState() => _CourierEditSheetState();
}

class _CourierEditSheetState extends State<_CourierEditSheet> {
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

  // معرّف حساب Authentication عند فتح النافذة؛ قد يختلف عن Document ID.
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

  // استعلامان فقط (phone و phoneNumber للحسابات القديمة)
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

  Future<User> _requireCurrentUser({bool verifyPhone = true}) async {
    final authUser = FirebaseAuth.instance.currentUser;

    debugPrint('AUTH UID: ${authUser?.uid}');
    debugPrint('FIRESTORE USER ID: ${widget.userId}');

    // لا نقارن UID مع Document ID؛ قد يكونان مختلفين للحسابات القديمة.
    if (authUser == null ||
        _authUidAtOpen == null ||
        authUser.uid != _authUidAtOpen) {
      throw Exception('انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى.');
    }

    // نتحقق من ارتباط جلسة Auth بمستند المندوب عن طريق رقم الجوال والدور.
    // بعد تحديث رقم Auth، نعطل هذا الفحص مؤقتًا أثناء حفظ الرقم الجديد في Firestore.
    if (verifyPhone) {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();

      final userData = userDoc.data();
      final firestorePhone =
          (userData?['phone'] ?? userData?['phoneNumber'] ?? '')
              .toString()
              .trim();
      final authPhone = (authUser.phoneNumber ?? '').trim();

      if (!userDoc.exists ||
          userData == null ||
          (userData['role'] ?? '').toString().toLowerCase() != 'courier' ||
          authPhone.isEmpty ||
          _normalizePhone(firestorePhone) != _normalizePhone(authPhone)) {
        throw Exception(
          'تعذّر مطابقة حسابك مع بيانات المندوب. سجّل الخروج ثم ادخل برقم الجوال المسجل.',
        );
      }
    }

    return authUser;
  }

  // ✅ جديد: يتأكد إن موافقة الأدمن لسا سارية (ما انتهى الأسبوع وما انستخدمت)
  Future<void> _ensureApprovalValid() async {
    final requestId = widget.phoneRequestId;
    if (requestId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('phone_change_requests')
        .doc(requestId)
        .get();

    final data = doc.data();
    final expiry = data?['expiresAt'];

    final valid =
        data != null &&
        data['userId'] == widget.userId &&
        data['status'] == 'approved' &&
        expiry is Timestamp &&
        DateTime.now().isBefore(expiry.toDate());

    if (!valid) {
      throw Exception(
        'انتهت مدة تغيير رقم الجوال أو لم تعد الموافقة سارية. قدّم طلباً جديداً',
      );
    }
  }

  Future<void> _saveWithoutPhoneChange() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final authUser = await _requireCurrentUser();
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
      await _requireCurrentUser();
      await _ensureApprovalValid(); // ✅ جديد

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
      final authUser = await _requireCurrentUser();

      // يغيّر رقم الهاتف للحساب الحالي ولا ينشئ/يفتح حسابًا آخر.
      if (!_authPhoneUpdated) {
        await _ensureApprovalValid(); // ✅ جديد: آخر فحص قبل تغيير الرقم فعلياً
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

  // الخطوة 2: حفظ البيانات في Firestore (بعد نجاح Auth فقط)
  Future<void> _saveProfileToFirestore() async {
    if (!mounted) return;

    final localPhone = _pendingLocalPhone ?? _toLocalPhone(_phoneCtrl.text);

    try {
      final first = _firstCtrl.text.trim();
      final last = _lastCtrl.text.trim();

      final authUser = await _requireCurrentUser(
        verifyPhone: !_authPhoneUpdated,
      );

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.set(db.collection('Users').doc(widget.userId), {
        'firstName': first,
        'lastName': last,
        'phone': localPhone,
        'phoneUpdatedAt': FieldValue.serverTimestamp(),
        // ✅ جديد: يقفل نافذة التغيير حتى ما يغيّر مرة ثانية بنفس الموافقة
        'phoneChangeAllowedUntil': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (widget.phoneRequestId != null) {
        batch.update(
          db.collection('phone_change_requests').doc(widget.phoneRequestId),
          {'status': 'completed', 'completedAt': FieldValue.serverTimestamp()},
        );
      }

      await batch.commit();

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

    final String primaryLabel = !widget.allowPhoneChange
        ? 'حفظ التعديلات'
        : (_authPhoneUpdated
              ? 'إعادة المحاولة'
              : (_otpSent ? 'تحقق وحفظ التعديلات' : 'إرسال رمز التحقق'));

    final VoidCallback primaryAction = !widget.allowPhoneChange
        ? _saveWithoutPhoneChange
        : (_authPhoneUpdated
              ? _retryProfileSave
              : (_otpSent ? _verifyOtp : _sendOtp));

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
                        : (widget.allowPhoneChange
                              ? 'تغيير رقم الجوال'
                              : 'تعديل البيانات الشخصية'),
                    style: AppDesign.h1Style.copyWith(
                      color: AppDesign.primary,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_otpSent) ...[
                    if (!widget.allowPhoneChange) ...[
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
                    ],

                    if (widget.allowPhoneChange) ...[
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
                    ],
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
