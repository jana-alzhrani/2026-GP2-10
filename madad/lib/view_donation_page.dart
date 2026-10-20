import 'dart:convert';

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'app_design.dart';
import 'edit_donation_page.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ViewDonationPage extends StatefulWidget {
  final String userId;

  const ViewDonationPage({super.key, required this.userId});

  @override
  State<ViewDonationPage> createState() => _ViewDonationPageState();
}

class _ViewDonationPageState extends State<ViewDonationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _bottomNavIndex = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isDraftStatus(String status) {
    return status.toLowerCase() == 'draft';
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'مسودة';
      case 'published':
        return 'مؤكد';
      case 'available':
        return 'متاح';
      case 'reserved':
        return 'محجوز';
      case 'delivered':
        return 'تم التسليم';
      default:
        return status;
    }
  }

  String _formatDeliveryMethod(String method) {
    switch (method.toLowerCase()) {
      case 'pickup':
        return 'استلام من موقعي';
      case 'self_delivery':
        return 'توصيل ذاتي للمستودع';
      default:
        return 'غير محددة';
    }
  }

  Color _statusBackground(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return AppDesign.warning.withOpacity(0.35);
      case 'published':
        return AppDesign.softGreen.withOpacity(0.20);
      case 'available':
        return AppDesign.secondary.withOpacity(0.18);
      case 'reserved':
        return AppDesign.warning.withOpacity(0.35);
      case 'delivered':
        return AppDesign.softGreen.withOpacity(0.20);
      default:
        return AppDesign.surfaceAlt;
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return AppDesign.primary;
      case 'published':
        return AppDesign.success;
      case 'available':
        return AppDesign.primary;
      case 'reserved':
        return AppDesign.primary;
      case 'delivered':
        return AppDesign.success;
      default:
        return AppDesign.textPrimary;
    }
  }

  String formatBoxStatus(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'مسودة';
      case 'published':
        return 'مؤكد';
      case 'available':
        return 'متاح';
      case 'reserved':
        return 'تم الطلب';
      case 'delivered':
        return 'تم التسليم';
      default:
        return status;
    }
  }

  IconData getBoxStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Icons.edit_note_outlined;
      case 'published':
        return Icons.check_circle_outline;
      case 'available':
        return Icons.inventory_2_outlined;
      case 'reserved':
        return Icons.assignment_turned_in_outlined; // تم الطلب
      case 'delivered':
        return Icons.local_shipping_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color getBoxStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return AppDesign.warning;
      case 'published':
        return AppDesign.primary;
      case 'available':
        return AppDesign.softGreen;
      case 'reserved':
        return AppDesign.secondary;
      case 'delivered':
        return AppDesign.success;
      default:
        return AppDesign.textSecondary;
    }
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spaceMD,
        vertical: AppDesign.spaceSM,
      ),
      decoration: BoxDecoration(
        color: AppDesign.surfaceAlt,
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        border: Border.all(color: AppDesign.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDesign.iconSM, color: AppDesign.primary),
          const SizedBox(width: AppDesign.spaceSM),
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

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, size: 20, color: AppDesign.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppDesign.captionStyle.copyWith(
            color: AppDesign.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: AppDesign.bodyStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _deliveryChip(String method, {Widget? trailing}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: trailing != null ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        border: Border.all(color: AppDesign.border),
      ),
      child: Row(
        mainAxisSize: trailing != null ? MainAxisSize.max : MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: AppDesign.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            "طريقة التوصيل",
            style: AppDesign.captionStyle.copyWith(
              color: AppDesign.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          if (trailing != null)
            Expanded(
              child: Text(
                method,
                style: AppDesign.bodyStyle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Text(
              method,
              style: AppDesign.bodyStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// زر مسح الباركود (مربع على اليسار) لتأكيد التسليم للمستودع
  Widget _scanSquareButton(String donationId) {
    return Tooltip(
      message: 'مسح الباركود لتأكيد التسليم للمستودع',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DropoffScanPage(donationId: donationId),
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
    );
  }

  String generateBoxCode(int boxNumber) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      10,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<void> _deleteDonation(String docId) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'حذف التبرع',
      message: 'هل أنت متأكد من حذف هذا التبرع؟\n\n! لا يمكنك التراجع عن الحذف',
    );
    if (confirm != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أولاً')));
        return;
      }

      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(docId)
          .get();

      if (!donationDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('التبرع غير موجود')));
        return;
      }

      final donationData = donationDoc.data() as Map<String, dynamic>;
      final donorId = donationData['donorId']?.toString();

      if (donorId != currentUser.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكنك حذف تبرع لا يخصك')),
        );
        return;
      }

      final boxesSnapshot = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .where('donationId', isEqualTo: docId)
          .get();

      for (final boxDoc in boxesSnapshot.docs) {
        await boxDoc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('donations')
          .doc(docId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف التبرع بنجاح')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حذف التبرع: $e')));
    }
  }

  Future<void> _moveDraftToConfirmed(String docId) async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'تأكيد التبرع',
      message:
          'هل تريد اتمام هذا التبرع؟\n\n! بعد التأكيد لن تتمكن من التعديل أو الحذف',
    );

    if (confirm != true) return;

    try {
      // تحديث التاريخ والحالة في Firestore قبل الانتقال لصفحة التوصيل
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(docId)
          .update({
            'updatedAt': FieldValue.serverTimestamp(), // تحديث وقت التأكيد
          });

      if (!mounted) return;

      Navigator.pushNamed(context, '/donorDelivery', arguments: docId);
    } catch (e) {
      debugPrint("Error updating donation: $e");
    }
  }

  Future<void> _openEditDonation(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditDonationPage(
          donationId: doc.id,
          initialGender: data['gender']?.toString(),
          initialAgeGroupLabel: data['ageGroup']?.toString(),
          initialItemCount: (data['numberOfItems'] ?? 0) as int,
        ),
      ),
    );

    if (result == true && mounted) {
      AppDesign.showSuccessSnackBar(context, 'تم تحديث التبرع بنجاح');
    }
  }

  Future<void> printBoxLabel(String boxCode, String boxId) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(boxCode, style: pw.TextStyle(fontSize: 42)),
                pw.SizedBox(height: 10),
                pw.Text("ID: $boxId"),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> printAllBoxesLabels(List boxes) async {
    final pdf = pw.Document();

    final logoBytes = (await rootBundle.load(
      'assets/images/logo.png',
    )).buffer.asUint8List();

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: boxes.map((box) {
              final data = box.data() as Map<String, dynamic>;
              final boxCode = (data['boxCode'] ?? '---').toString();

              return pw.Container(
                width: 180,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(
                    color: PdfColor.fromHex("#0A4D5C"),
                    width: 1.5,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(logoImage, width: 70),
                    pw.SizedBox(height: 8),
                    pw.Container(height: 1, color: PdfColor.fromHex("#0A4D5C")),
                    pw.SizedBox(height: 8),

                    // QR فعلي يحتوي نص الـ boxCode (هذا اللي يتم مسحه)
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: boxCode,
                      width: 80,
                      height: 80,
                    ),
                    pw.SizedBox(height: 8),

                    pw.Text(
                      boxCode,
                      style: pw.TextStyle(
                        color: PdfColor.fromHex("#0A4D5C"),
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      "Donation ID",
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      (data['donationId'] ?? '').toString(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColor.fromHex("#0A4D5C"),
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// هل الصندوق لسا ما تم تسليمه للمستودع؟
  bool _boxNeedsDropoff(Map<String, dynamic> data) {
    final s = (data['status'] ?? '').toString().toLowerCase();
    return s != 'available' &&
        s != 'reserved' &&
        s != 'delivered' &&
        s != 'completed' &&
        s != 'draft';
  }

  Widget _buildDonationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final String gender = (data['gender'] ?? '-').toString();
    final String ageGroup = (data['ageGroup'] ?? '-').toString();
    final int numberOfItems = (data['numberOfItems'] ?? 0) as int;
    final String generalSize = (data['generalSize'] ?? '').toString();
    final String status = (data['status'] ?? '-').toString();
    final String deliveryMethod =
        (data['deliveryMethod'] ?? data['deliveryType'] ?? 'غير محدد')
            .toString();

    final bool isDraft = _isDraftStatus(status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesign.spaceLG),
      padding: const EdgeInsets.all(AppDesign.cardPadding),
      decoration: AppDesign.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'تبرع ($gender - $ageGroup)',
                  textAlign: TextAlign.right,
                  style: AppDesign.subtitleStyle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.spaceSM),
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _statusBackground(status),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    _formatStatus(status),
                    style: AppDesign.captionStyle.copyWith(
                      color: _statusTextColor(status),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.spaceSM),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppDesign.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppDesign.radiusMD),
                  border: Border.all(color: AppDesign.border),
                ),
                child: const Icon(
                  Icons.volunteer_activism,
                  color: AppDesign.primary,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDesign.spaceLG),

          Container(
            padding: const EdgeInsets.all(AppDesign.spaceMD),
            decoration: BoxDecoration(
              color: AppDesign.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusMD),
              border: Border.all(color: AppDesign.border),
            ),
            child: Column(
              children: [
                _infoRow(Icons.wc_outlined, "الجنس", gender),
                const SizedBox(height: 12),
                _infoRow(Icons.cake_outlined, "الفئة العمرية", ageGroup),
                if (generalSize.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoRow(Icons.straighten_outlined, "المقاس", generalSize),
                ],
                const SizedBox(height: 12),
                _infoRow(
                  Icons.inventory_2_outlined,
                  "عدد القطع",
                  "$numberOfItems قطع",
                ),
              ],
            ),
          ),

          if (!isDraft) ...[
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donation_boxes')
                  .where('donationId', isEqualTo: doc.id)
                  .snapshots(),
              builder: (context, snap) {
                final boxDocs = snap.data?.docs ?? [];

                // زر المسح: فقط للتوصيل الذاتي وإذا فيه صناديق لسا ما انسلمت
                final bool showScan =
                    deliveryMethod.toLowerCase() == 'self_delivery' &&
                    boxDocs.any(
                      (b) => _boxNeedsDropoff(b.data() as Map<String, dynamic>),
                    );

                final bool isPickup = deliveryMethod.toLowerCase() == 'pickup';

                // بيانات العنوان المرتبط بخيار الاستلام من الموقع
                final String city = (data['city'] ?? data['donorCity'] ?? '')
                    .toString()
                    .trim();
                final String district =
                    (data['district'] ??
                            data['neighborhood'] ??
                            data['donorDistrict'] ??
                            '')
                        .toString()
                        .trim();
                final String nationalAddress =
                    (data['nationalAddress'] ??
                            data['fullAddress'] ??
                            data['address'] ??
                            data['donorNationalAddress'] ??
                            '')
                        .toString()
                        .trim();

                return SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _deliveryChip(
                        _formatDeliveryMethod(deliveryMethod),
                        trailing: showScan ? _scanSquareButton(doc.id) : null,
                      ),
                      if (isPickup &&
                          (city.isNotEmpty ||
                              district.isNotEmpty ||
                              nationalAddress.isNotEmpty)) ...[
                        const SizedBox(height: AppDesign.spaceSM),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDesign.spaceMD),
                          decoration: BoxDecoration(
                            color: AppDesign.surface,
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusMD,
                            ),
                            border: Border.all(color: AppDesign.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'عنوان الاستلام',
                                textAlign: TextAlign.right,
                                style: AppDesign.captionStyle.copyWith(
                                  color: AppDesign.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (city.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.location_city_outlined,
                                  'المدينة',
                                  city,
                                ),
                              ],
                              if (district.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _infoRow(Icons.map_outlined, 'الحي', district),
                              ],
                              if (nationalAddress.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.home_outlined,
                                  'العنوان الوطني',
                                  nationalAddress,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppDesign.spaceLG),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donation_boxes')
                  .where('donationId', isEqualTo: doc.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "لا توجد صناديق",
                      textAlign: TextAlign.right,
                      style: AppDesign.captionStyle,
                    ),
                  );
                }

                final boxes = snapshot.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        " الصناديق",
                        textAlign: TextAlign.right,
                        style: AppDesign.subtitleStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppDesign.primary,
                        ),
                      ),
                    ),
                    ...boxes.map((box) {
                      final data = box.data() as Map<String, dynamic>;
                      final rawStatus = (data['status'] ?? '-').toString();
                      final status = formatBoxStatus(rawStatus);
                      final statusColor = getBoxStatusColor(rawStatus);
                      final statusIcon = getBoxStatusIcon(rawStatus);
                      final boxCode = (data['boxCode'] ?? '---').toString();
                      final items = data['items'] ?? [];

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: AppDesign.spaceSM,
                        ),
                        decoration: AppDesign.softCardDecoration,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spaceMD,
                            vertical: AppDesign.spaceSM,
                          ),
                          title: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 18,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    status,
                                    style: AppDesign.captionStyle.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              AppGap.wMD,
                              Expanded(
                                child: Text(
                                  boxCode,
                                  style: AppDesign.h2Style.copyWith(
                                    color: AppDesign.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppDesign.spaceMD),
                              child: Column(
                                children: List.generate(items.length, (index) {
                                  final item = items[index];

                                  return Container(
                                    margin: const EdgeInsets.only(
                                      bottom: AppDesign.spaceSM,
                                    ),
                                    padding: const EdgeInsets.all(
                                      AppDesign.spaceSM,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppDesign.surface,
                                      borderRadius: BorderRadius.circular(
                                        AppDesign.radiusMD,
                                      ),
                                      border: Border.all(
                                        color: AppDesign.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        /// 🖼️ صورة القطعة
                                        (item['imageUrl'] != null &&
                                                item['imageUrl']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppDesign.radiusSM,
                                                    ),
                                                child: Image.network(
                                                  item['imageUrl'],
                                                  width: 55,
                                                  height: 55,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Container(
                                                          width: 55,
                                                          height: 55,
                                                          color: AppDesign
                                                              .surfaceAlt,
                                                          child: const Icon(
                                                            Icons.broken_image,
                                                          ),
                                                        );
                                                      },
                                                ),
                                              )
                                            : Container(
                                                width: 55,
                                                height: 55,
                                                decoration: BoxDecoration(
                                                  color: AppDesign.surfaceAlt,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppDesign.radiusSM,
                                                      ),
                                                ),
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                        AppGap.wMD,
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "القطعة ${index + 1}",
                                                style: AppDesign.bodyStyle
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item['type'] ?? '-',
                                                style: AppDesign.captionStyle,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    AppGap.md,

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text("طباعة جميع الملصقات"),
                        onPressed: () {
                          printAllBoxesLabels(boxes);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: AppDesign.spaceSM),

          if (isDraft)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditDonation(doc),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: AppDesign.spaceSM),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteDonation(doc.id),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: AppDesign.error,
                      side: const BorderSide(color: AppDesign.error),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف'),
                  ),
                ),
                const SizedBox(width: AppDesign.spaceSM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _moveDraftToConfirmed(doc.id),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDonationsList(bool draftsOnly) {
    String sortField = draftsOnly ? 'createdAt' : 'updatedAt';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: widget.userId)
          .orderBy(sortField, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ في تحميل التبرعات',
              style: AppDesign.bodyStyle.copyWith(color: AppDesign.primary),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          return draftsOnly ? _isDraftStatus(status) : !_isDraftStatus(status);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  draftsOnly
                      ? Icons.description_outlined
                      : Icons.volunteer_activism_outlined,
                  size: AppDesign.iconLG + 20,
                  color: AppDesign.secondary,
                ),
                const SizedBox(height: AppDesign.spaceMD),
                Text(
                  draftsOnly
                      ? 'لا توجد مسودات حالياً'
                      : 'لا توجد تبرعات حالياً',
                  style: AppDesign.subtitleStyle.copyWith(
                    color: AppDesign.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDesign.screenPadding),
          itemCount: filteredDocs.length,
          itemBuilder: (_, index) => _buildDonationCard(filteredDocs[index]),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
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
        selectedIndex: _bottomNavIndex,
        backgroundColor: Colors.transparent,
        indicatorColor: AppDesign.secondary.withOpacity(0.16),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == _bottomNavIndex && index == 1) return;

          setState(() {
            _bottomNavIndex = index;
          });

          if (index == 0) {
            Navigator.pushReplacementNamed(
              context,
              '/donorHome',
              arguments: widget.userId,
            );
          } else if (index == 2) {
            Navigator.pushReplacementNamed(
              context,
              '/donorMore',
              arguments: widget.userId,
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppDesign.primary),
            selectedIcon: Icon(Icons.home_rounded, color: AppDesign.primary),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.volunteer_activism_outlined,
              color: AppDesign.primary,
            ),
            selectedIcon: Icon(
              Icons.volunteer_activism_rounded,
              color: AppDesign.primary,
            ),
            label: 'تبرعاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded, color: AppDesign.primary),
            selectedIcon: Icon(
              Icons.more_horiz_rounded,
              color: AppDesign.primary,
            ),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppDesign.background,
                AppDesign.surfaceAlt,
                AppDesign.background,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDesign.screenPadding,
                    AppDesign.screenPadding,
                    AppDesign.screenPadding,
                    AppDesign.spaceMD,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'تبرعاتي',
                        textAlign: TextAlign.center,
                        style: AppDesign.h1Style.copyWith(
                          color: AppDesign.primary,
                        ),
                      ),
                      const SizedBox(height: AppDesign.spaceXS),
                      Text(
                        'إدارة المسودات والتبرعات النشطة',
                        textAlign: TextAlign.center,
                        style: AppDesign.bodySecondaryStyle,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesign.screenPadding,
                  ),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.all(AppDesign.spaceXS),
                    decoration: BoxDecoration(
                      color: AppDesign.white,
                      borderRadius: BorderRadius.circular(AppDesign.radiusLG),
                      border: Border.all(color: AppDesign.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppDesign.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppDesign.primary,
                        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
                      ),
                      labelColor: AppDesign.white,
                      unselectedLabelColor: AppDesign.primary,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(
                        AppDesign.radiusMD,
                      ),
                      labelStyle: AppDesign.bodyStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(text: 'التبرعات النشطة'),
                        Tab(text: 'المسودات'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDesign.spaceSM),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDonationsList(false),
                      _buildDonationsList(true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }
}

/// ═════════ صفحة مسح الباركود لتأكيد التسليم للمستودع ═════════
/// ترجع true إذا تم تسليم كل صناديق التبرع.
class DropoffScanPage extends StatefulWidget {
  final String donationId;

  const DropoffScanPage({super.key, required this.donationId});

  @override
  State<DropoffScanPage> createState() => _DropoffScanPageState();
}

class _DropoffScanPageState extends State<DropoffScanPage> {
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
      final db = FirebaseFirestore.instance;

      final snap = await db
          .collection('donation_boxes')
          .where('donationId', isEqualTo: widget.donationId)
          .get();

      // دوّر على الصندوق اللي كوده يطابق الباركود
      QueryDocumentSnapshot<Map<String, dynamic>>? match;
      for (final d in snap.docs) {
        final code = (d.data()['boxCode'] ?? '').toString();
        if (_normalize(code) == _normalize(raw)) {
          match = d;
          break;
        }
      }

      if (match == null) {
        _toast('هذا الباركود لا يخص هذا التبرع', error: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _busy = false);
        return;
      }

      if (match.data()['status'] == 'available') {
        _toast('تم تأكيد تسليم هذا الصندوق مسبقاً', error: true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _busy = false);
        return;
      }

      // 1) الصندوق -> متاح
      await match.reference.update({
        'status': 'available',
        'receivedAtWarehouse': FieldValue.serverTimestamp(),
      });

      // 2) إذا كل الصناديق صارت متاحة، التبرع -> متاح
      final remaining = snap.docs
          .where((d) => d.id != match!.id && d.data()['status'] != 'available')
          .toList();

      final allDone = remaining.isEmpty;

      if (allDone) {
        await db.collection('donations').doc(widget.donationId).update({
          'status': 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      await _showSuccessDialog(
        allDone
            ? 'تم تسليم التبرع بالكامل للمستودع'
            : 'تم تسليم الصندوق، باقي ${remaining.length}',
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
          title: const Text('تأكيد التسليم للمستودع'),
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
            MobileScanner(controller: _controller, onDetect: _onDetect),
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
                  'وجّه الكاميرا نحو باركود الصندوق لتأكيد تسليمه',
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
