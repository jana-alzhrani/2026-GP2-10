import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_design.dart';
import 'courier_tasks_page.dart';
import 'courier_more_page.dart';

class CourierHomePage extends StatefulWidget {
  final String userId;

  const CourierHomePage({super.key, required this.userId});

  @override
  State<CourierHomePage> createState() => _CourierHomePageState();
}

class _CourierHomePageState extends State<CourierHomePage> {
  int _bottomNavIndex = 0;
  String courierName = 'المندوب';
  int completedTasksCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourierData();
  }

  Future _loadCourierData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();

      final donationsSnapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('courierID', isEqualTo: widget.userId)
          .where('courierTaskStatus', isEqualTo: 'completed')
          .get();

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('courierID', isEqualTo: widget.userId)
          .where('courierTaskStatus', isEqualTo: 'completed')
          .get();

      if (!mounted) return;

      String fetchedName = 'المندوب';
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        final fullName = ('$firstName $lastName').trim();
        if (fullName.isNotEmpty) {
          fetchedName = fullName;
        }
      }

      setState(() {
        courierName = fetchedName;
        completedTasksCount =
            donationsSnapshot.docs.length + requestsSnapshot.docs.length;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    String formattedPhone = phone.trim();
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '+966${formattedPhone.substring(1)}';
    }
    final url = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'تعذر فتح تطبيق واتساب');
    }
  }

  Future _completeDonationTask(String donationId, String originalStatus) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'إتمام التوصيل',
      message: 'هل أنت متأكد من إتمام وتأكيد تسليم الطلب؟',
      confirmText: 'تأكيد التسليم',
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final boxesSnapshot = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .where('donationId', isEqualTo: donationId)
          .get();

      for (var boxDoc in boxesSnapshot.docs) {
        batch.update(boxDoc.reference, {'status': 'available'});
      }

      final targetDonationStatus = (originalStatus == 'published')
          ? 'available'
          : 'delivered';

      final donationRef = FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId);
      batch.update(donationRef, {
        'status': targetDonationStatus,
        'courierTaskStatus': 'completed',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      AppDesign.showSuccessSnackBar(context, 'تم تسجيل التسليم بنجاح');
      _loadCourierData();
    } catch (e) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء تحديث الحالة: $e');
    }
  }

  Future _completeRequestTask(String requestId) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'إتمام التوصيل للمستفيد',
      message: 'هل أنت متأكد من تسليم الطلب بنجاح؟',
      confirmText: 'تأكيد التسليم',
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final boxesSnapshot = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .where('requestId', isEqualTo: requestId)
          .get();

      final Set<String> donationIds = {};

      for (var boxDoc in boxesSnapshot.docs) {
        final boxData = boxDoc.data();

        batch.update(boxDoc.reference, {'status': 'delivered'});

        final dId = boxData['donationId'] ?? boxData['donationID'];
        if (dId != null && dId.toString().isNotEmpty) {
          donationIds.add(dId.toString());
        }
      }

      final requestRef = FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId);
      batch.update(requestRef, {
        'status': 'completed',
        'courierTaskStatus': 'completed',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      for (String dId in donationIds) {
        final donationRef = FirebaseFirestore.instance
            .collection('donations')
            .doc(dId);
        batch.update(donationRef, {
          'status': 'delivered',
          'courierTaskStatus': 'completed',
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      }

      // تنفيذ العملية دفعة واحدة (Batch Commit)
      await batch.commit();

      if (!mounted) return;
      AppDesign.showSuccessSnackBar(
        context,
        'تم إتمام توصيل طلب المستفيد وتحديث التبرعات المرتبطة بنجاح',
      );
      _loadCourierData();
    } catch (e) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء تحديث الحالة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      CourierTasksPage(userId: widget.userId),
      CourierMorePage(userId: widget.userId),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        body: pages[_bottomNavIndex],
        bottomNavigationBar: Container(
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
            selectedIndex: _bottomNavIndex,
            backgroundColor: Colors.transparent,
            indicatorColor: AppDesign.secondary.withOpacity(0.16),
            surfaceTintColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() {
                _bottomNavIndex = index;
              });
              if (index == 0) {
                _loadCourierData();
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: AppDesign.primary),
                selectedIcon: Icon(
                  Icons.home_rounded,
                  color: AppDesign.primary,
                ),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.local_shipping_outlined,
                  color: AppDesign.primary,
                ),
                selectedIcon: Icon(
                  Icons.local_shipping_rounded,
                  color: AppDesign.primary,
                ),
                label: 'المهام',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: AppDesign.primary),
                selectedIcon: Icon(Icons.person, color: AppDesign.primary),
                label: 'حسابي',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final firstLetter = courierName.trim().isNotEmpty
        ? courierName.trim()[0]
        : 'م';

    return SafeArea(
      child: RefreshIndicator(
        color: AppDesign.primary,
        onRefresh: _loadCourierData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppPadding.screen.copyWith(top: 22, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                          'مرحبًا بك',
                          style: AppDesign.bodyStyle.copyWith(
                            color: AppDesign.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          courierName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppDesign.h1Style.copyWith(
                            color: AppDesign.primary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppDesign.white,
                  borderRadius: BorderRadius.circular(AppDesign.radiusXL),
                  border: Border.all(color: AppDesign.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppDesign.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppDesign.secondary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.done_all_rounded,
                        color: AppDesign.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المهام المكتملة',
                            style: AppDesign.bodyStyle.copyWith(
                              color: AppDesign.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completedTasksCount',
                            style: AppDesign.h1Style.copyWith(
                              color: AppDesign.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'الطلبات النشطة الحالية',
                style: AppDesign.h1Style.copyWith(
                  color: AppDesign.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              // عرض التبرعات وطلبات المستفيدين النشطة المسندة للمندوب
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('donations')
                    .where('courierID', isEqualTo: widget.userId)
                    .snapshots(),
                builder: (context, donationsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('requests')
                        .where('courierID', isEqualTo: widget.userId)
                        .snapshots(),
                    builder: (context, requestsSnap) {
                      if (donationsSnap.connectionState ==
                              ConnectionState.waiting ||
                          requestsSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final donationDocs = donationsSnap.data?.docs ?? [];
                      final requestDocs = requestsSnap.data?.docs ?? [];

                      // تصفية التبرعات النشطة (غير المكتملة)
                      final activeDonations = donationDocs.where((doc) {
                        final data = doc.data() as Map;
                        final status = data['status'] ?? '';
                        return status != 'delivered' && status != 'available';
                      }).toList();

                      // تصفية طلبات المستفيدين النشطة (غير المكتملة)
                      final activeRequests = requestDocs.where((doc) {
                        final data = doc.data() as Map;
                        final status = data['status'] ?? '';
                        return status != 'completed';
                      }).toList();

                      if (activeDonations.isEmpty && activeRequests.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'لا توجد طلبات نشطة حالياً',
                              style: AppDesign.bodySecondaryStyle,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // 1. عرض التبرعات النشطة
                          ...activeDonations.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;

                            // قراءة العنوان من الخريطة pickupAddress بشكل صحيح حسب هيكل قاعدة البيانات
                            final pickupAddressMap = data['pickupAddress'];
                            final rawCity = pickupAddressMap is Map
                                ? (pickupAddressMap['city'] ?? '')
                                      .toString()
                                      .trim()
                                : (data['city'] ?? '').toString().trim();

                            final rawDistrict = pickupAddressMap is Map
                                ? (pickupAddressMap['district'] ?? '')
                                      .toString()
                                      .trim()
                                : (data['district'] ?? '').toString().trim();

                            final city = rawCity.isNotEmpty
                                ? rawCity
                                : 'لا يوجد';
                            final district = rawDistrict.isNotEmpty
                                ? rawDistrict
                                : 'لا يوجد';

                            final donorId = data['donorID'] ?? '';
                            final originalStatus =
                                data['originalStatus'] ?? 'published';

                            final String pickupLocation =
                                originalStatus == 'reserved'
                                ? 'المستودع'
                                : '$city - $district';
                            final String deliveryLocation =
                                originalStatus == 'reserved'
                                ? '$city - $district'
                                : 'المستودع';

                            return FutureBuilder<DocumentSnapshot>(
                              future: donorId.isNotEmpty
                                  ? FirebaseFirestore.instance
                                        .collection('Users')
                                        .doc(donorId)
                                        .get()
                                  : Future.value(null),
                              builder: (context, userSnap) {
                                String name = 'صاحب الطلب';
                                String phone = '';

                                if (userSnap.hasData &&
                                    userSnap.data != null &&
                                    userSnap.data!.exists) {
                                  final uData =
                                      userSnap.data!.data()
                                          as Map<String, dynamic>? ??
                                      {};
                                  name =
                                      '${uData['firstName'] ?? ''} ${uData['lastName'] ?? ''}'
                                          .trim();
                                  phone =
                                      (uData['phone'] ??
                                              uData['phoneNumber'] ??
                                              '')
                                          .toString();
                                }

                                return FutureBuilder<QuerySnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('donation_boxes')
                                      .where('donationId', isEqualTo: doc.id)
                                      .get(),
                                  builder: (context, boxesSnap) {
                                    final boxesDocs =
                                        boxesSnap.data?.docs ?? [];
                                    final int boxesCount = boxesDocs.length;

                                    List<String> boxCodes = boxesDocs
                                        .map(
                                          (b) =>
                                              (b.data()
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)['boxCode']
                                                  ?.toString() ??
                                              'صندوق',
                                        )
                                        .toList();
                                    if (boxCodes.isEmpty) {
                                      boxCodes = ['لا توجد صناديق مضافة'];
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration:
                                          AppDesign.primaryCardDecoration,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'طلب تبرع',
                                                style: AppDesign.subtitleStyle
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppDesign.warning
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  'قيد التوصيل للمستودع',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'موقع الاستلام: $pickupLocation',
                                            style: AppDesign.bodySecondaryStyle,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'موقع التسليم: $deliveryLocation',
                                            style: AppDesign.bodySecondaryStyle,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'صاحب الطلب: $name',
                                            style: AppDesign.bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'الجوال: ${phone.isNotEmpty ? phone : 'غير متوفر'}',
                                                style: AppDesign
                                                    .bodySecondaryStyle,
                                              ),
                                              if (phone.isNotEmpty)
                                                InkWell(
                                                  onTap: () =>
                                                      _launchWhatsApp(phone),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withOpacity(0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.chat,
                                                          color: Colors.green,
                                                          size: 18,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          'واتساب',
                                                          style: TextStyle(
                                                            color: Colors.green,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'عدد الصناديق: $boxesCount',
                                            style: AppDesign.bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppDesign.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppDesign.background,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: AppDesign.border,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'الصناديق المرتبطة بالطلب:',
                                                  style: AppDesign
                                                      .bodySecondaryStyle
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                ...boxCodes.map(
                                                  (code) => Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 3,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                          size: 16,
                                                          color:
                                                              AppDesign.primary,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'رمز الصندوق: $code',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppDesign.success,
                                              ),
                                              onPressed: () =>
                                                  _completeDonationTask(
                                                    doc.id,
                                                    originalStatus,
                                                  ),
                                              child: const Text('تم التسليم'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }),

                          // 2. عرض طلبات المستفيدين النشطة
                          ...activeRequests.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final beneficiaryId =
                                data['beneficiaryId'] ??
                                data['beneficiaryID'] ??
                                '';

                            final donationId =
                                data['donationId'] ?? data['donationID'] ?? '';
                            final addressMap = data['deliveryAddress'];
                            final warehouseName = addressMap is Map
                                ? (addressMap['warehouseName'] ?? 'المستودع')
                                      .toString()
                                : 'المستودع';

                            String deliveryAddressText = 'عنوان المستفيد';
                            if (addressMap is Map) {
                              final city = addressMap['city'] ?? '';
                              final district = addressMap['district'] ?? '';

                              List<String> addressParts = [];
                              if (city.isNotEmpty) addressParts.add(city);
                              if (district.isNotEmpty) {
                                addressParts.add(district);
                              }

                              if (addressParts.isNotEmpty) {
                                deliveryAddressText = addressParts.join(' - ');
                              }
                            }

                            return FutureBuilder<DocumentSnapshot>(
                              future:
                                  beneficiaryId.isNotEmpty &&
                                      beneficiaryId != '-'
                                  ? FirebaseFirestore.instance
                                        .collection('Users')
                                        .doc(beneficiaryId)
                                        .get()
                                  : Future.value(null),
                              builder: (context, userSnap) {
                                String name = 'المستفيد';
                                String phone = '';

                                if (userSnap.hasData &&
                                    userSnap.data != null &&
                                    userSnap.data!.exists) {
                                  final uData =
                                      userSnap.data!.data()
                                          as Map<String, dynamic>? ??
                                      {};
                                  name =
                                      '${uData['firstName'] ?? ''} ${uData['lastName'] ?? ''}'
                                          .trim();
                                  phone =
                                      (uData['phone'] ??
                                              uData['phoneNumber'] ??
                                              '')
                                          .toString();
                                }

                                return FutureBuilder<QuerySnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('donation_boxes')
                                      .where('requestId', isEqualTo: doc.id)
                                      .get(),
                                  builder: (context, boxesSnap) {
                                    final boxesDocs =
                                        boxesSnap.data?.docs ?? [];
                                    final int boxesCount = boxesDocs.length;

                                    List<String> boxCodes = boxesDocs
                                        .map(
                                          (b) =>
                                              (b.data()
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)['boxCode']
                                                  ?.toString() ??
                                              'صندوق',
                                        )
                                        .toList();
                                    if (boxCodes.isEmpty) {
                                      boxCodes = ['لا توجد صناديق مضافةة'];
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration:
                                          AppDesign.primaryCardDecoration,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'طلب مستفيد',
                                                style: AppDesign.subtitleStyle
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppDesign.warning
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  'قيد التوصيل للمستفيد',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'موقع الاستلام: $warehouseName',
                                            style: AppDesign.bodySecondaryStyle,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'موقع التسليم: $deliveryAddressText',
                                            style: AppDesign.bodySecondaryStyle,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'المستفيد: $name',
                                            style: AppDesign.bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'الجوال: ${phone.isNotEmpty ? phone : 'غير متوفر'}',
                                                style: AppDesign
                                                    .bodySecondaryStyle,
                                              ),
                                              if (phone.isNotEmpty)
                                                InkWell(
                                                  onTap: () =>
                                                      _launchWhatsApp(phone),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withOpacity(0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.chat,
                                                          color: Colors.green,
                                                          size: 18,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          'واتساب',
                                                          style: TextStyle(
                                                            color: Colors.green,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'عدد الصناديق: $boxesCount',
                                            style: AppDesign.bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppDesign.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppDesign.background,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: AppDesign.border,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'الصناديق المرتبطة بالطلب:',
                                                  style: AppDesign
                                                      .bodySecondaryStyle
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                ...boxCodes.map(
                                                  (code) => Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 3,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                          size: 16,
                                                          color:
                                                              AppDesign.primary,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'رمز الصندوق: $code',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppDesign.success,
                                              ),
                                              onPressed: () =>
                                                  _completeRequestTask(doc.id),
                                              child: const Text('تم التسليم'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
