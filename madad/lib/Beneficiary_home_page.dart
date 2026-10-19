import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_design.dart';
import 'Beneficiary_more_page.dart';
import 'Beneficiary_view_donation_page.dart';
import 'Beneficiary_request_page.dart';
import 'Beneficiary_cart_page.dart';

class BeneficiaryHomePage extends StatefulWidget {
  final String userId;

  const BeneficiaryHomePage({
    super.key,
    required this.userId,
  });

  @override
  State<BeneficiaryHomePage> createState() =>
      _BeneficiaryHomePageState();
}

class _BeneficiaryHomePageState extends State<BeneficiaryHomePage> {
  int _bottomNavIndex = 0;

  String beneficiaryStatus = 'pending';
  bool _beneficiaryStatusLoaded = false;

  String selectedGender = "الكل";
  String selectedAge = "الكل";

  List<Map<String, dynamic>> boxes = [];
  bool isLoading = true;

  String firstName = "";
  String lastName = "";

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadBoxes();
    loadBeneficiaryStatus();
  }

  // ============================================================
  // USER DATA
  // ============================================================

  Future<void> loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;

        setState(() {
          firstName = (data['firstName'] ?? "").toString();
          lastName = (data['lastName'] ?? "").toString();
        });
      }
    } catch (e) {
      debugPrint("USER ERROR: $e");
    }
  }

