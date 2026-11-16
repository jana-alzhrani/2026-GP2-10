import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_design.dart';
import 'recommender.dart';

class BeneficiaryViewItemPage extends StatefulWidget {
  final String itemId;
  final String boxId;
  final String userId;

  const BeneficiaryViewItemPage({
    super.key,
    required this.itemId,
    required this.boxId,
    required this.userId,
  });

  @override
  State<BeneficiaryViewItemPage> createState() =>
      _BeneficiaryViewItemPageState();
}

class _BeneficiaryViewItemPageState extends State<BeneficiaryViewItemPage> {
  bool _isAddingToCart = false;
  late final Future<Map<String, dynamic>> _itemFuture;

  // Both streams are created once so they aren't re-created on every rebuild.
  late final Stream<bool> _inCartStreamValue = _inCartStream();
  late final Stream<bool> _itemAvailableStreamValue = _itemAvailableStream();

  @override
  void initState() {
    super.initState();
    _itemFuture = _loadItem();
  }

  Future<Map<String, dynamic>> _loadItem() async {
    final db = FirebaseFirestore.instance;

    final itemDoc = await db.collection('items').doc(widget.itemId).get();

    if (!itemDoc.exists) {
      throw Exception('لم يتم العثور على القطعة');
    }

    final itemData = Map<String, dynamic>.from(itemDoc.data()!);
    final boxId = (itemData['boxId'] ?? widget.boxId).toString();
    final donationId = (itemData['donationId'] ?? '').toString();

    // نجيب الجنس والفئة العمرية والمقاس من الصندوق
    if (boxId.isNotEmpty) {
      try {
        final boxSnap = await db.collection('donation_boxes').doc(boxId).get();
        final box = boxSnap.data();

        if (box != null) {
          itemData['gender'] = box['gender'] ?? itemData['gender'];
          itemData['ageGroup'] = box['ageGroup'] ?? itemData['ageGroup'];

          // مقاس الحذاء يبقى من القطعة، غيره المقاس العام من الصندوق
          final size = (itemData['size'] ?? '').toString().trim();
          if (size.isEmpty || size == 'null') {
            itemData['size'] = box['generalSize'];
          }
        }
      } catch (e) {
        debugPrint('BOX FETCH ERROR: $e');
      }
    }

    return {
      'itemId': itemDoc.id,
      'item': itemData,
      'boxId': boxId,
      'donationId': donationId,
    };
  }

