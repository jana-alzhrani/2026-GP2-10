import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_design.dart';

class AdminBeneficiariesPage extends StatefulWidget {
  final String userId;

  const AdminBeneficiariesPage({
    super.key,
    required this.userId,
  });

  @override
  State<AdminBeneficiariesPage> createState() =>
      _AdminBeneficiariesPageState();
}

class _AdminBeneficiariesPageState
    extends State<AdminBeneficiariesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int selectedTab = 0;

  // =========================================================
  // Firestore
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _beneficiariesStream() {
    return _firestore.collection('beneficiaries').snapshots();
  }

  String _getStatus(Map<String, dynamic> data) {
    return (data['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
  }

  String _getSocialSecurityNumber(Map<String, dynamic> data) {
    return (data['socialSecurityNumber'] ?? 'غير متوفر').toString();
  }

  String _getPdfUrl(Map<String, dynamic> data) {
    return (data['socialSecurityPdfUrl'] ?? '').toString();
  }

  String _getUserId(
    String beneficiaryDocumentId,
    Map<String, dynamic> data,
  ) {
    final value = data['userId'];

    if (value is DocumentReference) {
      return value.id;
    }

    final userId = (value ?? '').toString().trim();

    if (userId.isNotEmpty) {
      return userId;
    }

    // لأننا نعتمد أن beneficiary document ID = uid
    return beneficiaryDocumentId;
  }

  // =========================================================
  // User Data
  // =========================================================

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (userId.trim().isEmpty) return null;

    try {
      final document =
          await _firestore.collection('Users').doc(userId).get();

      if (!document.exists) return null;

      return document.data();
    } catch (e) {
      debugPrint('Get beneficiary user error: $e');
      return null;
    }
  }

  String _getName(Map<String, dynamic>? data) {
    if (data == null) {
      return 'مستفيد';
    }

    final firstName =
        (data['firstName'] ?? '').toString().trim();

    final lastName =
        (data['lastName'] ?? '').toString().trim();

    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    return (data['fullName'] ?? 'مستفيد').toString();
  }

  String _getPhone(Map<String, dynamic>? data) {
    if (data == null) {
      return 'غير متوفر';
    }

    final phone = (data['phone'] ?? '').toString().trim();

    if (phone.isNotEmpty) {
      return phone;
    }

    final phoneNumber =
        (data['phoneNumber'] ?? '').toString().trim();

    if (phoneNumber.isNotEmpty) {
      return phoneNumber;
    }

    return 'غير متوفر';
  }

void _addBeneficiaryNotificationToBatch({
  required WriteBatch batch,
  required String beneficiaryUserId,
  required bool isApproved,
  String? rejectionReason,
}) {
  final notificationRef =
      _firestore.collection('notifications').doc();

  batch.set(notificationRef, {
    'userId': beneficiaryUserId,
    'type': isApproved
        ? 'beneficiary_approved'
        : 'beneficiary_rejected',
    'title': isApproved
        ? 'تم قبول طلبك'
        : 'تم رفض طلبك',
    'message': isApproved
        ? 'تم قبول طلب تسجيلك كمستفيد في مدد. يمكنك الآن إضافة الكسوات إلى السلة وإرسال طلبك.'
        : 'تعذر قبول طلب تسجيلك كمستفيد في مدد.',
    if (!isApproved)
      'rejectionReason': rejectionReason?.trim() ?? '',
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

  // =========================================================
  // Approve Beneficiary
  // =========================================================

  Future<void> _approveBeneficiary({
    required String beneficiaryId,
    required String beneficiaryUserId,
    required String name,
  }) async {
    final confirmed = await _showConfirmDialog(
      title: 'قبول الطلب',
      message: 'هل أنت متأكد من قبول طلب $name؟',
      confirmText: 'قبول',
    );

    if (!confirmed) return;

    try {
      final beneficiaryRef =
          _firestore.collection('beneficiaries').doc(beneficiaryId);



      final batch = _firestore.batch();

      // تحديث حالة المستفيد
      batch.update(
        beneficiaryRef,
        {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': widget.userId,

          // إزالة أي بيانات رفض سابقة
          'rejectionReason': FieldValue.delete(),
          'rejectedAt': FieldValue.delete(),
          'rejectedBy': FieldValue.delete(),

          // إزالة بيانات حذف سابقة إن وجدت
          'deletedAt': FieldValue.delete(),
          'deletedBy': FieldValue.delete(),
        },
      );

      // توحيد الحالة في Users
      batch.set(
        _firestore.collection('Users').doc(beneficiaryUserId),
        {'status': 'approved'},
        SetOptions(merge: true),
      );

_addBeneficiaryNotificationToBatch(
  batch: batch,
  beneficiaryUserId: beneficiaryUserId,
  isApproved: true,
);

      await batch.commit();

      if (!mounted) return;

      Navigator.of(context).pop();

      AppDesign.showSuccessSnackBar(
        context,
        'تم قبول المستفيد بنجاح',
      );
    } catch (e) {
      debugPrint('Approve Beneficiary Error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(
        context,
        'حدث خطأ أثناء قبول الطلب',
      );
    }
  }

  // =========================================================
  // Reject Beneficiary
  // =========================================================

  Future<void> _showRejectDialog({
    required String beneficiaryId,
    required String beneficiaryUserId,
    required String name,
  }) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppDesign.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Text(
                  'رفض الطلب',
                  textAlign: TextAlign.center,
                  style: AppDesign.h1Style.copyWith(
                    color: AppDesign.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'يرجى كتابة سبب رفض طلب $name',
                      textAlign: TextAlign.center,
                      style: AppDesign.bodyStyle.copyWith(
                        color: AppDesign.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: controller,
                      maxLines: 4,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'سبب الرفض',
                        errorText: errorText,
                        filled: true,
                        fillColor: AppDesign.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppDesign.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppDesign.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppDesign.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: Text(
                      'إلغاء',
                      style: AppDesign.bodyStyle.copyWith(
                        color: AppDesign.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      final value = controller.text.trim();

                      if (value.isEmpty) {
                        setDialogState(() {
                          errorText = 'سبب الرفض مطلوب';
                        });
                        return;
                      }

                      Navigator.pop(dialogContext, value);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('رفض الطلب'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      final beneficiaryRef =
          _firestore.collection('beneficiaries').doc(beneficiaryId);



      final batch = _firestore.batch();

      // تحديث حالة المستفيد
      batch.update(
        beneficiaryRef,
        {
          'status': 'rejected',
          'rejectionReason': reason.trim(),
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': widget.userId,

          // لو كان هناك قبول سابق
          'approvedAt': FieldValue.delete(),
          'approvedBy': FieldValue.delete(),
        },
      );

      // توحيد الحالة في Users
      batch.set(
        _firestore.collection('Users').doc(beneficiaryUserId),
        {'status': 'rejected'},
        SetOptions(merge: true),
      );

_addBeneficiaryNotificationToBatch(
  batch: batch,
  beneficiaryUserId: beneficiaryUserId,
  isApproved: false,
  rejectionReason: reason,
);
      await batch.commit();

      if (!mounted) return;

      // إغلاق Bottom Sheet
      Navigator.of(context).pop();

      AppDesign.showSuccessSnackBar(
        context,
        'تم رفض الطلب',
      );
    } catch (e) {
      debugPrint('Reject Beneficiary Error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(
        context,
        'حدث خطأ أثناء رفض الطلب',
      );
    }
  }

  // =========================================================
  // Delete Approved Beneficiary
  // =========================================================

  Future<void> _deleteBeneficiary({
    required String beneficiaryId,
    required String beneficiaryUserId,
    required String name,
  }) async {
    final confirmed = await _showConfirmDialog(
      title: 'حذف المستفيد',
      message: 'هل أنت متأكد من حذف $name من قائمة المستفيدين؟',
      confirmText: 'حذف',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      final beneficiaryRef =
          _firestore.collection('beneficiaries').doc(beneficiaryId);

      final batch = _firestore.batch();

      // 1) Soft Delete: إيقاف الحساب في beneficiaries و Users
      batch.update(beneficiaryRef, {
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': widget.userId,
      });

      batch.set(
        _firestore.collection('Users').doc(beneficiaryUserId),
        {'status': 'deleted'},
        SetOptions(merge: true),
      );

      // 2) تفريغ سلة المستفيد
      final cartSnap = await _firestore
          .collection('cart')
          .where('beneficiaryId', isEqualTo: beneficiaryUserId)
          .where('status', isEqualTo: 'in_cart')
          .get();

      for (final cartDoc in cartSnap.docs) {
        batch.delete(cartDoc.reference);
      }

      // 3) إلغاء الطلبات اللي ما قبلها مندوب، وإرجاع صناديقها متاحة
      final requestsSnap = await _firestore
          .collection('requests')
          .where('beneficiaryId', isEqualTo: beneficiaryUserId)
          .where('status', isEqualTo: 'requested')
          .get();

      for (final requestDoc in requestsSnap.docs) {
        final requestData = requestDoc.data();
        final courierId =
            requestData['courierID'] ?? requestData['courierId'];

        // الطلب اللي قبله مندوب يكمل عادي
        if (courierId != null && courierId.toString().isNotEmpty) continue;

        batch.update(requestDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelReason': 'beneficiary_deleted',
        });

        final boxesSnap = await _firestore
            .collection('donation_boxes')
            .where('requestId', isEqualTo: requestDoc.id)
            .get();

        for (final boxDoc in boxesSnap.docs) {
          batch.update(boxDoc.reference, {
            'status': 'available',
            'requestId': FieldValue.delete(),
          });
        }
      }

      await batch.commit();

      if (!mounted) return;

      Navigator.of(context).pop();

      AppDesign.showSuccessSnackBar(
        context,
        'تم حذف المستفيد من القائمة',
      );
    } catch (e) {
      debugPrint('Delete Beneficiary Error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(
        context,
        'حدث خطأ أثناء حذف المستفيد',
      );
    }
  }

  // =========================================================
  // Confirm Dialog
  // =========================================================

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppDesign.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              title,
              textAlign: TextAlign.center,
              style: AppDesign.h1Style.copyWith(
                color: AppDesign.primary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              message,
              textAlign: TextAlign.center,
              style: AppDesign.bodyStyle.copyWith(
                color: AppDesign.textSecondary,
                height: 1.6,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: Text(
                  'إلغاء',
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: destructive
                      ? Colors.red.shade700
                      : AppDesign.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(confirmText),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  // =========================================================
  // PDF
  // =========================================================

  Future<void> _openPdf(String url) async {
    if (url.trim().isEmpty) {
      AppDesign.showErrorSnackBar(
        context,
        'ملف إثبات الضمان غير متوفر',
      );
      return;
    }

    try {
      final uri = Uri.parse(url);

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        AppDesign.showErrorSnackBar(
          context,
          'تعذر فتح الملف',
        );
      }
    } catch (e) {
      debugPrint('Open PDF Error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(
        context,
        'تعذر فتح الملف',
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
          child: Column(
            children: [
              _buildHeader(),

              const SizedBox(height: 18),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: _buildTabs(),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _beneficiariesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppDesign.primary,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState();
                    }

                    final allDocs = snapshot.data?.docs ?? [];

                    final filteredDocs = allDocs.where((doc) {
                      final status = _getStatus(doc.data());

                      if (selectedTab == 0) {
                        return status == 'pending';
                      }

                      return status == 'approved';
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        5,
                        20,
                        30,
                      ),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];

                        return _buildBeneficiaryCard(
                          beneficiaryId: doc.id,
                          beneficiaryData: doc.data(),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // Header
  // =========================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppDesign.primary,
            ),
          ),

          const Expanded(
            child: Text(
              'إدارة المستفيدين',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppDesign.fontFamily,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: AppDesign.primary,
              ),
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // =========================================================
  // Tabs
  // =========================================================

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppDesign.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              index: 0,
              title: 'طلبات التسجيل',
            ),
          ),
          Expanded(
            child: _buildTab(
              index: 1,
              title: 'المستفيدون',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required String title,
  }) {
    final selected = selectedTab == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppDesign.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: AppDesign.bodyStyle.copyWith(
            color: selected
                ? AppDesign.white
                : AppDesign.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // Beneficiary Card
  // =========================================================

  Widget _buildBeneficiaryCard({
    required String beneficiaryId,
    required Map<String, dynamic> beneficiaryData,
  }) {
    final userId = _getUserId(
      beneficiaryId,
      beneficiaryData,
    );

    final status = _getStatus(beneficiaryData);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserData(userId),
      builder: (context, snapshot) {
        final userData = snapshot.data;

        final name = _getName(userData);
        final phone = _getPhone(userData);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: snapshot.connectionState ==
                    ConnectionState.waiting
                ? null
                : () {
                    _showBeneficiaryDetails(
                      beneficiaryId: beneficiaryId,
                      beneficiaryUserId: userId,
                      beneficiaryData: beneficiaryData,
                      userData: userData,
                    );
                  },
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppDesign.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppDesign.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          AppDesign.secondary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppDesign.primary,
                      size: 27,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: snapshot.connectionState ==
                            ConnectionState.waiting
                        ? const LinearProgressIndicator(
                            color: AppDesign.primary,
                          )
                        : Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    AppDesign.h1Style.copyWith(
                                  color: AppDesign.primary,
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                phone,
                                textDirection:
                                    TextDirection.ltr,
                                style:
                                    AppDesign.bodyStyle.copyWith(
                                  color:
                                      AppDesign.textSecondary,
                                  fontSize: 13,
                                ),
                              ),

                              if (status == 'pending') ...[
                                const SizedBox(height: 8),
                                _buildStatusBadge(
                                  'قيد المراجعة',
                                  Icons.schedule_rounded,
                                ),
                              ],

                              if (status == 'approved') ...[
                                const SizedBox(height: 8),
                                _buildStatusBadge(
                                  'مقبول',
                                  Icons.check_circle_outline,
                                ),
                              ],
                            ],
                          ),
                  ),

                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppDesign.primary,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(
    String text,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppDesign.secondary.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppDesign.primary,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppDesign.bodyStyle.copyWith(
              color: AppDesign.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Beneficiary Details
  // =========================================================

  Future<void> _showBeneficiaryDetails({
    required String beneficiaryId,
    required String beneficiaryUserId,
    required Map<String, dynamic> beneficiaryData,
    required Map<String, dynamic>? userData,
  }) async {
    final name = _getName(userData);
    final phone = _getPhone(userData);

    final socialSecurityNumber =
        _getSocialSecurityNumber(beneficiaryData);

    final pdfUrl = _getPdfUrl(beneficiaryData);

    final status = _getStatus(beneficiaryData);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(sheetContext).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: AppDesign.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom +
                    30,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppDesign.border,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color:
                          AppDesign.secondary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppDesign.primary,
                      size: 36,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AppDesign.h1Style.copyWith(
                      color: AppDesign.primary,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildDetailItem(
                    icon: Icons.phone_outlined,
                    label: 'رقم الجوال',
                    value: phone,
                  ),

                  _buildDetailItem(
                    icon: Icons.badge_outlined,
                    label: 'رقم الضمان الاجتماعي',
                    value: socialSecurityNumber,
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppDesign.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppDesign.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: AppDesign.secondary
                                .withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: AppDesign.primary,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إثبات الضمان الاجتماعي',
                                style:
                                    AppDesign.bodyStyle.copyWith(
                                  color: AppDesign.primary,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                pdfUrl.isEmpty
                                    ? 'لا يوجد ملف مرفق'
                                    : 'عرض الملف المرفق',
                                style:
                                    AppDesign.bodyStyle.copyWith(
                                  color:
                                      AppDesign.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (pdfUrl.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _openPdf(pdfUrl);
                            },
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              color: AppDesign.primary,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  if (status == 'pending') ...[
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _approveBeneficiary(
                            beneficiaryId:
                                beneficiaryId,
                            beneficiaryUserId:
                                beneficiaryUserId,
                            name: name,
                          );
                        },
                        icon: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'قبول الطلب',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppDesign.primary,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      height: 52,
                      child: TextButton.icon(
                        onPressed: () {
                          _showRejectDialog(
                            beneficiaryId:
                                beneficiaryId,
                            beneficiaryUserId:
                                beneficiaryUserId,
                            name: name,
                          );
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.red.shade700,
                        ),
                        label: Text(
                          'رفض الطلب',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (status == 'approved')
                    SizedBox(
                      height: 52,
                      child: TextButton.icon(
                        onPressed: () {
                          _deleteBeneficiary(
                            beneficiaryId:
                                beneficiaryId,
                            beneficiaryUserId:
                                beneficiaryUserId,
                            name: name,
                          );
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red.shade700,
                        ),
                        label: Text(
                          'حذف المستفيد',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // Detail Item
  // =========================================================

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppDesign.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppDesign.primary,
            size: 22,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.textSecondary,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Empty State
  // =========================================================

  Widget _buildEmptyState() {
    final title = selectedTab == 0
        ? 'لا توجد طلبات تسجيل'
        : 'لا يوجد مستفيدون حاليًا';

    final subtitle = selectedTab == 0
        ? 'ستظهر طلبات التسجيل الجديدة هنا'
        : 'سيظهر المستفيدون المقبولون هنا';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color:
                    AppDesign.secondary.withOpacity(0.13),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: AppDesign.primary,
                size: 36,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: AppDesign.h1Style.copyWith(
                color: AppDesign.primary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppDesign.bodyStyle.copyWith(
                color: AppDesign.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // Error State
  // =========================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade700,
            ),

            const SizedBox(height: 14),

            Text(
              'تعذر تحميل بيانات المستفيدين',
              textAlign: TextAlign.center,
              style: AppDesign.h1Style.copyWith(
                color: AppDesign.primary,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'تحقق من الاتصال وحاول مرة أخرى',
              textAlign: TextAlign.center,
              style: AppDesign.bodyStyle.copyWith(
                color: AppDesign.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
