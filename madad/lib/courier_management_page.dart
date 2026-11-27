import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_design.dart';
import 'add_courier_page.dart';
import 'edit_courier_page.dart';

class CourierManagementPage extends StatefulWidget {
  const CourierManagementPage({super.key});

  @override
  State<CourierManagementPage> createState() => _CourierManagementPageState();
}

class _CourierManagementPageState extends State<CourierManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[\s+\-()]'), '').toLowerCase();
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'ابحث باسم المندوب أو رقم الجوال',
          hintTextDirection: TextDirection.rtl,
          prefixIcon: const Icon(Icons.search, color: AppDesign.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppDesign.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppDesign.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppDesign.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppDesign.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _couriersStream() {
    return _firestore.collection('couriers').snapshots();
  }

  String _getStatus(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'active').toString().trim();

    return status.isEmpty ? 'active' : status;
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'نشط';
      case 'inactive':
        return 'غير نشط';
      default:
        return status;
    }
  }

  bool _isActive(String status) {
    return status.toLowerCase() == 'active' || status == 'نشط';
  }

  Future<int> _getCompletedDeliveries(String userId) async {
    final donationsSnapshot = await _firestore
        .collection('donations')
        .where('courierId', isEqualTo: userId)
        .where('courierTaskStatus', isEqualTo: 'completed')
        .get();

    final requestsSnapshot = await _firestore
        .collection('requests')
        .where('courierId', isEqualTo: userId)
        .where('courierTaskStatus', isEqualTo: 'completed')
        .get();

    final completedCount =
        donationsSnapshot.docs.length + requestsSnapshot.docs.length;

    final courierRef = _firestore.collection('couriers').doc(userId);
    final courierDoc = await courierRef.get();

    if (courierDoc.exists &&
        courierDoc.data()?['completedDeliveries'] != completedCount) {
      await courierRef.update({'completedDeliveries': completedCount});
    }

    return completedCount;
  }

  Future<void> _addCourier() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCourierPage()),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _editCourier({
    required String courierId,
    required String userId,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCourierPage(courierId: courierId, userId: userId),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteCourier(String courierId) async {
    try {
      final courierRef = _firestore.collection('couriers').doc(courierId);

      final courierDoc = await courierRef.get();

      if (!courierDoc.exists) {
        if (!mounted) return;

        AppDesign.showErrorSnackBar(context, 'بيانات المندوب غير موجودة');
        return;
      }

      final data = courierDoc.data() ?? <String, dynamic>{};
      final userId = (data['userID'] ?? '').toString().trim();

      final batch = _firestore.batch();

      if (userId.isEmpty) {
        batch.delete(courierRef);
      } else {
        batch.update(courierRef, {'status': 'deleted'});
      }

      if (userId.isNotEmpty) {
        for (final collection in ['donations', 'requests']) {
          final tasksSnap = await _firestore
              .collection(collection)
              .where('courierId', isEqualTo: userId)
              .where('courierTaskStatus', isEqualTo: 'active')
              .get();

          for (final taskDoc in tasksSnap.docs) {
            batch.update(taskDoc.reference, {
              'courierId': FieldValue.delete(),
              'courierTaskStatus': FieldValue.delete(),
              if (collection == 'donations')
                'updatedAt': FieldValue.serverTimestamp(),
            });

            final boxesSnap = await _firestore
                .collection('donation_boxes')
                .where(
                  collection == 'donations' ? 'donationId' : 'requestId',
                  isEqualTo: taskDoc.id,
                )
                .get();

            for (final boxDoc in boxesSnap.docs) {
              batch.update(boxDoc.reference, {
                'courierId': FieldValue.delete(),
              });
            }
          }
        }
      }

      await batch.commit();

      if (!mounted) return;

      AppDesign.showSuccessSnackBar(context, 'تم حذف المندوب بنجاح');
    } catch (e) {
      debugPrint('Delete Courier Error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء حذف المندوب');
    }
  }

  Future<void> _showDeleteDialog(String courierId) async {
    final confirmed = await AppDesign.showAppDialog(
      context: context,
      title: 'حذف المندوب',
      message: 'هل أنت متأكد من حذف هذا المندوب؟',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
    );

    if (confirmed) {
      await _deleteCourier(courierId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton(
          onPressed: _addCourier,
          backgroundColor: AppDesign.primary,
          foregroundColor: AppDesign.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.add, size: 30),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),

              const SizedBox(height: 18),

              _buildSearchField(),

              const SizedBox(height: 15),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _couriersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppDesign.primary,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ أثناء تحميل المناديب',
                          style: AppDesign.bodyStyle.copyWith(
                            color: AppDesign.textSecondary,
                          ),
                        ),
                      );
                    }

                    final docs = (snapshot.data?.docs ?? []).where((doc) {
                      final status = _getStatus(doc.data()).toLowerCase();

                      return status != 'deleted';
                    }).toList();

                    if (docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 100),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();

                        final userId = data['userID']?.toString() ?? '';

                        final status = _getStatus(data);

                        if (userId.isEmpty) {
                          final pendingPhone = (data['phone'] ?? '').toString();

                          if (pendingPhone.isEmpty) {
                            return _buildInvalidCourierCard(doc.id, status);
                          }

                          final pendingName =
                              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                                  .trim();

                          final matchesPending =
                              _searchQuery.isEmpty ||
                              pendingName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              _normalizePhone(
                                pendingPhone,
                              ).contains(_normalizePhone(_searchQuery));

                          if (!matchesPending) {
                            return const SizedBox.shrink();
                          }

                          return _buildCourierCard(
                            courierId: doc.id,
                            userId: '',
                            courierName: pendingName.isEmpty
                                ? 'اسم غير متوفر'
                                : pendingName,
                            phone: pendingPhone,
                            status: status,
                            completedDeliveries: 0,
                          );
                        }

                        return FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          future: _firestore
                              .collection('Users')
                              .doc(userId)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _buildLoadingCard();
                            }

                            final userData = userSnapshot.data?.data() ?? {};

                            final firstName = (userData['firstName'] ?? '')
                                .toString();

                            final lastName = (userData['lastName'] ?? '')
                                .toString();

                            final name = '$firstName $lastName'.trim();

                            final phone = (userData['phone'] ?? 'غير متوفر')
                                .toString();

                            final searchName = name.toLowerCase();
                            final searchPhone = _normalizePhone(phone);
                            final normalizedQuery = _normalizePhone(
                              _searchQuery,
                            );

                            final matchesSearch =
                                _searchQuery.isEmpty ||
                                searchName.contains(_searchQuery) ||
                                searchPhone.contains(normalizedQuery);

                            if (!matchesSearch) {
                              return const SizedBox.shrink();
                            }

                            return FutureBuilder<int>(
                              future: _getCompletedDeliveries(userId),
                              builder: (context, completedSnapshot) {
                                if (completedSnapshot.hasError) {
                                  debugPrint(
                                    'Completed Deliveries Error: '
                                    '${completedSnapshot.error}',
                                  );
                                }

                                final completedDeliveries =
                                    completedSnapshot.data ?? 0;

                                return _buildCourierCard(
                                  courierId: doc.id,
                                  userId: userId,
                                  courierName: name.isEmpty
                                      ? 'اسم غير متوفر'
                                      : name,
                                  phone: phone,
                                  status: status,
                                  completedDeliveries: completedDeliveries,
                                );
                              },
                            );
                          },
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                'إدارة المناديب',
                textAlign: TextAlign.center,
                style: AppDesign.h1Style.copyWith(
                  color: AppDesign.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_forward,
                  textDirection: TextDirection.ltr,
                  color: AppDesign.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 70,
              color: AppDesign.textSecondary,
            ),

            AppGap.md,

            Text('لا يوجد مناديب حاليًا', style: AppDesign.h2Style),

            AppGap.sm,

            Text(
              'اضغط على + لإضافة مندوب جديد',
              style: AppDesign.bodySecondaryStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesign.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppDesign.primary),
      ),
    );
  }

  Widget _buildCourierCard({
    required String courierId,
    required String userId,
    required String courierName,
    required String phone,
    required String status,
    required int completedDeliveries,
  }) {
    final firstLetter = courierName.trim().isNotEmpty
        ? courierName.trim()[0]
        : 'م';

    final active = _isActive(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesign.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppDesign.secondary.withOpacity(0.17),
                child: Text(
                  firstLetter,
                  style: AppDesign.h1Style.copyWith(
                    color: AppDesign.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesign.h1Style.copyWith(
                        color: AppDesign.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: AppDesign.textSecondary,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppDesign.bodyStyle.copyWith(
                              color: AppDesign.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 7),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppDesign.softGreen.withOpacity(0.25)
                      : AppDesign.secondary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _displayStatus(status),
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Divider(color: AppDesign.border, height: 1),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 20,
                color: AppDesign.primary,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'الرحلات المكتملة',
                  style: AppDesign.bodySecondaryStyle,
                ),
              ),

              Text(
                '$completedDeliveries',
                style: AppDesign.bodyStyle.copyWith(
                  color: AppDesign.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _editCourier(courierId: courierId, userId: userId),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    label: const Text('تعديل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppDesign.primary,
                      side: const BorderSide(
                        color: AppDesign.primary,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: AppDesign.bodyStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDeleteDialog(courierId),
                    icon: const Icon(Icons.delete_outline, size: 19),
                    label: const Text('حذف'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.primary,
                      foregroundColor: AppDesign.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: AppDesign.bodyStyle.copyWith(
                        color: AppDesign.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvalidCourierCard(String courierId, String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesign.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 45,
            color: Colors.orange,
          ),

          AppGap.sm,

          Text('بيانات المندوب غير مكتملة', style: AppDesign.h2Style),

          AppGap.sm,

          Text(
            'لم يتم ربط هذا المندوب بحساب مستخدم.',
            textAlign: TextAlign.center,
            style: AppDesign.bodySecondaryStyle,
          ),

          AppGap.sm,

          Text('الحالة: ${_displayStatus(status)}', style: AppDesign.bodyStyle),

          AppGap.md,

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _showDeleteDialog(courierId),
              icon: const Icon(Icons.delete_outline),
              label: const Text('حذف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesign.primary,
                foregroundColor: AppDesign.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
