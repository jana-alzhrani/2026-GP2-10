import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';
import 'Beneficiary_more_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// ─────────────── إعدادات قاعدة البيانات ───────────────
const String kRequestsCollection = 'requests';
const String kBoxesCollection = 'donation_boxes';

/// الحقل الذي يربط الطلب بالمستفيد
const String kBeneficiaryIdField = 'beneficiaryId';

/// الحقل داخل donation_boxes الذي يربط الصندوق بالطلب (عدّله حسب قاعدتك)
const String kBoxRequestIdField = 'requestId';

/// حالات الطلبات التي تظهر في تبويب "الطلبات النشطة"
const List<String> kActiveStatuses = [
  'requested',
  'reserved',
  'delivered',
];

/// الحالة المكتملة (تُستخدم في كل الملف)
const String kCompletedStatus = 'completed';

/// حالات الطلبات التي تظهر في تبويب "الطلبات السابقة"
const List<String> kPreviousStatuses = [
  kCompletedStatus,
];

const Map<String, String> kStatusLabels = {
  'requested': 'تم الطلب',
  'reserved': 'تم الحجز',
  'delivered': 'جاري التوصيل',
  'completed': 'تم الاستلام',
};

String _statusLabel(String s, {String method = ''}) =>
    kStatusLabels[s] ?? s;

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

  const BeneficiaryOrdersPage({
    super.key,
    required this.userId,
  });

  @override
  State<BeneficiaryOrdersPage> createState() => _BeneficiaryOrdersPageState();
}

class _BeneficiaryOrdersPageState extends State<BeneficiaryOrdersPage> {
  int _bottomNavIndex = 1;
  bool _accessChecked = false;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _checkBeneficiaryStatus();
  }

  Future<void> _checkBeneficiaryStatus() async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('beneficiaries')
          .where('userId', isEqualTo: widget.userId)
          .limit(1)
          .get();

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isApproved = false;
        _accessChecked = true;
      });
    }
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
                          'طلبك كمستفيد قيد المراجعة، وستتمكن من متابعة طلباتك بعد الموافقة.',
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
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
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
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
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
          return const Center(
            child: Text("حدث خطأ أثناء تحميل الطلبات"),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
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
            Navigator.pushReplacementNamed(context, '/beneficiaryHome', arguments: widget.userId);
          } else if (_isApproved && index == 1) {
            return;
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => BeneficiaryMorePage(userId: widget.userId)),
            );
          }
        },
        destinations: destinations,
      ),
    );
  }

}

