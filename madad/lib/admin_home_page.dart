import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_design.dart';

class AdminHomePage extends StatefulWidget {
  final String userId;

  const AdminHomePage({
    super.key,
    required this.userId,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String adminName = 'المشرف';
  bool isLoading = true;

  int pendingBeneficiariesCount = 0;
  int approvedBeneficiariesCount = 0;
  int couriersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // =========================================================
  // Load Admin + Beneficiaries + Couriers
  // =========================================================

  Future<void> _loadAdminData() async {
    try {
      // -----------------------------------------
      // 1) بيانات الأدمن من Users
      // -----------------------------------------
      final adminDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();

      // -----------------------------------------
      // 2) بيانات المستفيدين من beneficiaries
      // -----------------------------------------
      final beneficiariesSnapshot = await FirebaseFirestore.instance
          .collection('beneficiaries')
          .get();

      // -----------------------------------------
      // 3) بيانات المناديب من couriers
      // -----------------------------------------
      final couriersSnapshot =
          await FirebaseFirestore.instance.collection('couriers').get();

      if (!mounted) return;

      // -----------------------------------------
      // اسم الأدمن
      // -----------------------------------------
      String fetchedAdminName = 'المشرف';

      if (adminDoc.exists) {
        final data = adminDoc.data() ?? {};

        final firstName =
            (data['firstName'] ?? '').toString().trim();

        final lastName =
            (data['lastName'] ?? '').toString().trim();

        final fullName = '$firstName $lastName'.trim();

        if (fullName.isNotEmpty) {
          fetchedAdminName = fullName;
        }
      }

      // -----------------------------------------
      // حساب المستفيدين
      // -----------------------------------------
      int pending = 0;
      int approved = 0;

      for (final doc in beneficiariesSnapshot.docs) {
        final data = doc.data();

        final status =
            (data['status'] ?? '').toString().trim().toLowerCase();

        if (status == 'pending') {
          pending++;
        } else if (status == 'approved') {
          approved++;
        }
      }

      // -----------------------------------------
      // عدد المناديب
      // -----------------------------------------
      final int couriers = couriersSnapshot.docs
          .where(
            (d) => (d.data()['statues'] ?? '').toString() != 'deleted',
          )
          .length;

      setState(() {
        adminName = fetchedAdminName;
        pendingBeneficiariesCount = pending;
        approvedBeneficiariesCount = approved;
        couriersCount = couriers;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin data: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

Future<void> _logout() async {
  final confirmed = await AppDesign.showAppDialog(
    context: context,
    title: 'تسجيل الخروج',
    message: 'هل أنت متأكد من تسجيل الخروج؟',
    cancelText: 'إلغاء',
    confirmText: 'تسجيل الخروج',
  );

  if (!confirmed) return;

  try {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/welcome',
      (route) => false,
    );
  } catch (e) {
    if (!mounted) return;

    AppDesign.showErrorSnackBar(
      context,
      'تعذر تسجيل الخروج، حاول مرة أخرى',
    );
  }
}
  // =========================================================
  // Build
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppDesign.primary,
            onRefresh: _loadAdminData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppPadding.screen.copyWith(
                top: 22,
                bottom: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),

                  const SizedBox(height: 34),

                  Text(
                    'إدارة النظام',
                    textAlign: TextAlign.right,
                    style: AppDesign.h1Style.copyWith(
                      color: AppDesign.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'اختر القسم الذي ترغب في إدارته',
                    textAlign: TextAlign.right,
                    style: AppDesign.bodyStyle.copyWith(
                      color: AppDesign.textSecondary,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // المستفيدون
                  // =================================================

                  _buildManagementCard(
                    title: 'المستفيدون',
                    subtitle: 'مراجعة طلبات التسجيل وإدارة المستفيدين',
                    icon: Icons.family_restroom_rounded,
                    badgeCount: pendingBeneficiariesCount,
                    badgeText: 'طلبات جديدة',
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        '/adminBeneficiaries',
                        arguments: widget.userId,
                      );

                      // تحديث الأعداد بعد الرجوع
                      _loadAdminData();
                    },
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // المناديب
                  // =================================================

                  _buildManagementCard(
                    title: 'المناديب',
                    subtitle: 'عرض وإدارة حسابات مناديب التوصيل',
                    icon: Icons.local_shipping_outlined,
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        '/adminCouriers',
                        arguments: widget.userId,
                      );

                      // تحديث العدد بعد الرجوع
                      _loadAdminData();
                    },
                  ),

                  const SizedBox(height: 32),

                  _buildQuickSummary(),
                ],
              ),
            ),
          ),
        ),

        // لا يوجد Bottom Navigation
        // الأدمن لديه الرئيسية فقط
      ),
    );
  }

  // =========================================================
  // Header
  // =========================================================

 Widget _buildHeader() {
  final String firstLetter =
      adminName.trim().isNotEmpty ? adminName.trim()[0] : 'م';

  return Row(
    children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: AppDesign.primary,
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: AppDesign.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),

      AppGap.wMD,

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحبًا',
              style: AppDesign.bodyStyle.copyWith(
                color: AppDesign.primary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              adminName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppDesign.h1Style.copyWith(
                color: AppDesign.primary,
                fontSize: 29,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(width: 12),

      // تسجيل الخروج
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _logout,
          borderRadius: BorderRadius.circular(AppDesign.radiusMD),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppDesign.white,
              borderRadius: BorderRadius.circular(
                AppDesign.radiusMD,
              ),
              border: Border.all(
                color: AppDesign.border,
              ),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppDesign.primary,
              size: 24,
            ),
          ),
        ),
      ),
    ],
  );
}

  // =========================================================
  // Management Card
  // =========================================================

  Widget _buildManagementCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    int? badgeCount,
    String? badgeText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppDesign.white,
            borderRadius: BorderRadius.circular(
              AppDesign.radiusXL,
            ),
            border: Border.all(
              color: AppDesign.border,
            ),
            boxShadow: [
              BoxShadow(
                color: AppDesign.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppDesign.secondary.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppDesign.primary,
                  size: 29,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppDesign.h1Style.copyWith(
                        color: AppDesign.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      subtitle,
                      style: AppDesign.bodyStyle.copyWith(
                        color: AppDesign.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),

                    if (badgeCount != null && badgeCount > 0) ...[
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppDesign.softGreen.withOpacity(0.17),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$badgeCount ${badgeText ?? ''}',
                          style: AppDesign.bodyStyle.copyWith(
                            color: AppDesign.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppDesign.primary.withOpacity(0.55),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // Quick Summary
  // =========================================================

  Widget _buildQuickSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نظرة سريعة',
          style: AppDesign.h1Style.copyWith(
            color: AppDesign.primary,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'طلبات التسجيل',
                value: pendingBeneficiariesCount,
                icon: Icons.pending_actions_rounded,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildSummaryCard(
                title: 'المستفيدون',
                value: approvedBeneficiariesCount,
                icon: Icons.people_alt_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildSummaryCard(
          title: 'المناديب',
          value: couriersCount,
          icon: Icons.local_shipping_outlined,
          fullWidth: true,
        ),
      ],
    );
  }

  // =========================================================
  // Summary Card
  // =========================================================

  Widget _buildSummaryCard({
    required String title,
    required int value,
    required IconData icon,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(
          AppDesign.radiusXL,
        ),
        border: Border.all(
          color: AppDesign.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppDesign.secondary.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppDesign.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppDesign.primary,
                        ),
                      )
                    : Text(
                        '$value',
                        style: AppDesign.h1Style.copyWith(
                          color: AppDesign.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
