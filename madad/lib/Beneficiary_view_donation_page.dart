import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'app_design.dart';

class BeneficiaryViewDonationPage extends StatefulWidget {
  final String boxId;
  final String userId;

  const BeneficiaryViewDonationPage({
    super.key,
    required this.boxId,
    required this.userId,
  });

  @override
  State<BeneficiaryViewDonationPage> createState() =>
      _BeneficiaryViewDonationPageState();
}

class _BeneficiaryViewDonationPageState
    extends State<BeneficiaryViewDonationPage> {
  bool _isAddingToCart = false;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>>
    _beneficiaryStatusStream;

  late Future<Map<String, dynamic>> _donationDetailsFuture;

   @override
  void initState() {
    super.initState();

    _donationDetailsFuture = _loadDonationDetails();

    _beneficiaryStatusStream = FirebaseFirestore.instance
        .collection('beneficiaries')
        .doc(widget.userId)
        .snapshots();
  }

  // ============================================================
  // Helpers
  // ============================================================

  int _parseInt(dynamic value) {
    if (value is int) return value;

    if (value is double) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  Uint8List? _decodeImage(String? imageBase64) {
    if (imageBase64 == null || imageBase64.trim().isEmpty) {
      return null;
    }

    try {
      return base64Decode(imageBase64);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Load Donation Details
  // ============================================================

  Future<Map<String, dynamic>> _loadDonationDetails() async {
    final boxDoc = await FirebaseFirestore.instance
        .collection('donation_boxes')
        .doc(widget.boxId)
        .get();

    if (!boxDoc.exists) {
      throw Exception('لم يتم العثور على الصندوق');
    }

    final boxData = boxDoc.data()!;

    final items = boxData['items'];

    List<Map<String, dynamic>> parsedItems = [];

    if (items is List) {
      parsedItems = items
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    return {
      'box': boxData,
      'items': parsedItems,
    };
  }

  // ============================================================
  // Recommended System (by age group only)
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadRecommendedDonations(
    Map<String, dynamic> currentBox,
  ) async {
    try {
      final currentAgeGroup =
          (currentBox['ageGroup']?['label'] ?? '').toString().trim();

      // لو ما فيه فئة عمرية للتبرع الحالي ما نقدر نوصي
      if (currentAgeGroup.isEmpty) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .get();

      final List<Map<String, dynamic>> recommendations = [];

      for (final doc in snapshot.docs) {
        // لا نوصي بنفس التبرع
        if (doc.id == widget.boxId) continue;

        final data = doc.data();

        final recommendedAgeGroup =
            (data['ageGroup']?['label'] ?? '').toString().trim();

        // نفس الفئة العمرية فقط
        if (recommendedAgeGroup == currentAgeGroup) {
          recommendations.add({
            'id': doc.id,
            'data': data,
          });
        }
      }

      // أقصى عدد 5 توصيات
      return recommendations.take(5).toList();
    } catch (e) {
      debugPrint('Error loading recommended donations: $e');
      return [];
    }
  }

  // ============================================================
  // Add to Cart
  // ============================================================

  Future<void> _addToCart(
    Map<String, dynamic> boxData,
  ) async {
    try {
      setState(() => _isAddingToCart = true);
            // التحقق من حالة المستفيد قبل الإضافة للسلة
      final beneficiaryDoc = await FirebaseFirestore.instance
          .collection('beneficiaries')
          .doc(widget.userId)
          .get();

      final beneficiaryStatus =
          (beneficiaryDoc.data()?['status'] ?? 'pending')
              .toString()
              .trim()
              .toLowerCase();

      if (!beneficiaryDoc.exists ||
          beneficiaryStatus != 'approved') {
        if (!mounted) return;

        AppDesign.showErrorSnackBar(
          context,
          beneficiaryStatus == 'rejected'
              ? 'عذرًا، لم تتم الموافقة على طلبك كمستفيد.'
              : 'طلبك قيد المراجعة، يمكنك إضافة التبرعات للسلة بعد قبولك كمستفيد.',
        );

        return;
      }

      final existingCartItem = await FirebaseFirestore.instance
          .collection('cart')
          .where(
            'beneficiaryId',
            isEqualTo: widget.userId,
          )
          .where(
            'boxId',
            isEqualTo: widget.boxId,
          )
          .where(
            'status',
            isEqualTo: 'in_cart',
          )
          .limit(1)
          .get();

      if (existingCartItem.docs.isNotEmpty) {
        if (!mounted) return;

        AppDesign.showErrorSnackBar(
          context,
          'التبرع مضاف للسلة مسبقًا',
        );

        return;
      }

      await FirebaseFirestore.instance.collection('cart').add({
        'beneficiaryId': widget.userId,
        'boxId': widget.boxId,
        'donationId': boxData['donationId'] ?? '',
        'status': 'in_cart',
        'gender': boxData['gender'] ?? '',
        'ageGroup': boxData['ageGroup']?['label'] ?? '',
        'generalSize': boxData['generalSize'] ?? '',
        'numberOfItems': (boxData['items'] is List)
            ? (boxData['items'] as List).length
            : 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      AppDesign.showSuccessSnackBar(
        context,
        'تمت إضافة التبرع إلى السلة',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل إضافة الصندوق إلى السلة: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(
          () => _isAddingToCart = false,
        );
      }
    }
  }

  // ============================================================
  // Info Row
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppDesign.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppDesign.captionStyle.copyWith(
            color: AppDesign.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppDesign.bodyStyle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Chip
  // ============================================================

  Widget _chip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spaceMD,
        vertical: AppDesign.spaceSM,
      ),
      decoration: BoxDecoration(
        color: AppDesign.surfaceAlt,
        borderRadius: BorderRadius.circular(
          AppDesign.radiusLG,
        ),
        border: Border.all(
          color: AppDesign.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          Icon(
            icon,
            size: AppDesign.iconSM,
            color: AppDesign.primary,
          ),
          const SizedBox(
            width: AppDesign.spaceSM,
          ),
          Text(
            text,
            style: AppDesign.captionStyle.copyWith(
              color: AppDesign.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Item Card
  // ============================================================

  Widget _buildItemCard(
    Map<String, dynamic> item,
    int itemIndex,
  ) {
    final imageBase64 = item['imageBase64'];

    final imageUrl = item['imageUrl'];

    final Uint8List? imageBytes = imageBase64 != null
        ? _decodeImage(
            imageBase64.toString(),
          )
        : null;

    final type = (item['type'] ?? 'غير محدد').toString();

    final size = (item['size'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(
        bottom: AppDesign.spaceLG,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppDesign.spaceMD,
              AppDesign.spaceLG,
              AppDesign.spaceMD,
              AppDesign.spaceMD,
            ),
            decoration: BoxDecoration(
              color: AppDesign.white,
              borderRadius: BorderRadius.circular(
                AppDesign.radiusLG,
              ),
              border: Border.all(
                color: AppDesign.border,
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: imageBytes == null
                      ? null
                      : () => _showImagePreview(
                            imageBytes,
                          ),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppDesign.surfaceAlt,
                      borderRadius: BorderRadius.circular(
                        AppDesign.radiusMD,
                      ),
                      border: Border.all(
                        color: AppDesign.border,
                      ),
                    ),
                    child: imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusMD,
                            ),
                            child: Image.memory(
                              imageBytes,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          )
                        : (imageUrl != null &&
                                imageUrl.toString().trim().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppDesign.radiusMD,
                                ),
                                child: Image.network(
                                  imageUrl.toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return const Icon(
                                      Icons.broken_image,
                                      color: AppDesign.secondary,
                                      size: 30,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppDesign.secondary,
                                size: 30,
                              )),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النوع: $type',
                        textAlign: TextAlign.right,
                        style: AppDesign.bodyStyle.copyWith(
                          color: AppDesign.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (type == 'حذاء' && size.trim().isNotEmpty)
                        Text(
                          'مقاس الحذاء: $size',
                          textAlign: TextAlign.right,
                          style: AppDesign.bodySecondaryStyle,
                        )
                      else if (size.trim().isNotEmpty)
                        Text(
                          'المقاس: $size',
                          textAlign: TextAlign.right,
                          style: AppDesign.bodySecondaryStyle,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -5,
            right: 24,
            child: Text(
              'القطعة ${itemIndex + 1}',
              style: AppDesign.subtitleStyle.copyWith(
                color: AppDesign.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Recommended Card
  // ============================================================

  Widget _buildRecommendedCard(
    Map<String, dynamic> recommendation,
  ) {
    final String boxId = recommendation['id'].toString();

    final Map<String, dynamic> data = Map<String, dynamic>.from(
      recommendation['data'] as Map,
    );

    final gender = (data['gender'] ?? '-').toString();

    final ageGroup = (data['ageGroup']?['label'] ?? '-').toString();

    final generalSize = (data['generalSize'] ?? '').toString();

    final items = data['items'];

    int numberOfItems = 0;

    if (items is List) {
      numberOfItems = items.length;
    }

    // ------------------------------------------------------------
    // Get first available image
    // ------------------------------------------------------------

    Uint8List? imageBytes;

    String? imageUrl;

    if (items is List && items.isNotEmpty) {
      final firstItem = items.first;

      if (firstItem is Map) {
        final base64Image = firstItem['imageBase64'];

        final networkImage = firstItem['imageUrl'];

        if (base64Image != null) {
          imageBytes = _decodeImage(
            base64Image.toString(),
          );
        }

        if (networkImage != null &&
            networkImage.toString().trim().isNotEmpty) {
          imageUrl = networkImage.toString();
        }
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BeneficiaryViewDonationPage(
              boxId: boxId,
              userId: widget.userId,
            ),
          ),
        );
      },
      child: Container(
        width: 245,
        margin: const EdgeInsets.only(
          left: AppDesign.spaceMD,
        ),
        decoration: BoxDecoration(
          color: AppDesign.white,
          borderRadius: BorderRadius.circular(
            AppDesign.radiusLG,
          ),
          border: Border.all(
            color: AppDesign.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----------------------------------------------------
            // Image
            // ----------------------------------------------------

            SizedBox(
              height: 145,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                    AppDesign.radiusLG,
                  ),
                  topRight: Radius.circular(
                    AppDesign.radiusLG,
                  ),
                ),
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: AppDesign.surfaceAlt,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppDesign.secondary,
                                  size: 38,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: AppDesign.surfaceAlt,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppDesign.secondary,
                              size: 38,
                            ),
                          ),
              ),
            ),

            // ----------------------------------------------------
            // Content
            // ----------------------------------------------------

            Padding(
              padding: const EdgeInsets.all(
                AppDesign.spaceMD,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recommendation badge

                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppDesign.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(
                          AppDesign.radiusLG,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: AppDesign.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'مناسب لك',
                            style: AppDesign.captionStyle.copyWith(
                              color: AppDesign.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Gender

                  _recommendedInfoLine(
                    Icons.wc_outlined,
                    gender,
                  ),

                  const SizedBox(height: 6),

                  // Age / Size

                  _recommendedInfoLine(
                    ageGroup.contains('بالغون')
                        ? Icons.straighten_outlined
                        : Icons.cake_outlined,
                    ageGroup.contains('بالغون')
                        ? (generalSize.trim().isNotEmpty ? generalSize : '-')
                        : ageGroup,
                  ),

                  const SizedBox(height: 6),

                  // Number of items

                  _recommendedInfoLine(
                    Icons.inventory_2_outlined,
                    '$numberOfItems قطع',
                  ),

                  const SizedBox(height: 14),

                  // View button

                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BeneficiaryViewDonationPage(
                              boxId: boxId,
                              userId: widget.userId,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'عرض التبرع',
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_back_ios_new,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Recommended Info Line
  // ============================================================

  Widget _recommendedInfoLine(
    IconData icon,
    String text,
  ) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(
          icon,
          size: 17,
          color: AppDesign.primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesign.captionStyle.copyWith(
              color: AppDesign.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Recommended Section
  // ============================================================

  Widget _buildRecommendedSection(
    Map<String, dynamic> currentBox,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRecommendedDonations(
        currentBox,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDesign.spaceLG,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قد يناسبك أيضًا',
                  style: AppDesign.subtitleStyle.copyWith(
                    color: AppDesign.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 15),
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recommendations = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.only(
            top: AppDesign.spaceXL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------
              // Section title
              // --------------------------------------------------

              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppDesign.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppDesign.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'قد يناسبك أيضًا',
                          style: AppDesign.subtitleStyle.copyWith(
                            color: AppDesign.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تبرعات مشابهة قد تكون مناسبة لاحتياجك',
                          style: AppDesign.captionStyle.copyWith(
                            color: AppDesign.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // Horizontal recommendations
              // --------------------------------------------------

              SizedBox(
                height: 340,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: recommendations.length,
                  itemBuilder: (context, index) {
                    return _buildRecommendedCard(
                      recommendations[index],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,

        // ======================================================
        // App Bar
        // ======================================================

        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'تفاصيل التبرع',
            style: AppDesign.h2Style.copyWith(
              color: AppDesign.textPrimary,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppDesign.background,
          foregroundColor: AppDesign.textPrimary,
          elevation: 0,
        ),

        // ======================================================
        // Body
        // ======================================================

        body: FutureBuilder<Map<String, dynamic>>(
          future: _donationDetailsFuture,
          builder: (context, snapshot) {
            // --------------------------------------------------
            // Loading
            // --------------------------------------------------

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // --------------------------------------------------
            // Error
            // --------------------------------------------------

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(
                    AppDesign.screenPadding,
                  ),
                  child: Text(
                    'حدث خطأ أثناء تحميل تفاصيل التبرع\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: AppDesign.bodyStyle.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            // --------------------------------------------------
            // No data
            // --------------------------------------------------

            if (!snapshot.hasData) {
              return Center(
                child: Text(
                  'لا توجد بيانات',
                  style: AppDesign.bodyStyle,
                ),
              );
            }

            // --------------------------------------------------
            // Data
            // --------------------------------------------------

            final boxData = snapshot.data!['box'] as Map<String, dynamic>;

            final items =
                snapshot.data!['items'] as List<Map<String, dynamic>>;

            final gender = (boxData['gender'] ?? '-').toString();

            final ageGroup =
                (boxData['ageGroup']?['label'] ?? '-').toString();

            final generalSize = (boxData['generalSize'] ?? '').toString();

            final numberOfItems = items.length;

            // ==================================================
            // Main Column
            // ==================================================

            return Column(
              children: [
                // ==================================================
                // Scrollable content
                // ==================================================

                Expanded(
                  child: SingleChildScrollView(
                    padding: AppPadding.screen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==========================================
                        // Main donation information
                        // ==========================================

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                            AppDesign.cardPadding,
                          ),
                          decoration: AppDesign.primaryCardDecoration,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Column(
                              children: [
                                _infoRow(
                                  Icons.wc_outlined,
                                  'الجنس',
                                  gender,
                                ),
                                const SizedBox(height: 12),
                                if (ageGroup.contains('بالغون'))
                                  _infoRow(
                                    Icons.straighten_outlined,
                                    'المقاس',
                                    generalSize.trim().isNotEmpty
                                        ? generalSize
                                        : '-',
                                  )
                                else
                                  _infoRow(
                                    Icons.cake_outlined,
                                    'الفئة العمرية',
                                    ageGroup,
                                  ),
                                const SizedBox(height: 12),
                                _infoRow(
                                  Icons.inventory_2_outlined,
                                  'عدد القطع',
                                  '$numberOfItems قطع',
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: AppDesign.spaceXL,
                        ),

                        // ==========================================
                        // Donation content title
                        // ==========================================

                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'محتوى التبرع',
                            textAlign: TextAlign.right,
                            style: AppDesign.subtitleStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppDesign.primary,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: AppDesign.spaceMD,
                        ),

                        // ==========================================
                        // Items
                        // ==========================================

                        if (items.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(
                              AppDesign.cardPadding,
                            ),
                            decoration: AppDesign.primaryCardDecoration,
                            child: Text(
                              'لا توجد قطع مرتبطة بهذا التبرع حالياً',
                              textAlign: TextAlign.center,
                              style: AppDesign.bodyStyle.copyWith(
                                color: AppDesign.textSecondary,
                              ),
                            ),
                          )
                        else
                          ...List.generate(
                            items.length,
                            (index) => _buildItemCard(
                              items[index],
                              index,
                            ),
                          ),

                        // ==========================================
                        // Recommended System
                        // ==========================================

                        _buildRecommendedSection(
                          boxData,
                        ),

                        const SizedBox(
                          height: AppDesign.space2XL,
                        ),
                      ],
                    ),
                  ),
                ),

                // ==================================================
                // Add to cart button - Live beneficiary status
                // ==================================================

                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _beneficiaryStatusStream,
                  builder: (context, beneficiarySnapshot) {
                    final beneficiaryData =
                        beneficiarySnapshot.data?.data();

                    final beneficiaryStatus =
                        (beneficiaryData?['status'] ?? 'pending')
                            .toString()
                            .trim()
                            .toLowerCase();

                    final isApproved =
                        beneficiarySnapshot.hasData &&
                        beneficiarySnapshot.data!.exists &&
                        beneficiaryStatus == 'approved';

                    final isLoadingStatus =
                        beneficiarySnapshot.connectionState ==
                            ConnectionState.waiting;

                    final canAddToCart =
                        isApproved && !_isAddingToCart;

                    return SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDesign.screenPadding,
                          0,
                          AppDesign.screenPadding,
                          AppDesign.screenPadding,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: AppDesign.buttonHeightMD,
                          child: ElevatedButton(
                            onPressed: canAddToCart
                                ? () => _addToCart(boxData)
                                : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _isAddingToCart
                                        ? 'جاري الإضافة...'
                                        : isLoadingStatus
                                            ? 'جاري التحقق من حالة المستفيد...'
                                            : isApproved
                                                ? 'إضافة إلى السلة'
                                                : 'بانتظار قبول طلب المستفيد',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_isAddingToCart ||
                                    isLoadingStatus)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.add_shopping_cart_outlined,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // Image Preview
  // ============================================================

  void _showImagePreview(
    Uint8List imageBytes,
  ) {
    final size = MediaQuery.of(context).size.width * 0.75;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