/// ═══════════════════════════ كارد الطلب ═══════════════════════════
class OrderCard extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const OrderCard({
    super.key,
    required this.requestId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? '').toString();
    final method = (data['deliveryMethod'] ?? '').toString();
    final createdAt = _toDate(data['createdAt']);

    final addr = data['deliveryAddress'];
    final warehouseName =
        addr is Map ? (addr['warehouseName'] ?? '').toString() : '';
    final city = addr is Map ? (addr['city'] ?? '').toString() : '';
    final district = addr is Map ? (addr['district'] ?? '').toString() : '';

    final shortId =
        requestId.length < 6 ? requestId : requestId.substring(0, 6);

    // زر المسح يظهر فقط للاستلام من المستودع وقبل اكتمال الطلب
    final canScan = method == 'pickup' && status != kCompletedStatus;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
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
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(kBoxesCollection)
                .where(kBoxRequestIdField, isEqualTo: requestId)
                .snapshots(),
            builder: (context, snap) {
              final boxes = snap.data?.docs ?? [];
              if (boxes.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'الصناديق',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppDesign.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final b in boxes)
                    _BoxTile(
                      boxId: b.id,
                      data: b.data(),
                      statusLabel: _statusLabel(
                        (b.data()['status'] ?? status).toString(),
                        method: method,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════ صندوق (قابل للفتح) ═══════════════════════════
class _BoxTile extends StatelessWidget {
  final String boxId;
  final Map<String, dynamic> data;
  final String statusLabel;

  const _BoxTile({
    required this.boxId,
    required this.data,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final code =
        (data['boxCode'] ?? data['code'] ?? data['boxNumber'] ?? boxId)
            .toString();

    // BOX1-SK8A9
    // BOX1- = غامق
    // SK8A9 = رمادي
    final dash = code.indexOf('-');

    final head = dash == -1 ? code : code.substring(0, dash + 1);
    final tail = dash == -1 ? '' : code.substring(dash + 1);

    final items = data['items'] is List ? data['items'] as List : const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: head,
                      style: TextStyle(
                        color: AppDesign.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    TextSpan(
                      text: tail,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                textDirection: TextDirection.ltr,
              ),
              const Spacer(),
            ],
          ),
          children: [
            for (int i = 0; i < items.length; i++)
              _ItemTile(
                index: i,
                item: items[i],
              ),
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════ قطعة داخل الصندوق ═══════════════════════════
class _ItemTile extends StatelessWidget {
  final int index;
  final dynamic item;

  const _ItemTile({
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final map = item is Map ? item as Map : const {};

    final imageUrl = map['imageUrl']?.toString();

    final type =
        (map['type'] ?? map['category'] ?? map['name'] ?? map['title'] ?? '')
            .toString();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.checkroom_outlined,
                        color: Colors.grey.shade500,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'القطعة ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                  ),
                ),
                if (type.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════ صندوق معلومات ═══════════════════════════
class _InfoBox extends StatelessWidget {
  final List<Widget> children;

  const _InfoBox({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: children,
      ),
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
          Icon(
            icon,
            size: 18,
            color: AppDesign.primary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
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

  const _StatusChip({
    required this.label,
  });

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
/// صفحة مسح باركود الصندوق لتأكيد الاستلام من المستودع.
/// ترجع true عند اكتمال استلام كل الصناديق.
class PickupScanPage extends StatefulWidget {
  final String requestId;

  const PickupScanPage({super.key, required this.requestId});

  @override
  State<PickupScanPage> createState() => _PickupScanPageState();
}

class _PickupScanPageState extends State<PickupScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.all],
  );

  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String s) => s.trim().toLowerCase();

  String _codeOf(Map<String, dynamic> d, String fallback) =>
      (d['boxCode'] ?? d['code'] ?? d['boxNumber'] ?? fallback).toString();

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
        .firstWhere((v) => v != null && v.trim().isNotEmpty,
            orElse: () => null);
    if (raw == null) return;

    setState(() => _busy = true);

    try {
      final db = FirebaseFirestore.instance;

      final snap = await db
          .collection(kBoxesCollection)
          .where(kBoxRequestIdField, isEqualTo: widget.requestId)
          .get();

      // دوّر على الصندوق اللي كوده يطابق الباركود
      QueryDocumentSnapshot<Map<String, dynamic>>? match;
      for (final d in snap.docs) {
        if (_normalize(_codeOf(d.data(), d.id)) == _normalize(raw)) {
          match = d;
          break;
        }
      }

      if (match == null) {
        _toast('هذا الباركود لا يخص طلبك', error: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _busy = false);
        return;
      }

      if (match.data()['status'] == kCompletedStatus) {
        _toast('تم تأكيد استلام هذا الصندوق مسبقاً', error: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _busy = false);
        return;
      }

      // 1) تأكيد استلام الصندوق
      await match.reference.update({
        'status': kCompletedStatus,
        'receivedAt': FieldValue.serverTimestamp(),
      });

      // 2) إذا كل الصناديق انستلمت، اقفل الطلب
      final remaining = snap.docs
          .where((d) =>
              d.id != match!.id && d.data()['status'] != kCompletedStatus)
          .toList();

      final allDone = remaining.isEmpty;

      if (allDone) {
        await db.collection(kRequestsCollection).doc(widget.requestId).update({
          'status': kCompletedStatus,
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // 3) رسالة "تم الاستلام"
      await _showSuccessDialog(
        allDone
            ? 'تم استلام الطلب بالكامل'
            : 'تم استلام الصندوق، باقي ${remaining.length}',
      );

      if (!mounted) return;

      if (allDone) {
        Navigator.pop(context, true);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
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
                  'وجّه الكاميرا نحو باركود الصندوق لتأكيد استلامه',
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
