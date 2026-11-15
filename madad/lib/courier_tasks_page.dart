import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';
// Still needed: taskSortTime is used for sorting the completed tab.
import 'request_items_helper.dart';

class CourierTasksPage extends StatefulWidget {
  final String userId;

  const CourierTasksPage({super.key, required this.userId});

  @override
  State<CourierTasksPage> createState() => _CourierTasksPageState();
}

class _CourierTasksPageState extends State<CourierTasksPage> {
  int _selectedTab = 0;
  late Stream<QuerySnapshot> _donationsStreamValue = _donationsStream();
  late Stream<QuerySnapshot> _requestsStreamValue = _requestsStream();

  Future<void> _acceptTask({
    required String collection, // 'donations' or 'requests'
    required String boxField, // 'donationId' or 'requestId'
    required String id,
    required String dialogTitle,
    required String dialogMessage,
    required String successMessage,
    required String requiredStatus,
  }) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: dialogTitle,
      message: dialogMessage,
      confirmText: 'قبول الطلب',
    );
    if (confirm != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection(collection).doc(id);
      final boxes = await db
          .collection('donation_boxes')
          .where(boxField, isEqualTo: id)
          .get();

      final accepted = await db.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (snap.data()?['status'] != requiredStatus) return false;
        final current = snap.data()?['courierId'];
        if (current != null && current.toString().isNotEmpty) return false;

        tx.update(ref, {
          'courierId': widget.userId,
          'courierTaskStatus': 'active',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        for (final b in boxes.docs) {
          tx.update(b.reference, {'courierId': widget.userId});
        }
        return true;
      });

      if (!mounted) return;
      if (accepted) {
        AppDesign.showSuccessSnackBar(context, successMessage);
      } else {
        AppDesign.showErrorSnackBar(context, 'تم قبول هذا الطلب من مندوب آخر');
      }
    } catch (e) {
      debugPrint('accept task error: $e');
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء قبول الطلب');
    }
  }

  Future<void> _acceptDonationTask(String id) => _acceptTask(
    collection: 'donations',
    boxField: 'donationId',
    id: id,
    dialogTitle: 'قبول الطلب',
    dialogMessage: 'هل أنت متأكد من رغبتك في قبول هذا الطلب؟',
    successMessage: 'تم قبول الطلب بنجاح وإضافته لمهامك النشطة',
    requiredStatus: 'published',
  );

  Future<void> _acceptRequestTask(String id) => _acceptTask(
    collection: 'requests',
    boxField: 'requestId',
    id: id,
    dialogTitle: 'قبول طلب المستفيد',
    dialogMessage: 'هل أنت متأكد من رغبتك في قبول توصيل هذا الطلب؟',
    successMessage: 'تم قبول طلب المستفيد بنجاح وإضافته لمهامك',
    requiredStatus: 'requested',
  );

  Stream<QuerySnapshot> _donationsStream() {
    final col = FirebaseFirestore.instance.collection('donations');

    if (_selectedTab == 0) {
      return col
          .where('status', isEqualTo: 'published')
          .where('deliveryMethod', isEqualTo: 'pickup')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return col
        .where('courierId', isEqualTo: widget.userId)
        .where('courierTaskStatus', isEqualTo: 'completed')
        .snapshots();
  }

  Stream<QuerySnapshot> _requestsStream() {
    final col = FirebaseFirestore.instance.collection('requests');

    if (_selectedTab == 0) {
      return col
          .where('status', isEqualTo: 'requested')
          .where('deliveryMethod', isEqualTo: 'delivery')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return col
        .where('courierId', isEqualTo: widget.userId)
        .where('courierTaskStatus', isEqualTo: 'completed')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        appBar: AppBar(
          title: const Text('إدارة مهام التوصيل'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDesign.screenPadding),
              child: Container(
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppDesign.white,
                  borderRadius: BorderRadius.circular(AppDesign.radiusLG),
                  border: Border.all(color: AppDesign.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        title: 'الطلبات المتاحة',
                        index: 0,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        title: 'الطلبات المكتملة',
                        index: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _donationsStreamValue,
                builder: (context, donationsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _requestsStreamValue,
                    builder: (context, requestsSnap) {
                      if (donationsSnap.connectionState ==
                              ConnectionState.waiting ||
                          requestsSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (donationsSnap.hasError || requestsSnap.hasError) {
                        return const Center(
                          child: Text('حدث خطأ في تحميل المهام'),
                        );
                      }

                      final donationDocs = donationsSnap.data?.docs ?? [];
                      final requestDocs = requestsSnap.data?.docs ?? [];

                      List<Map<String, dynamic>> combinedTasks = [];

                      for (var doc in donationDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? '';
                        final courierTaskStatus =
                            (data['courierTaskStatus'] ?? '')
                                .toString()
                                .toLowerCase();
                        final deliveryMethod = data['deliveryMethod'] ?? '';
                        final courierId = data['courierId'];

                        bool isAvailable =
                            (_selectedTab == 0) &&
                            status == 'published' &&
                            deliveryMethod == 'pickup' &&
                            (courierId == null || courierId.toString().isEmpty);

                        bool isCompleted =
                            (_selectedTab == 1) &&
                            (courierId == widget.userId) &&
                            (courierTaskStatus == 'completed');

                        if (isAvailable || isCompleted) {
                          combinedTasks.add({
                            'id': doc.id,
                            'type': 'donation',
                            'data': data,
                          });
                        }
                      }

                      for (var doc in requestDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? '';
                        final courierTaskStatus =
                            (data['courierTaskStatus'] ?? '')
                                .toString()
                                .toLowerCase();
                        final deliveryMethod =
                            data['deliveryMethod'] ?? ''; // جلب طريقة التوصيل
                        final courierId = data['courierId'];

                        bool isAvailable =
                            (_selectedTab == 0) &&
                            deliveryMethod == 'delivery' &&
                            status == 'requested' &&
                            (courierId == null || courierId.toString().isEmpty);

                        bool isCompleted =
                            (_selectedTab == 1) &&
                            (courierId == widget.userId) &&
                            (courierTaskStatus == 'completed');

                        if (isAvailable || isCompleted) {
                          combinedTasks.add({
                            'id': doc.id,
                            'type': 'request',
                            'data': data,
                          });
                        }
                      }
                      DateTime createdAtOf(Map<String, dynamic> d) {
                        final v = d['createdAt'];
                        return v is Timestamp
                            ? v.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                      }

                      combinedTasks.sort((a, b) {
                        final da = a['data'] as Map<String, dynamic>;
                        final db = b['data'] as Map<String, dynamic>;

                        if (_selectedTab == 0) {
                          return createdAtOf(
                            db,
                          ).compareTo(createdAtOf(da)); // newest first
                        }
                        final ta = taskSortTime(
                          da,
                          isDonation: a['type'] == 'donation',
                          completed: true,
                        );
                        final tb = taskSortTime(
                          db,
                          isDonation: b['type'] == 'donation',
                          completed: true,
                        );
                        return tb.compareTo(ta);
                      });
                      if (combinedTasks.isEmpty) {
                        return Center(
                          child: Text(
                            _selectedTab == 0
                                ? 'لا توجد طلبات متاحة حالياً'
                                : 'لا توجد طلبات مكتملة',
                            style: AppDesign.bodySecondaryStyle,
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.screenPadding,
                        ),
                        itemCount: combinedTasks.length,
                        itemBuilder: (context, index) {
                          final task = combinedTasks[index];
                          final id = task['id'] as String;
                          final type = task['type'];
                          final data = task['data'] as Map<String, dynamic>;

                          if (type == 'donation') {
                            return _buildDonationTaskCard(id, data);
                          } else {
                            return _buildRequestTaskCard(id, data);
                          }
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
    );
  }

  Widget _buildDonationTaskCard(String docId, Map<String, dynamic> data) {
    final pickupAddressMap = data['pickupAddress'];
    final rawCity = pickupAddressMap is Map
        ? (pickupAddressMap['city'] ?? '').toString().trim()
        : (data['city'] ?? '').toString().trim();

    final rawDistrict = pickupAddressMap is Map
        ? (pickupAddressMap['district'] ?? '').toString().trim()
        : (data['district'] ?? '').toString().trim();

    final city = rawCity.isNotEmpty ? rawCity : 'لا يوجد';
    final district = rawDistrict.isNotEmpty ? rawDistrict : 'لا يوجد';

    final totalBoxes =
        ((data['numberOfItems'] ?? 0) is num
                ? (data['numberOfItems'] as num) / 5
                : 1)
            .ceil();
    final boxCount =
        ((data['boxCodes'] is List)
                ? (data['boxCodes'] as List).length
                : totalBoxes)
            .clamp(0, 999999);
    final donorId = data['donorId'] ?? '';

    final String pickupLocation = '$city - $district';
    final String deliveryLocation = 'المستودع';

    return FutureBuilder(
      future: donorId.isNotEmpty
          ? FirebaseFirestore.instance.collection('Users').doc(donorId).get()
          : Future.value(null),
      builder: (context, userSnapshot) {
        String donorName = 'صاحب الطلب';
        String donorPhone = 'غير متوفر';

        if (userSnapshot.hasData &&
            userSnapshot.data != null &&
            userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map? ?? {};
          donorName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                  .trim();
          donorPhone = (userData['phone'] ?? userData['phoneNumber'] ?? '')
              .toString();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: AppDesign.spaceMD),
          padding: const EdgeInsets.all(AppDesign.cardPadding),
          decoration: AppDesign.primaryCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب تبرع',
                    style: AppDesign.subtitleStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'موقع الاستلام: $pickupLocation',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'موقع التسليم: $deliveryLocation',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عدد الصناديق: $boxCount',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'صاحب الطلب: $donorName',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'رقم الجوال: ${donorPhone.isNotEmpty ? donorPhone : 'غير متوفر'}',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedTab == 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _acceptDonationTask(docId),
                    child: const Text('قبول الطلب'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestTaskCard(String requestId, Map<String, dynamic> data) {
    final beneficiaryId = data['beneficiaryId'] ?? data['beneficiaryID'] ?? '';
    final List itemIds = data['itemIds'] is List
        ? data['itemIds'] as List
        : const [];
    final int itemsCount = itemIds.length;
    final addressMap = data['deliveryAddress'];
    final warehouseName = addressMap is Map
        ? (addressMap['warehouseName'] ?? 'المستودع').toString()
        : 'المستودع';

    String deliveryAddressText = 'عنوان المستفيد';
    if (addressMap is Map) {
      final city = (addressMap['city'] ?? '').toString();
      final district = (addressMap['district'] ?? '').toString();

      List<String> addressParts = [];
      if (city.isNotEmpty) addressParts.add(city);
      if (district.isNotEmpty) addressParts.add(district);

      if (addressParts.isNotEmpty) {
        deliveryAddressText = addressParts.join(' - ');
      }
    }

    return FutureBuilder(
      future: beneficiaryId.isNotEmpty && beneficiaryId != '-'
          ? FirebaseFirestore.instance
                .collection('Users')
                .doc(beneficiaryId)
                .get()
          : Future.value(null),
      builder: (context, userSnapshot) {
        String beneficiaryName = 'المستفيد';
        String beneficiaryPhone = 'غير متوفر';

        if (userSnapshot.hasData &&
            userSnapshot.data != null &&
            userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map? ?? {};
          beneficiaryName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                  .trim();
          beneficiaryPhone =
              (userData['phone'] ?? userData['phoneNumber'] ?? '').toString();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: AppDesign.spaceMD),
          padding: const EdgeInsets.all(AppDesign.cardPadding),
          decoration: AppDesign.primaryCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب مستفيد',
                    style: AppDesign.subtitleStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'موقع الاستلام: $warehouseName',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'موقع التسليم: $deliveryAddressText',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عدد القطع: $itemsCount',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المستفيد: $beneficiaryName',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: AppDesign.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'رقم الجوال: ${beneficiaryPhone.isNotEmpty ? beneficiaryPhone : 'غير متوفر'}',
                      style: AppDesign.bodySecondaryStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedTab == 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _acceptRequestTask(requestId),
                    child: const Text('قبول الطلب'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge() {
    final isCompleted = _selectedTab == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.grey.shade300
            : AppDesign.warning.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isCompleted ? 'مكتمل' : 'متاح',
        style: AppDesign.captionStyle.copyWith(
          fontWeight: FontWeight.bold,
          color: isCompleted ? Colors.grey.shade700 : null,
        ),
      ),
    );
  }

  Widget _buildTabButton({required String title, required int index}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTab == index) return;
        setState(() {
          _selectedTab = index;
          _donationsStreamValue = _donationsStream();
          _requestsStreamValue = _requestsStream();
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppDesign.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        ),
        child: Text(
          title,
          style: AppDesign.bodyStyle.copyWith(
            color: isSelected ? AppDesign.white : AppDesign.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
