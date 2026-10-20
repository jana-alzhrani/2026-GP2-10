import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';

class CourierTasksPage extends StatefulWidget {
  final String userId;

  const CourierTasksPage({super.key, required this.userId});

  @override
  State<CourierTasksPage> createState() => _CourierTasksPageState();
}

class _CourierTasksPageState extends State<CourierTasksPage> {
  int _selectedTab = 0;

  Future _acceptDonationTask(String donationId, Map donationData) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'قبول الطلب',
      message: 'هل أنت متأكد من رغبتك في قبول هذا الطلب؟',
      confirmText: 'قبول الطلب',
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final donationRef = FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId);
      batch.update(donationRef, {
        'courierId': widget.userId,
        'courierTaskStatus': 'active',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      final boxesSnapshot = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .where('donationId', isEqualTo: donationId)
          .get();

      for (var boxDoc in boxesSnapshot.docs) {
        batch.update(boxDoc.reference, {'courierId': widget.userId});
      }

      await batch.commit();

      if (!mounted) return;
      AppDesign.showSuccessSnackBar(
        context,
        'تم قبول الطلب بنجاح وإضافته لمهامك النشطة',
      );
    } catch (e) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء قبول الطلب: $e');
    }
  }

  Future _acceptRequestTask(String requestId, Map requestData) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'قبول طلب المستفيد',
      message: 'هل أنت متأكد من رغبتك في قبول توصيل هذا الطلب؟',
      confirmText: 'قبول الطلب',
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final requestRef = FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId);
      batch.update(requestRef, {
        'courierId': widget.userId,
        'courierTaskStatus': 'active',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      final boxesSnapshot = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .where('requestId', isEqualTo: requestId)
          .get();

      for (var boxDoc in boxesSnapshot.docs) {
        batch.update(boxDoc.reference, {'courierId': widget.userId});
      }

      await batch.commit();

      if (!mounted) return;
      AppDesign.showSuccessSnackBar(
        context,
        'تم قبول طلب المستفيد بنجاح وإضافته لمهامك',
      );
    } catch (e) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء قبول الطلب: $e');
    }
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
                stream: FirebaseFirestore.instance
                    .collection('donations')
                    .snapshots(),
                builder: (context, donationsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('requests')
                        .snapshots(),
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
                            (status == 'published' || status == 'reserved') &&
                            deliveryMethod != 'self_delivery' &&
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
                            'status': status,
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
                            (status == 'requested' || status.isEmpty) &&
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
                            'status': status,
                          });
                        }
                      }

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
                          final id = task['id'];
                          final type = task['type'];
                          final data = task['data'] as Map<String, dynamic>;
                          final status = task['status'];

                          if (type == 'donation') {
                            return _buildDonationTaskCard(id, data, status);
                          } else {
                            return _buildRequestTaskCard(id, data, status);
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

  Widget _buildDonationTaskCard(
    String docId,
    Map<String, dynamic> data,
    String status,
  ) {
    // قراءة العنوان من خريطة pickupAddress بشكل صحيح
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

    final String pickupLocation = status == 'reserved'
        ? 'المستودع'
        : '$city - $district';
    final String deliveryLocation = status == 'reserved'
        ? '$city - $district'
        : 'المستودع';

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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (status == 'completed' || status == 'available')
                          ? AppDesign.success.withOpacity(0.2)
                          : AppDesign.warning.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedTab == 1 ? 'مكتمل' : '',
                      style: AppDesign.captionStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                    onPressed: () => _acceptDonationTask(docId, data),
                    child: const Text('قبول الطلب'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestTaskCard(
    String requestId,
    Map<String, dynamic> data,
    String status,
  ) {
    final beneficiaryId = data['beneficiaryId'] ?? data['beneficiaryID'] ?? '';
    final addressMap = data['deliveryAddress'];
    final warehouseName = addressMap is Map
        ? (addressMap['warehouseName'] ?? 'المستودع').toString()
        : 'المستودع';

    String deliveryAddressText = 'عنوان المستفيد';
    if (addressMap is Map) {
      final city = addressMap['city'] ?? '';
      final district = addressMap['district'] ?? '';

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

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('donation_boxes')
              .where('requestId', isEqualTo: requestId)
              .get(),
          builder: (context, boxesSnap) {
            final boxesDocs = boxesSnap.data?.docs ?? [];
            final boxesCount = boxesSnap.data?.docs.length ?? 0;

            List<String> boxCodes = boxesDocs
                .map(
                  (b) =>
                      (b.data() as Map<String, dynamic>)['boxCode']
                          ?.toString() ??
                      'صندوق',
                )
                .toList();
            if (boxCodes.isEmpty) {
              boxCodes = ['لا توجد صناديق مضافة'];
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'completed'
                              ? AppDesign.success.withOpacity(0.2)
                              : AppDesign.warning.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _selectedTab == 1 ? 'مكتمل' : '',
                          style: AppDesign.captionStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                          'عدد الصناديق: $boxesCount',
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
                        onPressed: () => _acceptRequestTask(requestId, data),
                        child: const Text('قبول الطلب'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabButton({required String title, required int index}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
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
