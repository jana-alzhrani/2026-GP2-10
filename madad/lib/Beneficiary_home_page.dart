import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'app_design.dart';
import 'Beneficiary_more_page.dart';
import 'Beneficiary_view_item_page.dart';
import 'Beneficiary_request_page.dart';
import 'Beneficiary_cart_page.dart';
import 'order_limits_service.dart';

class BeneficiaryHomePage extends StatefulWidget {
  final String userId;

  const BeneficiaryHomePage({super.key, required this.userId});

  @override
  State<BeneficiaryHomePage> createState() => _BeneficiaryHomePageState();
}

class _BeneficiaryHomePageState extends State<BeneficiaryHomePage> {
  int _bottomNavIndex = 0;

  String beneficiaryStatus = 'pending';
  bool _beneficiaryStatusLoaded = false;
  late Stream<OrderLimits> _limitsStream;
  String selectedGender = "الكل";
  String selectedAge = "الكل";

  List<Map<String, dynamic>> boxes = [];
  bool isLoading = true;
  final Map<String, Map<String, dynamic>> _boxCache = {};
  String firstName = "";
  String lastName = "";

  // ---- Cart badge state ----
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSub;
  int _cartCount = 0;
  int _cartCountSeq = 0; // ignores stale results that finish out of order

  // ---- Beneficiary status (live) ----
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statusSub;

