import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';
import 'Beneficiary_more_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'request_items_helper.dart';

/// ─────────────── إعدادات قاعدة البيانات ───────────────
const String kRequestsCollection = 'requests';
const String kBoxesCollection = 'donation_boxes';

/// الحقل الذي يربط الطلب بالمستفيد
const String kBeneficiaryIdField = 'beneficiaryId';

/// الحقل داخل donation_boxes الذي يربط الصندوق بالطلب (عدّله حسب قاعدتك)
const String kBoxRequestIdField = 'requestId';

/// حالات الطلبات التي تظهر في تبويب "الطلبات النشطة"
const List<String> kActiveStatuses = ['requested', 'reserved', 'delivered'];

/// الحالة المكتملة (تُستخدم في كل الملف)
const String kCompletedStatus = 'completed';

/// حالات الطلبات التي تظهر في تبويب "الطلبات السابقة"
const List<String> kPreviousStatuses = [kCompletedStatus];

const Map<String, String> kStatusLabels = {
  'requested': 'تم الطلب',
  'reserved': 'تم الحجز',
  'delivered': 'جاري التوصيل',
  'completed': 'تم الاستلام',
};

String _statusLabel(String s, {String method = ''}) => kStatusLabels[s] ?? s;

String _deliveryLabel(String m) {
  switch (m) {
    case 'pickup':
      return 'استلام من المستودع';
    case 'delivery':
      return 'توصيل للموقع';
    default:
      return m.isEmpty ? 'استلام من المستودع' : m;
  }
}

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}/${two(l.month)}/${two(l.day)}  ${two(l.hour)}:${two(l.minute)}';
}

/// ═══════════════════════════ الصفحة ═══════════════════════════
class BeneficiaryOrdersPage extends StatefulWidget {
  final String userId;

  const BeneficiaryOrdersPage({super.key, required this.userId});

  @override
  State<BeneficiaryOrdersPage> createState() => _BeneficiaryOrdersPageState();
}

class _BeneficiaryOrdersPageState extends State<BeneficiaryOrdersPage> {
  int _bottomNavIndex = 1;
  bool _accessChecked = false;
  bool _isApproved = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statusSub;

  @override
  void initState() {
    super.initState();
    _listenToBeneficiaryStatus();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  void _listenToBeneficiaryStatus() {
    _statusSub = FirebaseFirestore.instance
        .collection('beneficiaries')
        .where('userId', isEqualTo: widget.userId)
        .limit(1)
        .snapshots()
        .listen(
          (result) {
            final status = result.docs.isNotEmpty
                ? (result.docs.first.data()['status'] ?? 'pending')
                      .toString()
                      .trim()
                      .toLowerCase()
                : 'pending';

            if (!mounted) return;
            setState(() {
              _isApproved = status == 'approved';
              _accessChecked = true;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _isApproved = false;
              _accessChecked = true;
            });
          },
        );
  }

  /// 0 = الطلبات النشطة
  /// 1 = الطلبات السابقة
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        bottomNavigationBar: _buildBottomNav(),
        body: SafeArea(
          child: !_accessChecked
              ? const Center(child: CircularProgressIndicator())
              : !_isApproved
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'عذراً ، ستتمكن فقط من متابعة طلباتك بعد الموافقة على طلبك كمستفيد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppDesign.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    _buildTabs(),
                    Expanded(child: _buildRequestsList()),
                  ],
                ),
        ),
      ),
    );
  }

  // ───────────────────────── الهيدر ─────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Text(
            "طلباتي",
            style: TextStyle(
              color: AppDesign.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "تابع حالة طلباتك النشطة والسابقة",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── التبويبات ─────────────────────────
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            _tabItem("الطلبات النشطة", 0),
            _tabItem("الطلبات السابقة", 1),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String label, int index) {
    final selected = _tabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppDesign.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppDesign.primary,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── قائمة الطلبات ─────────────────────────
  Widget _buildRequestsList() {
    final isActiveTab = _tabIndex == 0;

    /// جلب الطلبات الخاصة بالمستفيد الحالي من كولكشن requests
    final Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection(kRequestsCollection)
        .where(kBeneficiaryIdField, isEqualTo: widget.userId)
        .where(
          'status',
          whereIn: isActiveTab ? kActiveStatuses : kPreviousStatuses,
        );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("حدث خطأ أثناء تحميل الطلبات"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...?snapshot.data?.docs];

        // ترتيب الأحدث أولاً
        docs.sort((a, b) {
          final da = _toDate(a.data()['createdAt']);
          final db = _toDate(b.data()['createdAt']);

          if (da != null && db != null) {
            return db.compareTo(da);
          }
          return 0;
        });

        // لا توجد طلبات
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volunteer_activism_outlined,
                  size: 56,
                  color: AppDesign.primary.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  isActiveTab
                      ? "لا توجد طلبات نشطة حالياً"
                      : "لا توجد طلبات سابقة",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppDesign.primary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = docs[index];

            return OrderCard(
              key: ValueKey('${_tabIndex}_${doc.id}'),
              requestId: doc.id,
              data: doc.data(),
            );
          },
        );
      },
    );
  }

  // ───────────────────────── البوتوم ناف ─────────────────────────
  Widget _buildBottomNav() {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'الرئيسية',
      ),
      if (_isApproved)
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
    ];
    final selectedIndex = _isApproved ? _bottomNavIndex : 1;

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
            Navigator.pushReplacementNamed(
              context,
              '/beneficiaryHome',
              arguments: widget.userId,
            );
          } else if (_isApproved && index == 1) {
            return;
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BeneficiaryMorePage(userId: widget.userId),
              ),
            );
          }
        },
        destinations: destinations,
      ),
    );
  }
}

