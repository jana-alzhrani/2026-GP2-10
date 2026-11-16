import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_design.dart';
import 'beneficiary_delivery_method_page.dart';
import 'Beneficiary_view_item_page.dart';
import 'order_limits_service.dart';

/// Cart items + current limits, loaded together.
class _CartData {
  final List<Map<String, dynamic>> items;
  final OrderLimits? limits; // null = couldn't be computed (don't block)

  const _CartData({required this.items, required this.limits});
}

class BeneficiaryCartPage extends StatefulWidget {
  final String userId;

  const BeneficiaryCartPage({super.key, required this.userId});

  @override
  State<BeneficiaryCartPage> createState() => _BeneficiaryCartPageState();
}

class _BeneficiaryCartPageState extends State<BeneficiaryCartPage> {
  // ---- Beneficiary status (live) ----
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statusSub;
  String _beneficiaryStatus = 'pending';
  bool _statusLoaded = false;

  bool get _isApproved => _beneficiaryStatus == 'approved';

  // ---- Cart data cache (used by pull-to-refresh) ----
  QuerySnapshot? _lastCartSnapshot; // latest cart docs from the stream
  Future<_CartData>? _dataFuture; // items + limits for those docs
  _CartData? _lastData; // last loaded data, shown while reloading

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
            if (!mounted) return;
            setState(() {
              _beneficiaryStatus = result.docs.isNotEmpty
                  ? (result.docs.first.data()['status'] ?? 'pending')
                        .toString()
                        .trim()
                        .toLowerCase()
                  : 'pending';
              _statusLoaded = true;
            });
          },
          onError: (e) {
            debugPrint('BENEFICIARY STATUS ERROR: $e');
            if (!mounted) return;
            setState(() {
              _beneficiaryStatus = 'pending';
              _statusLoaded = true;
            });
          },
        );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _deleteFromCart(String cartDocId) async {
    try {
      await FirebaseFirestore.instance
          .collection('cart')
          .doc(cartDocId)
          .delete();

      if (!mounted) return;
      AppDesign.showSuccessSnackBar(context, 'تمت إزالة القطعة من السلة');
    } catch (e) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'تعذر إزالة القطعة من السلة');
    }
  }

  Future<void> _confirmAndDelete(String cartDocId) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'إزالة القطعة',
      message: 'هل أنت متأكد من إزالة هذه القطعة من السلة؟',
      confirmText: 'إزالة',
      cancelText: 'إلغاء',
    );

    if (!confirm) return;

    await _deleteFromCart(cartDocId);
  }

  Future<void> _goToDeliveryMethod(
    List<Map<String, dynamic>> availableItems,
    OrderLimits? limits,
  ) async {
    if (availableItems.isEmpty) return;
    if (!_isApproved) return;

    // Re-check the item quota with fresh data right before continuing.
    final fresh = await OrderLimitsService.tryFetch(widget.userId) ?? limits;

    if (!mounted) return;

    if (fresh != null && fresh.exceedsItems(availableItems.length)) {
      AppDesign.showErrorSnackBar(context, fresh.itemsMessage);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeneficiaryDeliveryMethodPage(
          userId: widget.userId,
          cartItems: availableItems,
        ),
      ),
    );
  }

  // ============================================================
  // DATA
  // ============================================================

  /// Pull-to-refresh: reloads the cart items and the limits.
  Future<void> _onRefresh() async {
    final snap = _lastCartSnapshot;
    if (snap == null) return;

    final future = _loadCartData(snap.docs);
    setState(() => _dataFuture = future);

    try {
      await future;
    } catch (e) {
      debugPrint('CART REFRESH ERROR: $e');
    }
  }

  Future<_CartData> _loadCartData(List<QueryDocumentSnapshot> cartDocs) async {
    // Start both at the same time.
    final itemsFuture = _loadCartItems(cartDocs);
    final limitsFuture = OrderLimitsService.tryFetch(widget.userId);

    final items = await itemsFuture;
    final limits = await limitsFuture;

    return _CartData(items: items, limits: limits);
  }

  Future<List<Map<String, dynamic>>> _loadCartItems(
    List<QueryDocumentSnapshot> cartDocs,
  ) async {
    final List<Map<String, dynamic>> result = [];

    for (final cartDoc in cartDocs) {
      final cart = cartDoc.data() as Map<String, dynamic>;

      final itemId = (cart['itemId'] ?? '').toString();
      final boxId = (cart['boxId'] ?? '').toString();

      // Old cart entries (boxId only) can't be resolved to an item.
      // Show them as unavailable so the user can remove them.
      if (itemId.isEmpty) {
        result.add({
          'cartDocId': cartDoc.id,
          'itemId': '',
          'boxId': boxId,
          'isAvailable': false,
          'item': <String, dynamic>{},
          'box': <String, dynamic>{},
        });
        continue;
      }

      try {
        final itemSnap = await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get();

        final data = itemSnap.data();
        final isAvailable = itemSnap.exists && data?['status'] == 'available';

        // Live data if the item still exists, otherwise the snapshot
        // that was saved in the cart document.
        final Map<String, dynamic> itemData = Map<String, dynamic>.from(
          data ?? cart,
        );

        final bId = (itemData['boxId'] ?? boxId).toString();

        final missing =
            (itemData['gender'] ?? '').toString().trim().isEmpty ||
            itemData['ageGroup'] == null ||
            (itemData['size'] ?? '').toString().trim().isEmpty;

        if (missing && bId.isNotEmpty) {
          final boxSnap = await FirebaseFirestore.instance
              .collection('donation_boxes')
              .doc(bId)
              .get();
          final box = boxSnap.data();

          if (box != null) {
            if ((itemData['gender'] ?? '').toString().trim().isEmpty) {
              itemData['gender'] = box['gender'];
            }
            if (itemData['ageGroup'] == null) {
              itemData['ageGroup'] = box['ageGroup'];
            }
            if ((itemData['size'] ?? '').toString().trim().isEmpty) {
              itemData['size'] = box['generalSize'];
            }
          }
        }

        result.add({
          'cartDocId': cartDoc.id,
          'itemId': itemId,
          'boxId': (itemData['boxId'] ?? boxId).toString(),
          'isAvailable': isAvailable,
          'item': itemData,
          // kept so the delivery page can still read 'box' if it expects it
          'box': itemData,
        });
      } catch (e) {
        debugPrint('CART ITEM ERROR: $e');
      }
    }

    result.sort((a, b) {
      final aAvailable = a['isAvailable'] == true;
      final bAvailable = b['isAvailable'] == true;

      if (aAvailable && !bAvailable) return -1;
      if (!aAvailable && bAvailable) return 1;
      return 0;
    });

    return result;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        appBar: AppBar(
          title: Text(
            'السلة',
            style: AppDesign.h2Style.copyWith(
              color: AppDesign.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppDesign.background,
          foregroundColor: AppDesign.textPrimary,
          elevation: 0,
        ),
        body: !_statusLoaded
            ? const Center(child: CircularProgressIndicator())
            : !_isApproved
            ? _buildNotApproved()
            : _buildCartBody(),
      ),
    );
  }

  Widget _buildCartBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cart')
          .where('beneficiaryId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'in_cart')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ أثناء تحميل السلة',
              style: AppDesign.bodyStyle.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final cartDocs = snapshot.data?.docs ?? [];

        if (cartDocs.isEmpty) {
          _lastCartSnapshot = snapshot.data;
          _dataFuture = null;
          _lastData = null;
          return _buildEmptyCart();
        }

        // Load again only when the cart really changed (or on refresh),
        // not on every rebuild.
        if (_dataFuture == null ||
            !identical(_lastCartSnapshot, snapshot.data)) {
          _lastCartSnapshot = snapshot.data;
          _dataFuture = _loadCartData(cartDocs);
        }

        return FutureBuilder<_CartData>(
          future: _dataFuture,
          builder: (context, cartSnapshot) {
            if (cartSnapshot.hasData) {
              _lastData = cartSnapshot.data;
            }

            // Show a spinner only the first time; while reloading we keep
            // showing the previous data so the list doesn't flash.
            if (cartSnapshot.connectionState == ConnectionState.waiting &&
                _lastData == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = cartSnapshot.data ?? _lastData;
            final items = data?.items ?? [];
            final limits = data?.limits;

            final availableItems = items
                .where((c) => c['isAvailable'] == true)
                .toList();

            final unavailableItems = items
                .where((c) => c['isAvailable'] == false)
                .toList();

            return Column(
              children: [
                if (limits != null)
                  _buildQuotaCard(limits, availableItems.length),
                Expanded(
                  child: RefreshIndicator(
                    color: AppDesign.primary,
                    onRefresh: _onRefresh,
                    child: ListView(
                      // Always scrollable so pull-down works even with 1 item.
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      children: [
                        if (availableItems.isNotEmpty) ...[
                          _buildSectionTitle('القطع المتاحة'),
                          const SizedBox(height: 10),
                          ...availableItems.map((c) => _buildCartCard(c)),
                        ],
                        if (unavailableItems.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _buildSectionTitle('القطع غير المتاحة'),
                          const SizedBox(height: 10),
                          ...unavailableItems.map((c) => _buildCartCard(c)),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildBottomButton(
                  hasUnavailable: unavailableItems.isNotEmpty,
                  hasAvailable: availableItems.isNotEmpty,
                  availableItems: availableItems,
                  limits: limits,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget _buildNotApproved() {
    final message = _beneficiaryStatus == 'rejected'
        ? 'عذرًا، لم تتم الموافقة على طلبك كمستفيد.'
        : 'طلبك كمستفيد قيد المراجعة، ويمكنك استخدام السلة بعد الموافقة.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 64,
              color: AppDesign.primary.withOpacity(0.45),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppDesign.bodyStyle.copyWith(
                color: AppDesign.primary,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: AppDesign.subtitleStyle.copyWith(
          color: AppDesign.primary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCartCard(Map<String, dynamic> card) {
    final bool isAvailable = card['isAvailable'] == true;
    final item = card['item'] as Map<String, dynamic>;

    final cartDocId = card['cartDocId'].toString();
    final itemId = card['itemId'].toString();
    final boxId = card['boxId'].toString();

    final type = (item['type'] ?? 'قطعة ملابس').toString();
    final gender = (item['gender'] ?? '-').toString();

    final rawAge = item['ageGroup'];
    final ageGroup = rawAge is Map
        ? (rawAge['label'] ?? '-').toString()
        : (rawAge ?? '-').toString();

    final size = (item['size'] ?? '').toString();
    final imageUrl = (item['imageUrl'] ?? '').toString();
    final List images = imageUrl.isNotEmpty ? [imageUrl] : [];

    return GestureDetector(
      onTap: isAvailable && itemId.isNotEmpty
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BeneficiaryViewItemPage(
                    itemId: itemId,
                    boxId: boxId,
                    userId: widget.userId,
                  ),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isAvailable ? AppDesign.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppDesign.radiusXL),
          border: Border.all(
            color: isAvailable ? AppDesign.border : Colors.grey.shade300,
          ),
          boxShadow: [
            if (isAvailable)
              BoxShadow(
                color: AppDesign.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              if (!isAvailable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'هذه القطعة وجدت طريقها إلى مستفيد آخر. يرجى إزالتها من السلة للمتابعة',
                    textAlign: TextAlign.center,
                    style: AppDesign.bodyStyle.copyWith(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePreview(images, isAvailable),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppDesign.subtitleStyle.copyWith(
                            color: isAvailable
                                ? AppDesign.textPrimary
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInfoText('الجنس', gender, isAvailable),
                        const SizedBox(height: 5),
                        _buildInfoText('الفئة العمرية', ageGroup, isAvailable),
                        if (size.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _buildInfoText('المقاس', size, isAvailable),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmAndDelete(cartDocId),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('إزالة من السلة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesign.radiusLG),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(List images, bool isAvailable) {
    if (images.isEmpty) {
      return Container(
        width: 95,
        height: 115,
        decoration: BoxDecoration(
          color: AppDesign.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.checkroom_outlined,
          size: 34,
          color: isAvailable ? AppDesign.primary : Colors.grey,
        ),
      );
    }

    return Container(
      width: 95,
      height: 115,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        images.first.toString(),
        fit: BoxFit.cover,
        color: isAvailable ? null : Colors.grey.withOpacity(0.45),
        colorBlendMode: isAvailable ? null : BlendMode.saturation,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppDesign.surfaceAlt,
            child: Icon(
              Icons.broken_image_outlined,
              size: 34,
              color: isAvailable ? AppDesign.primary : Colors.grey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoText(String title, String value, bool isAvailable) {
    return Text(
      '$title: $value',
      style: AppDesign.bodySecondaryStyle.copyWith(
        color: isAvailable ? AppDesign.textSecondary : Colors.grey.shade500,
        fontSize: 13,
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 75,
              color: AppDesign.primary.withOpacity(0.45),
            ),
            const SizedBox(height: 18),
            Text(
              'السلة فارغة',
              style: AppDesign.h2Style.copyWith(
                color: AppDesign.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك إضافة القطع التي تناسبك من صفحة التبرعات.',
              textAlign: TextAlign.center,
              style: AppDesign.bodyStyle.copyWith(
                color: AppDesign.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Quota card: progress bar of the items left + days until reset
  // ------------------------------------------------------------
  Widget _buildQuotaCard(OrderLimits limits, int cartCount) {
    final maxItems = limits.maxItemsPerPeriod;
    final remaining = limits.itemsRemaining;
    final ratio = maxItems == 0 ? 0.0 : remaining / maxItems;
    final afterOrder = remaining - cartCount;
    final days = limits.daysUntilReset;

    final Color barColor = ratio <= 0.2
        ? Colors.red.shade600
        : ratio <= 0.5
        ? Colors.orange.shade700
        : AppDesign.primary;

    final String resetText = days == null
        ? 'تبدأ الفترة مع أول طلب'
        : days == 0
        ? 'تتجدد اليوم'
        : 'تتجدد بعد $days يومًا';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        border: Border.all(color: AppDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'حصتك خلال $kLimitPeriodDays يومًا',
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'المتبقي: $remaining من $maxItems قطعة',
                style: AppDesign.bodyStyle.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _quotaChip(Icons.shopping_cart_outlined, 'في السلة: $cartCount'),
              _quotaChip(Icons.event_repeat_rounded, resetText),
            ],
          ),
          if (cartCount > 0 && afterOrder >= 0) ...[
            const SizedBox(height: 8),
            Text(
              'بعد هذا الطلب ستتبقى لك $afterOrder قطعة',
              style: AppDesign.bodySecondaryStyle.copyWith(
                color: AppDesign.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quotaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppDesign.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppDesign.bodySecondaryStyle.copyWith(
            color: AppDesign.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton({
    required bool hasUnavailable,
    required bool hasAvailable,
    required List<Map<String, dynamic>> availableItems,
    required OrderLimits? limits,
  }) {
    final overItems =
        limits != null && limits.exceedsItems(availableItems.length);

    // Warning under the card (only when the item quota is exceeded).
    String? warning;
    if (overItems) {
      warning = limits.itemsRemaining == 0
          ? limits.itemsMessage
          : '${limits.itemsMessage}، يرجى إزالة بعض القطع للمتابعة';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (warning != null) ...[
              Text(
                warning,
                textAlign: TextAlign.center,
                style: AppDesign.bodyStyle.copyWith(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: AppDesign.buttonHeightMD,
              child: ElevatedButton(
                onPressed: hasUnavailable || !hasAvailable || overItems
                    ? null
                    : () async {
                        await _goToDeliveryMethod(availableItems, limits);
                      },
                child: Text(
                  hasUnavailable
                      ? 'أزل القطع غير المتاحة للمتابعة'
                      : 'طلب التبرع',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