  @override
  void initState() {
    super.initState();

    _limitsStream = OrderLimitsService.watch(widget.userId);

    loadUserData();
    _loadItems();
    _listenToCart();
    _listenToBeneficiaryStatus();
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
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
      String status = beneficiaryStatus;

      // نستخدم الحالة المحمّلة مسبقًا، ونستعلم فقط إذا لم يكتمل التحميل بعد
      if (!_beneficiaryStatusLoaded) {
        final query = await FirebaseFirestore.instance
            .collection('beneficiaries')
            .where('userId', isEqualTo: widget.userId)
            .limit(1)
            .get();

        status = query.docs.isNotEmpty
            ? (query.docs.first.data()['status'] ?? 'pending')
                  .toString()
                  .trim()
                  .toLowerCase()
            : 'pending';
      }

      if (!mounted) return;

      if (status != 'approved') {
        final message = status == 'rejected'
            ? 'عذرًا، لم تتم الموافقة على طلبك كمستفيد.'
            : 'طلبك كمستفيد قيد المراجعة، ويمكنك استخدام السلة بعد الموافقة.';

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(message, textAlign: TextAlign.right),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );

        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BeneficiaryCartPage(userId: widget.userId),
        ),
      );

      // Back from the cart: reload the donation items.
      if (!mounted) return;
      await _onRefresh();
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

  void _listenToBeneficiaryStatus() {
    _statusSub = FirebaseFirestore.instance
        .collection('beneficiaries')
        .where('userId', isEqualTo: widget.userId)
        .limit(1)
        .snapshots()
        .listen(
          (query) {
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
          },
          onError: (e) {
            debugPrint('BENEFICIARY STATUS ERROR: $e');
            if (!mounted) return;
            setState(() => _beneficiaryStatusLoaded = true);
          },
        );
  }

  // ============================================================
  // CART
  // ============================================================

  void _listenToCart() {
    _cartSub = FirebaseFirestore.instance
        .collection('cart')
        .where('beneficiaryId', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'in_cart')
        .snapshots()
        .listen((snapshot) async {
          final seq = ++_cartCountSeq;
          final count = await _countAvailableCartItems(snapshot.docs);
          if (!mounted || seq != _cartCountSeq) return;
          setState(() => _cartCount = count);
        }, onError: (e) => debugPrint('CART STREAM ERROR: $e'));
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
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
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
                            style: TextStyle(fontWeight: FontWeight.w700),
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
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.25),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Widget _buildHomeQuotaCard(OrderLimits limits) {
    final maxItems = limits.maxItemsPerPeriod;
    final remaining = limits.itemsRemaining;

    // Percentage of the quota already used.
    final used = (maxItems - remaining).clamp(0, maxItems);
    final progress = maxItems == 0 ? 0.0 : used / maxItems;

    final days = limits.daysUntilReset;

    final Color barColor = progress >= 0.8
        ? Colors.red.shade600
        : progress >= 0.5
        ? Colors.orange.shade700
        : AppDesign.primary;

    final String resetText = days == null
        ? 'تبدأ الفترة مع أول طلب'
        : days == 0
        ? 'تتجدد اليوم'
        : 'تتجدد بعد $days يومًا';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        border: Border.all(color: AppDesign.border),
        boxShadow: [
          BoxShadow(
            color: AppDesign.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppDesign.primary,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حصتك من التبرعات',
                    style: AppDesign.bodyStyle.copyWith(
                      color: AppDesign.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$remaining / $maxItems قطعة',
                  style: AppDesign.bodyStyle.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 16,
                  color: AppDesign.primary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'استخدمت $used من $maxItems قطعة',
                    style: AppDesign.bodySecondaryStyle.copyWith(
                      fontSize: 12,
                      color: AppDesign.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.event_repeat_rounded,
                  size: 16,
                  color: AppDesign.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  resetText,
                  style: AppDesign.bodySecondaryStyle.copyWith(
                    fontSize: 12,
                    color: AppDesign.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.userId)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getUnreadNotifications(
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

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint("NOTIFICATION READ ERROR: $e");
    }
  }

  Future<void> _showNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> notification,
  ) async {
    final data = notification.data();

    final type = (data['type'] ?? '').toString();

    final title = (data['title'] ?? 'إشعار جديد').toString();

    final message = (data['message'] ?? '').toString();

    final rejectionReason = (data['rejectionReason'] ?? '').toString().trim();

    final bool isApproved = type == 'beneficiary_approved';

    final bool isRejected = type == 'beneficiary_rejected';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  : AppDesign.secondary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isApproved
                                  ? Icons.check_rounded
                                  : isRejected
                                  ? Icons.close_rounded
                                  : Icons.notifications_none_rounded,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إشعار جديد',
                                  style: AppDesign.bodyStyle.copyWith(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  style: AppDesign.h1Style.copyWith(
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            message,
                            style: AppDesign.bodyStyle.copyWith(height: 1.6),
                          ),
                        ),
                      ],

                      if (isRejected && rejectionReason.isNotEmpty) ...[
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppDesign.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سبب الرفض',
                                style: AppDesign.bodyStyle.copyWith(
                                  color: AppDesign.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(rejectionReason, style: AppDesign.bodyStyle),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      SizedBox(
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
                          onPressed: () async {
                            await _markNotificationAsRead(notification.id);

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text(
                            'حسنًا',
                            style: TextStyle(fontWeight: FontWeight.w700),
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
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.25),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  // ============================================================
  // DONATION BOXES
  // ============================================================

  // ============================================================
  // DONATION BOXES (loaded once, refreshed by pull-down)
  // ============================================================

  Future<void> _loadItems() async {
    try {
      final db = FirebaseFirestore.instance;

      final snapshot = await db
          .collection('items')
          .where('status', isEqualTo: 'available')
          .get();

      // نجيب فقط الصناديق اللي ما عندنا لها نسخة محفوظة
      final newBoxIds = snapshot.docs
          .map((d) => (d.data()['boxId'] ?? '').toString())
          .where((id) => id.isNotEmpty && !_boxCache.containsKey(id))
          .toSet();

      await Future.wait(
        newBoxIds.map((id) async {
          try {
            final snap = await db.collection('donation_boxes').doc(id).get();
            if (snap.exists && snap.data() != null) {
              _boxCache[id] = snap.data()!;
            }
          } catch (e) {
            debugPrint('BOX FETCH ERROR ($id): $e');
          }
        }),
      );

      final List<Map<String, dynamic>> allItems = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final boxId = (data['boxId'] ?? '').toString();
        final box = _boxCache[boxId];

        final gender = ((box?['gender'] ?? data['gender']) ?? 'الكل')
            .toString();

        final rawAgeGroup = box?['ageGroup'] ?? data['ageGroup'];
        String ageLabel = 'الكل';
        if (rawAgeGroup is Map) {
          ageLabel = (rawAgeGroup['label'] ?? 'الكل').toString();
        } else if (rawAgeGroup != null) {
          ageLabel = rawAgeGroup.toString();
        }

        String size = (data['size'] ?? '').toString().trim();
        if (size.isEmpty || size == 'null') {
          size = (box?['generalSize'] ?? '').toString().trim();
          if (size == 'null') size = '';
        }

        final imageUrl = (data['imageUrl'] ?? '').toString().trim();

        allItems.add({
          'itemId': doc.id,
          'boxId': boxId,
          'donationId': (data['donationId'] ?? '').toString(),
          'gender': gender,
          'age': ageLabel,
          'type': (data['type'] ?? 'قطعة ملابس').toString(),
          'size': size,
          'description': (data['description'] ?? '').toString(),
          'images': imageUrl.isNotEmpty ? [imageUrl] : <String>[],
        });
      }

      if (!mounted) return;
      setState(() {
        boxes = allItems;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('ITEMS ERROR: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  /// Pull-to-refresh: reloads the items (and the box data) from Firestore.
  Future<void> _onRefresh() async {
    _boxCache.clear();

    // The quota is already listening to Firestore in real time.
    // Pull-to-refresh only needs to reload the donation items.
    await _loadItems();
  }

  // ============================================================
  // FILTER
  // ============================================================

  String normalize(String text) {
    return text.replaceAll(" ", "").trim();
  }

  List<Map<String, dynamic>> get filteredBoxes {
    return boxes.where((box) {
      final gender = (box["gender"] ?? "الكل").toString();

      final age = (box["age"] ?? "الكل").toString();

      final genderOk =
          selectedGender == "الكل" ||
          normalize(gender) == normalize(selectedGender);

      final ageOk =
          selectedAge == "الكل" || normalize(age) == normalize(selectedAge);

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
        child: !_beneficiaryStatusLoaded
            ? const SizedBox(
                height: 78,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Directionality(
                textDirection: TextDirection.rtl,
                child: NavigationBar(
                  height: 78,
                  selectedIndex: _bottomNavIndex,
                  backgroundColor: Colors.transparent,
                  indicatorColor: AppDesign.secondary.withOpacity(0.16),
                  surfaceTintColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                          builder: (_) =>
                              BeneficiaryMorePage(userId: widget.userId),
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
                          builder: (_) =>
                              BeneficiaryOrdersPage(userId: widget.userId),
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
                          builder: (_) =>
                              BeneficiaryMorePage(userId: widget.userId),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    // ==========================================
                    // USER
                    // ==========================================
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppDesign.primary,
                      child: Text(
                        firstName.isNotEmpty ? firstName[0] : 'م',
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
                            "$firstName $lastName",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppDesign.h1Style.copyWith(
                              color: AppDesign.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // ==========================================
                    // NOTIFICATIONS
                    // ==========================================
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _notificationsStream(),
                      builder: (context, notificationSnapshot) {
                        final unread = _getUnreadNotifications(
                          notificationSnapshot.data,
                        );

                        final unreadCount = unread.length;

                        final latestNotification = unread.isNotEmpty
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
                                Icons.notifications_none_rounded,
                                color: AppDesign.primary,
                                size: 28,
                              ),

                              if (unreadCount > 0)
                                Positioned(
                                  top: -8,
                                  right: -8,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD84A4A),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppDesign.background,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      unreadCount > 9
                                          ? '9+'
                                          : unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                    IconButton(
                      onPressed: _openCartIfApproved,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.grey.shade700,
                            size: 28,
                          ),

                          if (_cartCount > 0)
                            Positioned(
                              top: -7,
                              right: -7,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppDesign.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppDesign.background,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  _cartCount > 9 ? '9+' : _cartCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // BANNER
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      AppDesign.primary,
                      AppDesign.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: const Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "مع مَدَد يمكنك الحصول على التبرعات المناسبة ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "تصفح القطع واختر ما يناسبك بسهولة وسرعة",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // BENEFICIARY QUOTA PROGRESS
            // ==================================================
            if (beneficiaryStatus == 'approved')
              StreamBuilder<OrderLimits>(
                stream: _limitsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(10),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  return _buildHomeQuotaCard(snapshot.data!);
                },
              ),

            const SizedBox(height: 12),

            // ==================================================
            // FILTER TITLE
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: AppDesign.primary,
                      onRefresh: _onRefresh,
                      child: filtered.isEmpty
                          // Scrollable so pull-down works on the empty state too
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text("لا توجد تبرعات")),
                              ],
                            )
                          : Directionality(
                              textDirection: TextDirection.rtl,
                              child: GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(10),
                                itemCount: filtered.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.75,
                                    ),
                                itemBuilder: (context, index) {
                                  final box = filtered[index];

                                  return Align(
                                    alignment: Alignment.topRight,
                                    child: ClothesBoxCard(
                                      images: box["images"] as List,
                                      gender: box["gender"].toString(),
                                      age: box["age"].toString(),
                                      type: box["type"].toString(),
                                      size: box["size"].toString(),
                                      userId: widget.userId,
                                      itemId: box["itemId"].toString(),
                                      boxId: box["boxId"].toString(),
                                      onReturn: _onRefresh,
                                    ),
                                  );
                                },
                              ),
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
    List<String> genders = ["الكل", "ذكر", "أنثى"];

    List<String> ages = [
      "الكل",
      "رضّع (0-2)",
      "أطفال صغار (3-5)",
      "أطفال (6-9)",
      "أطفال (10-15)",
      "بالغون",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: _filterCard(
              title: "التصنيف",
              value: selectedGender,
              icon: Icons.person,
              items: genders,
              onSelected: (value) {
                setState(() => selectedGender = value);
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
                setState(() => selectedAge = value);
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
    itemBuilder: (context) =>
        items.map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: AppDesign.primary),
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
      final cartData = cartDoc.data() as Map<String, dynamic>;

      final itemId = cartData['itemId']?.toString();

      if (itemId == null || itemId.isEmpty) {
        // التوافق مع عناصر السلة القديمة التي كانت تستخدم boxId.
        final boxId = cartData['boxId']?.toString();
        if (boxId == null || boxId.isEmpty) continue;
        final oldBox = await FirebaseFirestore.instance
            .collection('donation_boxes')
            .doc(boxId)
            .get();
        if (oldBox.exists && oldBox.data()?['status'] == 'available') {
          count++;
        }
        continue;
      }

      final itemDoc = await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .get();

      if (itemDoc.exists && itemDoc.data()?['status'] == 'available') {
        count++;
      }
    } catch (e) {
      debugPrint("CART COUNT ERROR: $e");
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
  final String itemId;
  final String boxId;
  final String type;
  final String size;
  final Future<void> Function()? onReturn;

  const ClothesBoxCard({
    super.key,
    required this.images,
    required this.gender,
    required this.age,
    required this.userId,
    required this.itemId,
    required this.boxId,
    required this.type,
    required this.size,
    this.onReturn,
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
            borderRadius: BorderRadius.circular(20),
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
                            Icons.checkroom_outlined,
                            size: 42,
                            color: AppDesign.secondary,
                          ),
                        ),
                      )
                    : PageView.builder(
                        itemCount: images.length,
                        itemBuilder: (context, i) {
                          final imageUrl = images[i].toString().trim();

                          if (imageUrl.isEmpty) {
                            return Container(
                              color: AppDesign.background,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          return Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppDesign.background,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),

              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (size.trim().isNotEmpty)
                      Text(
                        'المقاس: $size',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      age,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 6),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesign.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BeneficiaryViewItemPage(
                              itemId: itemId,
                              boxId: boxId,
                              userId: userId,
                            ),
                          ),
                        );
                        await onReturn?.call();
                      },
                      child: const Text("عرض التفاصيل"),
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
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
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