/// ═══════════════════════════ كارد الطلب ═══════════════════════════
class OrderCard extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const OrderCard({super.key, required this.requestId, required this.data});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  /// نُنشئ الـ Future مرة واحدة بدل إنشائه في كل build
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = fetchRequestItems(widget.requestId);
  }

  @override
  void didUpdateWidget(covariant OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // نعيد الجلب فقط عند تغيّر الطلب أو حالته (مثلاً بعد مسح الباركود)
    if (oldWidget.requestId != widget.requestId ||
        oldWidget.data['status'] != widget.data['status']) {
      _itemsFuture = fetchRequestItems(widget.requestId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = widget.requestId;
    final data = widget.data;

    final status = (data['status'] ?? '').toString();
    final method = (data['deliveryMethod'] ?? '').toString();
    final createdAt = _toDate(data['createdAt']);

    final addr = data['deliveryAddress'];
    final warehouseName = addr is Map
        ? (addr['warehouseName'] ?? '').toString()
        : '';
    final city = addr is Map ? (addr['city'] ?? '').toString() : '';
    final district = addr is Map ? (addr['district'] ?? '').toString() : '';

    final shortId = requestId.length < 6
        ? requestId
        : requestId.substring(0, 6);

    // زر المسح يظهر فقط للاستلام من المستودع وقبل اكتمال الطلب
    final canScan = method == 'pickup' && status != kCompletedStatus;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── العنوان + الحالة + الأيقونة ───
          Row(
            children: [
              Expanded(
                child: Text(
                  'طلب #$shortId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppDesign.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(label: _statusLabel(status, method: method)),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppDesign.secondary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  size: 20,
                  color: AppDesign.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ─── معلومات الطلب ───
          _InfoBox(
            children: [
              if (createdAt != null)
                _InfoRow(
                  icon: Icons.event_outlined,
                  label: 'تاريخ الطلب',
                  value: _fmtDate(createdAt),
                ),
              _InfoRow(
                icon: Icons.local_shipping_outlined,
                label: 'طريقة التوصيل',
                value: _deliveryLabel(method),
                trailing: canScan
                    ? Tooltip(
                        message: 'مسح الباركود لتأكيد الاستلام',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PickupScanPage(requestId: requestId),
                              ),
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppDesign.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              if (warehouseName.isNotEmpty)
                _InfoRow(
                  icon: Icons.warehouse_outlined,
                  label: 'المستودع',
                  value: warehouseName,
                ),

              // المدينة والحي: يظهران فقط إذا الطلب توصيل
              if (method == 'delivery' && city.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_city_outlined,
                  label: 'المدينة',
                  value: city,
                ),
              if (method == 'delivery' && district.isNotEmpty)
                _InfoRow(
                  icon: Icons.map_outlined,
                  label: 'الحي',
                  value: district,
                ),
            ],
          ),

          // ─── الصناديق المرتبطة بالطلب (إن وجدت) ───
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _itemsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final items = snap.data ?? [];
              if (items.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  RequestItemsList(items: items),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════ صندوق معلومات ═══════════════════════════
class _InfoBox extends StatelessWidget {
  final List<Widget> children;

  const _InfoBox({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppDesign.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// ═══════════════════════════ شارة الحالة ═══════════════════════════
class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesign.secondary.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppDesign.primary,
        ),
      ),
    );
  }
}

/// ═══════════════════════════ صفحة مسح الباركود (تأكيد الاستلام) ═══════════════════════════
/// الباركود يحمل قيمة requestId الكاملة.
/// عند التطابق: القطع والصناديق -> delivered، والطلب -> completed.
/// ترجع true عند نجاح الاستلام.
class PickupScanPage extends StatefulWidget {
  final String requestId;

  const PickupScanPage({super.key, required this.requestId});

  @override
  State<PickupScanPage> createState() => _PickupScanPageState();
}

class _PickupScanPageState extends State<PickupScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 1000,
    formats: const [BarcodeFormat.all],
  );

  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String s) => s.trim().toLowerCase();

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _showSuccessDialog(String message) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere(
          (v) => v != null && v.trim().isNotEmpty,
          orElse: () => null,
        );
    if (raw == null) return;

    setState(() => _busy = true);

    try {
      // 1) الباركود لازم يطابق requestId
      if (_normalize(raw) != _normalize(widget.requestId)) {
        debugPrint('SCANNED: "$raw" | REQUEST: "${widget.requestId}"');
        _toast('هذا الباركود لا يخص طلبك', error: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _busy = false);
        return;
      }

      final db = FirebaseFirestore.instance;
      final requestRef = db
          .collection(kRequestsCollection)
          .doc(widget.requestId);

      // 2) تأكد أن الطلب لم يكتمل
      final requestSnap = await requestRef.get();
      if (requestSnap.data()?['status'] == kCompletedStatus) {
        _toast('تم استلام هذا الطلب مسبقاً', error: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _busy = false);
        return;
      }

      // 3) قطع الطلب
      final itemsSnap = await db
          .collection('items')
          .where('requestId', isEqualTo: widget.requestId)
          .get();

      final batch = db.batch();

      // 4) القطع -> delivered
      for (final itemDoc in itemsSnap.docs) {
        batch.update(itemDoc.reference, {'status': 'delivered'});
      }

      // 5) الصناديق -> delivered
      final boxIds = itemsSnap.docs
          .map((d) => (d.data()['boxId'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final boxId in boxIds) {
        batch.update(db.collection(kBoxesCollection).doc(boxId), {
          'status': 'delivered',
        });
      }

      // 6) الطلب -> completed
      batch.update(requestRef, {
        'status': kCompletedStatus,
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // 7) التبرعات اللي كل قطعها صارت مستلمة
      final currentIds = itemsSnap.docs.map((d) => d.id).toSet();
      final donationIds = itemsSnap.docs
          .map((d) => (d.data()['donationId'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final donationId in donationIds) {
        final donationRef = db.collection('donations').doc(donationId);
        final donationSnap = await donationRef.get();
        if (!donationSnap.exists) continue;

        final siblings = await db
            .collection('items')
            .where('donationId', isEqualTo: donationId)
            .get();

        final allDelivered = siblings.docs.every(
          (i) => currentIds.contains(i.id) || i.data()['status'] == 'delivered',
        );

        if (allDelivered) {
          batch.update(donationRef, {
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (!mounted) return;
      await _showSuccessDialog('تم استلام الطلب بنجاح');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('PICKUP SCAN ERROR: $e');
      _toast('حدث خطأ، حاول مرة ثانية', error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: AppDesign.primary,
          foregroundColor: Colors.white,
          title: const Text('تأكيد الاستلام'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'خطأ الكاميرا: ${error.errorCode}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            // إطار التوجيه
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'وجّه الكاميرا نحو باركود الطلب لتأكيد استلامه',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            if (_busy)
              Container(
                color: Colors.black38,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