  Uint8List? _decodeImage(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    try {
      var encoded = value.toString().trim();
      if (encoded.startsWith('data:image') && encoded.contains(',')) {
        encoded = encoded.substring(encoded.indexOf(',') + 1);
      }
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  String _ageLabel(dynamic value) {
    if (value is Map) return (value['label'] ?? '-').toString();
    if (value == null || value.toString().trim().isEmpty) return '-';
    return value.toString();
  }

  // هل القطعة في سلة المستفيد؟
  Stream<bool> _inCartStream() {
    return FirebaseFirestore.instance
        .collection('cart')
        .where('beneficiaryId', isEqualTo: widget.userId)
        .where('itemId', isEqualTo: widget.itemId)
        .where('status', isEqualTo: 'in_cart')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }

  // هل القطعة ما زالت متاحة؟ (تتحدث فورًا لو انحجزت أو انحذفت)
  Stream<bool> _itemAvailableStream() {
    return FirebaseFirestore.instance
        .collection('items')
        .doc(widget.itemId)
        .snapshots()
        .map((snap) => snap.exists && snap.data()?['status'] == 'available');
  }

  Future<void> _addToCart(Map<String, dynamic> loadedData) async {
    if (_isAddingToCart) return;

    setState(() => _isAddingToCart = true);
    try {
      final db = FirebaseFirestore.instance;

      // فحص أخير: القطعة لسا متاحة؟
      final freshItem = await db.collection('items').doc(widget.itemId).get();
      if (!freshItem.exists || freshItem.data()?['status'] != 'available') {
        if (!mounted) return;
        AppDesign.showErrorSnackBar(context, 'هذه القطعة لم تعد متاحة');
        return;
      }

      final beneficiaryDoc = await db
          .collection('beneficiaries')
          .doc(widget.userId)
          .get();

      final status = (beneficiaryDoc.data()?['status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();

      if (!beneficiaryDoc.exists || status != 'approved') {
        if (!mounted) return;
        AppDesign.showErrorSnackBar(
          context,
          status == 'rejected'
              ? 'عذرًا، لم تتم الموافقة على طلبك كمستفيد.'
              : 'طلبك قيد المراجعة، يمكنك إضافة القطع للسلة بعد قبولك كمستفيد.',
        );
        return;
      }

      final existing = await db
          .collection('cart')
          .where('beneficiaryId', isEqualTo: widget.userId)
          .where('itemId', isEqualTo: widget.itemId)
          .where('status', isEqualTo: 'in_cart')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        AppDesign.showErrorSnackBar(context, 'هذه القطعة مضافة للسلة مسبقًا');
        return;
      }

      final item = Map<String, dynamic>.from(loadedData['item'] as Map);

      final rawSize = (item['size'] ?? '').toString().trim();

      await db.collection('cart').add({
        'beneficiaryId': widget.userId,
        'itemId': widget.itemId,
        'boxId': loadedData['boxId'] ?? '',
        'donationId': loadedData['donationId'] ?? '',
        'status': 'in_cart',
        'type': (item['type'] ?? '').toString(),
        'description': (item['description'] ?? '').toString(),
        'imageUrl': (item['imageUrl'] ?? '').toString(),
        'size': rawSize == 'null' ? '' : rawSize,
        'gender': (item['gender'] ?? '').toString(),
        'ageGroup': _ageLabel(item['ageGroup']),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      AppDesign.showSuccessSnackBar(context, 'تمت إضافة القطعة إلى السلة');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذرت إضافة القطعة إلى السلة: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Widget _infoRow(IconData icon, String title, String value) {
    if (value.trim().isEmpty || value == '-') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppDesign.primary),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: AppDesign.bodyStyle.copyWith(
              color: AppDesign.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppDesign.bodyStyle.copyWith(
                color: AppDesign.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(Map<String, dynamic> item) {
    final bytes = _decodeImage(item['imageBase64']);
    final imageUrl = (item['imageUrl'] ?? '').toString().trim();

    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
    }

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }

    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppDesign.surfaceAlt,
      width: double.infinity,
      child: const Center(
        child: Icon(
          Icons.checkroom_outlined,
          size: 64,
          color: AppDesign.secondary,
        ),
      ),
    );
  }

  // زر الإضافة للسلة: يتحدث فورًا حسب حالة القطعة والسلة
  Widget _buildCartButton(Map<String, dynamic> loadedData) {
    return StreamBuilder<bool>(
      stream: _itemAvailableStreamValue,
      builder: (context, availableSnap) {
        // قبل وصول أول تحديث نعتبرها متاحة (تم التحقق منها عند التحميل)
        final isAvailable = availableSnap.data ?? true;

        return StreamBuilder<bool>(
          stream: _inCartStreamValue,
          builder: (context, cartSnap) {
            final inCart = cartSnap.data ?? false;

            final disabled = _isAddingToCart || inCart || !isAvailable;

            final IconData icon = !isAvailable
                ? Icons.block_outlined
                : inCart
                ? Icons.check_circle_outline
                : Icons.shopping_cart_outlined;

            final String label = _isAddingToCart
                ? 'جارٍ الإضافة...'
                : !isAvailable
                ? 'القطعة غير متاحة حاليًا'
                : inCart
                ? 'المنتج موجود بالسلة'
                : 'إضافة القطعة إلى السلة';

            return SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: disabled ? null : () => _addToCart(loadedData),
                icon: _isAddingToCart
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon),
                label: Text(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppDesign.primary.withOpacity(0.35),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesign.radiusLG),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'تفاصيل القطعة',
            style: AppDesign.h2Style.copyWith(color: AppDesign.textPrimary),
          ),
          centerTitle: true,
          backgroundColor: AppDesign.background,
          foregroundColor: AppDesign.textPrimary,
          elevation: 0,
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _itemFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesign.screenPadding),
                  child: Text(
                    'حدث خطأ أثناء تحميل تفاصيل القطعة\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: AppDesign.bodyStyle.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('لا توجد بيانات'));
            }

            final loadedData = snapshot.data!;
            final item = Map<String, dynamic>.from(loadedData['item'] as Map);

            final type = (item['type'] ?? 'قطعة ملابس').toString();
            final rawSize = (item['size'] ?? '').toString().trim();
            final size = rawSize == 'null' ? '' : rawSize;
            final gender = (item['gender'] ?? '-').toString();
            final age = _ageLabel(item['ageGroup']);

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppPadding.screen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusLG,
                          ),
                          child: SizedBox(
                            height: 280,
                            child: _buildImage(item),
                          ),
                        ),
                        const SizedBox(height: AppDesign.spaceLG),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDesign.cardPadding),
                          decoration: AppDesign.primaryCardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type,
                                style: AppDesign.h1Style.copyWith(
                                  color: AppDesign.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppDesign.spaceLG),
                              _infoRow(
                                Icons.straighten_outlined,
                                'المقاس',
                                size,
                              ),
                              _infoRow(Icons.wc_outlined, 'الجنس', gender),
                              _infoRow(
                                Icons.cake_outlined,
                                'الفئة العمرية',
                                age,
                              ),
                            ],
                          ),
                        ),
                        MatchingItemsSection(
                          itemId: widget.itemId,
                          item: item,
                          userId: widget.userId,
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildCartButton(loadedData),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