Future<void> _openCartIfApproved() async {
  try {
    final beneficiaryQuery = await FirebaseFirestore.instance
    .collection('beneficiaries')
    .where('userId', isEqualTo: widget.userId)
    .limit(1)
    .get();

final beneficiaryDoc = beneficiaryQuery.docs.isNotEmpty
    ? beneficiaryQuery.docs.first
    : null;

    if (!mounted) return;

    final status = (beneficiaryDoc?.data()['status'] ?? 'pending')
    .toString()
    .trim()
    .toLowerCase();

if (beneficiaryDoc == null || status != 'approved') {
      final message = status == 'rejected'
          ? 'عذرًا، لم تتم الموافقة على طلبك كمستفيد.'
          : 'طلبك كمستفيد قيد المراجعة، ويمكنك استخدام السلة بعد الموافقة.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                message,
                textAlign: TextAlign.right,
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeneficiaryCartPage(
          userId: widget.userId,
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تعذر التحقق من حالة المستفيد، حاول مرة أخرى.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
Future<void> loadBeneficiaryStatus() async {
  try {
    final query = await FirebaseFirestore.instance
        .collection('beneficiaries')
        .where('userId', isEqualTo: widget.userId)
        .limit(1)
        .get();

    if (!mounted) return;

    setState(() {
      beneficiaryStatus = query.docs.isNotEmpty
          ? (query.docs.first.data()['status'] ?? 'pending')
              .toString()
              .trim()
              .toLowerCase()
          : 'pending';
      _beneficiaryStatusLoaded = true;
    });
  } catch (e) {
    debugPrint('BENEFICIARY STATUS ERROR: $e');
    if (!mounted) return;
    setState(() {
      _beneficiaryStatusLoaded = true;
    });
  }
}

  // ============================================================
  // NOTIFICATIONS
  // ============================================================
Future<void> _showNoNotifications() async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withOpacity(0.25),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (
      dialogContext,
      animation,
      secondaryAnimation,
    ) {
      return SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppDesign.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppDesign.secondary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppDesign.primary,
                        size: 28,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'الإشعارات',
                      style: AppDesign.h1Style.copyWith(
                        color: AppDesign.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'لا توجد إشعارات جديدة حاليًا',
                      textAlign: TextAlign.center,
                      style: AppDesign.bodyStyle.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.primary,
                          foregroundColor: AppDesign.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text(
                          'حسنًا',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (
      context,
      animation,
      secondaryAnimation,
      child,
    ) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.25),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
        ),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}
  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.userId)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _getUnreadNotifications(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return [];

    final unread = snapshot.docs.where((doc) {
      return doc.data()['isRead'] != true;
    }).toList();

    unread.sort((a, b) {
      final aTime = a.data()['createdAt'] as Timestamp?;
      final bTime = b.data()['createdAt'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return unread;
  }

  Future<void> _markNotificationAsRead(
    String notificationId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("NOTIFICATION READ ERROR: $e");
    }
  }

  Future<void> _showNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> notification,
  ) async {
    final data = notification.data();

    final type = (data['type'] ?? '').toString();

    final title =
        (data['title'] ?? 'إشعار جديد').toString();

    final message =
        (data['message'] ?? '').toString();

    final rejectionReason =
        (data['rejectionReason'] ?? '').toString().trim();

    final bool isApproved =
        type == 'beneficiary_approved';

    final bool isRejected =
        type == 'beneficiary_rejected';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (
        dialogContext,
        animation,
        secondaryAnimation,
      ) {
        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    0,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppDesign.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? Colors.green.withOpacity(0.10)
                                  : isRejected
                                      ? Colors.red.withOpacity(0.08)
                                      : AppDesign.secondary
                                          .withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isApproved
                                  ? Icons.check_rounded
                                  : isRejected
                                      ? Icons.close_rounded
                                      : Icons
                                          .notifications_none_rounded,
                              color: isApproved
                                  ? Colors.green.shade700
                                  : isRejected
                                      ? Colors.red.shade700
                                      : AppDesign.primary,
                              size: 26,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إشعار جديد',
                                  style:
                                      AppDesign.bodyStyle.copyWith(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  style:
                                      AppDesign.h1Style.copyWith(
                                    color: AppDesign.primary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isApproved
                                ? Colors.green.withOpacity(0.06)
                                : isRejected
                                    ? Colors.red.withOpacity(0.05)
                                    : AppDesign.background,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Text(
                            message,
                            style:
                                AppDesign.bodyStyle.copyWith(
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],

                      if (isRejected &&
                          rejectionReason.isNotEmpty) ...[
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppDesign.background,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سبب الرفض',
                                style:
                                    AppDesign.bodyStyle.copyWith(
                                  color: AppDesign.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                rejectionReason,
                                style: AppDesign.bodyStyle,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppDesign.primary,
                            foregroundColor:
                                AppDesign.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            await _markNotificationAsRead(
                              notification.id,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text(
                            'حسنًا',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
      ) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.25),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  // ============================================================
  // DONATION BOXES
  // ============================================================

  Future<void> loadBoxes() async {
    List<Map<String, dynamic>> allBoxes = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .where('status', isEqualTo: 'available')
          .get();

      for (var doc in snapshot.docs) {
        final d = doc.data();

        List<String> imagesList = [];

        final items = d['items'];

        if (items is List) {
          for (var item in items) {
            if (item is Map &&
                item['imageUrl'] != null) {
              final imageUrl =
                  item['imageUrl'].toString().trim();

              if (imageUrl.isNotEmpty) {
                imagesList.add(imageUrl);
              }
            }
          }
        }

        String ageLabel = 'الكل';

        final ageGroup = d['ageGroup'];

        if (ageGroup is Map) {
          ageLabel =
              (ageGroup['label'] ?? 'الكل').toString();
        } else if (ageGroup != null) {
          ageLabel = ageGroup.toString();
        }

        allBoxes.add({
          "boxId": doc.id,
          "donationId": d['donationId'] ?? "",
          "gender": (d['gender'] ?? 'الكل').toString(),
          "age": ageLabel,
          "images": imagesList,
        });
      }

      if (!mounted) return;

      setState(() {
        boxes = allBoxes;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("BOXES ERROR: $e");

      if (!mounted) return;

      setState(() {
        boxes = [];
        isLoading = false;
      });
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  String normalize(String text) {
    return text.replaceAll(" ", "").trim();
  }

  List<Map<String, dynamic>> get filteredBoxes {
    return boxes.where((box) {
      final gender =
          (box["gender"] ?? "الكل").toString();

      final age =
          (box["age"] ?? "الكل").toString();

      final genderOk =
          selectedGender == "الكل" ||
              normalize(gender) ==
                  normalize(selectedGender);

      final ageOk =
          selectedAge == "الكل" ||
              normalize(age) ==
                  normalize(selectedAge);

      return genderOk && ageOk;
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filtered = filteredBoxes;

    return Scaffold(
      backgroundColor: AppDesign.background,

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          14,
        ),
        decoration: BoxDecoration(
          color: AppDesign.white,
          borderRadius:
              BorderRadius.circular(AppDesign.radiusXL),
          boxShadow: [
            BoxShadow(
              color: AppDesign.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: !_beneficiaryStatusLoaded
            ? const SizedBox(
                height: 78,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            : Directionality(
          textDirection: TextDirection.rtl,
          child: NavigationBar(
            height: 78,
            selectedIndex: _bottomNavIndex,
            backgroundColor: Colors.transparent,
            indicatorColor:
                AppDesign.secondary.withOpacity(0.16),
            surfaceTintColor: Colors.transparent,
            labelBehavior:
                NavigationDestinationLabelBehavior
                    .alwaysShow,
            onDestinationSelected: (index) {
  final isApproved = beneficiaryStatus == 'approved';

  if (index == 0) {
    setState(() => _bottomNavIndex = 0);
    return;
  }

  // إذا لم يكن المستفيد موافقًا عليه:
  // الفهرس 1 يعني صفحة المزيد
  if (!isApproved && index == 1) {
    setState(() => _bottomNavIndex = 1);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BeneficiaryMorePage(
          userId: widget.userId,
        ),
      ),
    );
    return;
  }

  // إذا كان المستفيد موافقًا عليه:
  if (isApproved && index == 1) {
    setState(() => _bottomNavIndex = 1);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BeneficiaryOrdersPage(
          userId: widget.userId,
        ),
      ),
    );
    return;
  }

  // المزيد للمستفيد الموافق عليه، عند الفهرس 2
  if (isApproved && index == 2) {
    setState(() => _bottomNavIndex = 2);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BeneficiaryMorePage(
          userId: widget.userId,
        ),
      ),
    );
  }
},
            destinations: [
  const NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: 'الرئيسية',
  ),

  if (beneficiaryStatus == 'approved')
    const NavigationDestination(
      icon: Icon(Icons.volunteer_activism_outlined),
      selectedIcon: Icon(Icons.volunteer_activism_rounded),
      label: 'طلباتي',
    ),

  const NavigationDestination(
    icon: Icon(Icons.more_horiz),
    selectedIcon: Icon(Icons.more_horiz),
    label: 'المزيد',
  ),
],
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    // ==========================================
                    // USER
                    // ==========================================

                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppDesign.primary,
                      child: Text(
                        firstName.isNotEmpty
                            ? firstName[0]
                            : 'م',
                        style: const TextStyle(
                          color: AppDesign.white,
                          fontWeight:
                              FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),

                    AppGap.wMD,

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحبًا',
                            style:
                                AppDesign.bodyStyle.copyWith(
                              color: AppDesign.primary,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$firstName $lastName",
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                AppDesign.h1Style.copyWith(
                              color: AppDesign.primary,
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // ==========================================
                    // NOTIFICATIONS
                    // ==========================================

                    StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream: _notificationsStream(),
                      builder: (
                        context,
                        notificationSnapshot,
                      ) {
                        final unread =
                            _getUnreadNotifications(
                          notificationSnapshot.data,
                        );

                        final unreadCount =
                            unread.length;

                        final latestNotification =
                            unread.isNotEmpty
                                ? unread.first
                                : null;

                        return IconButton(
                          tooltip: 'الإشعارات',
                         onPressed: () {
  if (latestNotification == null) {
    _showNoNotifications();
  } else {
    _showNotification(latestNotification);
  }
},
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons
                                    .notifications_none_rounded,
                                color:
                                    AppDesign.primary,
                                size: 28,
                              ),

                              if (unreadCount > 0)
                                Positioned(
                                  top: -8,
                                  right: -8,
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    alignment:
                                        Alignment.center,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          const Color(
                                        0xFFD84A4A,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                      border:
                                          Border.all(
                                        color:
                                            AppDesign
                                                .background,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      unreadCount > 9
                                          ? '9+'
                                          : unreadCount
                                              .toString(),
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // ==========================================
                    // CART
                    // ==========================================

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore
                          .instance
                          .collection('cart')
                          .where(
                            'beneficiaryId',
                            isEqualTo:
                                widget.userId,
                          )
                          .where(
                            'status',
                            isEqualTo: 'in_cart',
                          )
                          .snapshots(),
                      builder: (
                        context,
                        cartSnapshot,
                      ) {
                        if (!cartSnapshot.hasData) {
                          return IconButton(
                            icon: Icon(
                              Icons
                                  .shopping_cart_outlined,
                              color:
                                  Colors.grey.shade700,
                              size: 28,
                            ),
                            onPressed: _openCartIfApproved,
                          );
                        }

                        final cartDocs =
                            cartSnapshot.data!.docs;

                        return FutureBuilder<int>(
                          future:
                              _countAvailableCartItems(
                            cartDocs,
                          ),
                          builder: (
                            context,
                            countSnapshot,
                          ) {
                            final count =
                                countSnapshot.data ??
                                    0;

                            return IconButton(
                              onPressed: _openCartIfApproved,
                              icon: Stack(
                                clipBehavior:
                                    Clip.none,
                                children: [
                                  Icon(
                                    Icons
                                        .shopping_cart_outlined,
                                    color: Colors
                                        .grey.shade700,
                                    size: 28,
                                  ),

                                  if (count > 0)
                                    Positioned(
                                      top: -7,
                                      right: -7,
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        alignment:
                                            Alignment
                                                .center,
                                        decoration:
                                            BoxDecoration(
                                          color:
                                              AppDesign
                                                  .primary,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            20,
                                          ),
                                          border:
                                              Border.all(
                                            color:
                                                AppDesign
                                                    .background,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          count > 9
                                              ? '9+'
                                              : count
                                                  .toString(),
                                          style:
                                              const TextStyle(
                                            color:
                                                Colors.white,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // BANNER
            // ==================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      AppDesign.primary,
                      AppDesign.primary
                          .withOpacity(0.8),
                    ],
                  ),
                ),
                child: const Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "مع مَدَد يمكنك الحصول على التبرعات المناسبة ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "تصفح القطع واختر ما يناسبك بسهولة وسرعة",
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // FILTER TITLE
            // ==================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "تصفية التبرعات",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ==================================================
            // FILTERS
            // ==================================================

            _buildFilters(),

            const SizedBox(height: 10),

            // ==================================================
            // BOXES
            // ==================================================

            Expanded(
              child: isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            "لا توجد تبرعات",
                          ),
                        )
                      : Directionality(
                          textDirection:
                              TextDirection.rtl,
                          child: GridView.builder(
                            padding:
                                const EdgeInsets.all(
                              10,
                            ),
                            itemCount:
                                filtered.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio:
                                  0.75,
                            ),
                            itemBuilder: (
                              context,
                              index,
                            ) {
                              final box =
                                  filtered[index];

                              return Align(
                                alignment:
                                    Alignment.topRight,
                                child:
                                    ClothesBoxCard(
                                  images:
                                      box["images"],
                                  gender:
                                      box["gender"],
                                  age: box["age"],
                                  userId:
                                      widget.userId,
                                  boxId:
                                      box["boxId"],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    List<String> genders = [
      "الكل",
      "ذكر",
      "أنثى",
    ];

    List<String> ages = [
      "الكل",
      "رضّع (0-2)",
      "أطفال صغار (3-5)",
      "أطفال (6-9)",
      "أطفال (10-15)",
      "بالغون",
    ];

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: _filterCard(
              title: "التصنيف",
              value: selectedGender,
              icon: Icons.person,
              items: genders,
              onSelected: (value) {
                setState(
                  () => selectedGender = value,
                );
              },
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: _filterCard(
              title: "الفئة العمرية",
              value: selectedAge,
              icon: Icons.cake,
              items: ages,
              onSelected: (value) {
                setState(
                  () => selectedAge = value,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FILTER CARD
// ================================================================

Widget _filterCard({
  required String title,
  required String value,
  required IconData icon,
  required List<String> items,
  required Function(String) onSelected,
}) {
  return PopupMenuButton<String>(
    onSelected: onSelected,
    itemBuilder: (context) => items
        .map(
          (e) => PopupMenuItem(
            value: e,
            child: Text(e),
          ),
        )
        .toList(),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.end,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                size: 18,
                color: AppDesign.primary,
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    ),
  );
}

// ================================================================
// CART COUNT
// ================================================================

Future<int> _countAvailableCartItems(
  List<QueryDocumentSnapshot> cartDocs,
) async {
  int count = 0;

  for (final cartDoc in cartDocs) {
    try {
      final cartData =
          cartDoc.data() as Map<String, dynamic>;

      final boxId =
          cartData['boxId']?.toString();

      if (boxId == null || boxId.isEmpty) {
        continue;
      }

      final boxDoc =
          await FirebaseFirestore.instance
              .collection('donation_boxes')
              .doc(boxId)
              .get();

      if (!boxDoc.exists) continue;

      final boxData = boxDoc.data()!;

      final boxStatus =
          boxData['status']?.toString();

      if (boxStatus == 'available') {
        count++;
      }
    } catch (e) {
      debugPrint(
        "CART COUNT ERROR: $e",
      );
    }
  }

  return count;
}

// ================================================================
// CLOTHES BOX CARD
// ================================================================

class ClothesBoxCard extends StatelessWidget {
  final List images;
  final String gender;
  final String age;
  final String userId;
  final String boxId;

  const ClothesBoxCard({
    super.key,
    required this.images,
    required this.gender,
    required this.age,
    required this.userId,
    required this.boxId,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Expanded(
                child: images.isEmpty
                    ? Container(
                        width: double.infinity,
                        color: AppDesign.background,
                        child: const Center(
                          child: Icon(
                            Icons
                                .checkroom_outlined,
                            size: 42,
                            color:
                                AppDesign.secondary,
                          ),
                        ),
                      )
                    : PageView.builder(
                        itemCount: images.length,
                        itemBuilder: (
                          context,
                          i,
                        ) {
                          final imageUrl =
                              images[i]
                                  .toString()
                                  .trim();

                          if (imageUrl.isEmpty) {
                            return Container(
                              color: AppDesign
                                  .background,
                              child:
                                  const Center(
                                child: Icon(
                                  Icons
                                      .broken_image_outlined,
                                  size: 40,
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            );
                          }

                          return Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width:
                                double.infinity,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Container(
                                color: AppDesign
                                    .background,
                                child:
                                    const Center(
                                  child: Icon(
                                    Icons
                                        .broken_image_outlined,
                                    size: 40,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      age,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    ElevatedButton(
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            AppDesign.primary,
                        foregroundColor:
                            Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BeneficiaryViewDonationPage(
                              boxId: boxId,
                              userId: userId,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "عرض التفاصيل",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.9),
              borderRadius:
                  BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              gender == "أنثى"
                  ? Icons.woman_2
                  : gender == "ذكر"
                      ? Icons.man
                      : Icons.person,
              size: 22,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
