import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_design.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Beneficiary_request_page.dart';

class BeneficiaryMorePage extends StatefulWidget {
  final String userId;

  const BeneficiaryMorePage({
    super.key,
    required this.userId,
  });

  @override
  State<BeneficiaryMorePage> createState() => _BeneficiaryMorePageState();
}

class _BeneficiaryMorePageState extends State<BeneficiaryMorePage> {
  int _bottomNavIndex = 2;

  String firstName = '';
  String lastName = '';
  String phone = '';
  String email = '';

  bool isLoading = true;
  bool _isBeneficiaryApproved = false;
  bool _approvalStatusLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBeneficiaryApprovalStatus();
  }

  Future<void> _loadBeneficiaryApprovalStatus() async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('beneficiaries')
          .where('userId', isEqualTo: widget.userId)
          .limit(1)
          .get();
      final status = result.docs.isNotEmpty
          ? (result.docs.first.data()['status'] ?? 'pending')
              .toString().trim().toLowerCase()
          : 'pending';
      if (!mounted) return;
      setState(() {
        _isBeneficiaryApproved = status == 'approved';
        _approvalStatusLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBeneficiaryApproved = false;
        _approvalStatusLoaded = true;
      });
    }
  }

  Future<void> _openOrdersIfApproved() async {
    if (!_approvalStatusLoaded) {
      await _loadBeneficiaryApprovalStatus();
    }
    if (!mounted) return;
    if (!_isBeneficiaryApproved) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('طلبك كمستفيد قيد المراجعة، وستتمكن من متابعة طلباتك بعد الموافقة.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BeneficiaryOrdersPage(userId: widget.userId)),
    );
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
        email = FirebaseAuth.instance.currentUser?.email ?? '';
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ───────────────────────── تعديل البيانات ─────────────────────────
  Future<void> _showEditNameSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditNameSheet(
        userId: widget.userId,
        firstName: firstName,
        lastName: lastName,
      ),
    );

    if (result == null || !mounted) return;

    // تحديث فوري في الصفحة
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
      child: Image.asset(
        'assets/images/madad_identity.png',
        fit: BoxFit.cover,
      ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppDesign.secondary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 18, color: AppDesign.primary),
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
              icon: Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _buildInfoField(
              label: 'الاسم الأخير',
              value: lastName,
              icon: Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _buildInfoField(
              label: 'رقم الجوال',
              value: phone,
              icon: Icons.phone_outlined),
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
                        style: AppDesign.bodyStyle.copyWith(
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
                    const url =
                        'https://www.google.com/maps/search/?api=1&query=24.768932,46.728328';

                    final uri = Uri.parse(url);

                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: Icon(Icons.location_on_outlined,
                      color: AppDesign.primary, size: 18),
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
          Text('تسجيل الخروج',
              style: AppDesign.subtitleStyle.copyWith(
                  color: Colors.red,
                  fontSize: 21,
                  fontWeight: FontWeight.w800)),
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

  Widget _buildBottomNavigationBar() {
    // لا نعرض شريطًا مؤقتًا بخيارين قبل اكتمال قراءة حالة المستفيد.
    // ننتظر نتيجة Firestore حتى يظهر شريط التنقل الصحيح من أول مرة.
    if (!_approvalStatusLoaded) {
      return Container(
        height: 78,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: AppDesign.white,
          borderRadius: BorderRadius.circular(AppDesign.radiusXL),
          boxShadow: [
            BoxShadow(
              color: AppDesign.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'الرئيسية',
      ),
      if (_approvalStatusLoaded && _isBeneficiaryApproved)
        const NavigationDestination(
          icon: Icon(Icons.volunteer_activism_outlined),
          selectedIcon: Icon(Icons.volunteer_activism_rounded),
          label: 'طلباتي',
        ),
      const NavigationDestination(
        icon: Icon(Icons.more_horiz_rounded),
        selectedIcon: Icon(Icons.more_horiz_rounded),
        label: 'المزيد',
      ),
    ];
    final selectedIndex = !_isBeneficiaryApproved && _bottomNavIndex == 2
        ? 1
        : _bottomNavIndex;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppDesign.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: NavigationBar(
        height: 78,
        selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
        backgroundColor: Colors.transparent,
        indicatorColor: AppDesign.secondary.withOpacity(0.16),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/beneficiaryHome', arguments: widget.userId);
          } else if (_isBeneficiaryApproved && index == 1) {
            _openOrdersIfApproved();
          } else {
            setState(() => _bottomNavIndex = 2);
          }
        },
        destinations: destinations,
      ),
    );
  }

}

/// ═══════════════════════════ نافذة تعديل الاسم ═══════════════════════════
class _EditNameSheet extends StatefulWidget {
  final String userId;
  final String firstName;
  final String lastName;

  const _EditNameSheet({
    required this.userId,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.firstName);
    _lastCtrl = TextEditingController(text: widget.lastName);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();

    // ما تغيّر شي → نقفل بدون كتابة
    if (first == widget.firstName && last == widget.lastName) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // حفظ البيانات في Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .set({
        'firstName': first,
        'lastName': last,
      }, SetOptions(merge: true));

      // تحديث الاسم في Authentication (displayName)
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.uid == widget.userId) {
          await authUser.updateDisplayName('$first $last');
        }
      } catch (e) {
        debugPrint('Auth displayName update failed: $e');
      }

      if (!mounted) return;
      Navigator.pop(context, {'firstName': first, 'lastName': last});
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذّر حفظ التعديل، حاولي مرة أخرى';
      });
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      counterText: '',
      prefixIcon: Icon(Icons.person_outline_rounded, color: AppDesign.primary),
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
        borderSide: BorderSide(color: AppDesign.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: BorderSide(color: AppDesign.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: BorderSide(color: AppDesign.error, width: 1.6),
      ),
      errorStyle: TextStyle(
        fontFamily: AppDesign.fontFamily,
        fontSize: AppDesign.caption,
        fontWeight: FontWeight.w400,
        color: AppDesign.error,
      ),
    );
  }

  String? _validateName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'هذا الحقل مطلوب';
    if (t.length < 2) return 'الاسم قصير جداً';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        // يرفع النافذة فوق الكيبورد
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                  'تعديل البيانات الشخصية',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppDesign.primary,
                  ),
                ),
                const SizedBox(height: 20),
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
                  enabled: !_saving,
                  maxLength: 30,
                  textInputAction: TextInputAction.next,
                  cursorColor: AppDesign.primary,
                  decoration: _decoration('الاسم الأول'),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
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
                  enabled: !_saving,
                  maxLength: 30,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  cursorColor: AppDesign.primary,
                  decoration: _decoration('الاسم الأخير'),
                  validator: _validateName,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppDesign.fontFamily,
                      color: AppDesign.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppDesign.primary.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'حفظ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(color: AppDesign.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
