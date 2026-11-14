import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'app_design.dart';
import 'edit_donation_page.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ViewDonationPage extends StatefulWidget {
  final String userId;

  const ViewDonationPage({
    super.key,
    required this.userId,
  });

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
      return 'تم الطلب'; // ✅ التعديل هنا
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

      Text(
        value,
        style: AppDesign.bodyStyle.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
Widget _deliveryChip(String method) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    decoration: BoxDecoration(
      color: AppDesign.surface,
      borderRadius: BorderRadius.circular(AppDesign.radiusMD),
      border: Border.all(color: AppDesign.border),
    ),
    child: Row(
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

        Text(
          method,
          style: AppDesign.bodyStyle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
  String generateBoxCode(String boxId, int boxNumber) {
  final shortId = boxId.substring(0, 5).toUpperCase();
  return "BOX$boxNumber-$shortId";
}

  Future<void> _deleteDonation(String docId) async {
 final confirm = await AppDesign.showAppDialog(
  context: context,
  title: 'حذف التبرع',
  message: 'هل أنت متأكد من حذف هذا التبرع؟\n\n! لا يمكنك التراجع عن الحذف',);
    if (confirm != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
        );
        return;
      }

      final donationDoc = await FirebaseFirestore.instance
          .collection('donations')
          .doc(docId)
          .get();

      if (!donationDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('التبرع غير موجود')),
        );
        return;
      }

      final donationData = donationDoc.data() as Map<String, dynamic>;
      final donorId = donationData['donorID']?.toString();

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف التبرع بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف التبرع: $e')),
      );
    }
  }

Future<void> _moveDraftToConfirmed(String docId) async {
  final confirm = await AppDesign.showAppDialog(
    context: context,
    title: 'تأكيد التبرع',
    message: 'هل تريد اتمام هذا التبرع؟\n\n! بعد التأكيد لن تتمكن من التعديل أو الحذف',
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
    
    Navigator.pushNamed(
      context, '/deliveryMethod',
      arguments: docId,
    );
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
      AppDesign.showSuccessSnackBar(
  context,'تم تحديث التبرع بنجاح',
      );
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
                pw.Text(
                  boxCode,
                  style: pw.TextStyle(fontSize: 42),
                ),
                pw.SizedBox(height: 10),
                pw.Text("ID: $boxId"),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
Future<void> printAllBoxesLabels(List boxes) async {
  final pdf = pw.Document();

  final logoBytes =
      (await rootBundle.load('assets/images/logo.png'))
          .buffer
          .asUint8List();

  final logoImage = pw.MemoryImage(logoBytes);

  pdf.addPage(
    pw.Page(
      build: (context) {
        return pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: boxes.map((box) {
            final data = box.data() as Map<String, dynamic>;
            final boxNumber = data['boxNumber'] ?? 0;
            final boxCode = data['boxCode'] ?? '---';

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

      
      pw.Image(
        logoImage,
        width: 70,
      ),

      pw.SizedBox(height: 8),

      
      pw.Container(
        height: 1,
        color: PdfColor.fromHex("#0A4D5C"),
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
        data['donationId'] ?? '',
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

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}

  Widget _buildDonationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final String gender = (data['gender'] ?? '-').toString();
    final String ageGroup = (data['ageGroup'] ?? '-').toString();
    final int numberOfItems = (data['numberOfItems'] ?? 0) as int;
    final String generalSize =
    (data['generalSize'] ?? '').toString();
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

      _infoRow(
        Icons.wc_outlined,
        "الجنس",
        gender,
      ),

      const SizedBox(height: 12),

      _infoRow(
        Icons.cake_outlined,
        "الفئة العمرية",
        ageGroup,
      ),

      if (generalSize.isNotEmpty) ...[
  const SizedBox(height: 12),

  _infoRow(
    Icons.straighten_outlined,
    "المقاس",
    generalSize,
  ),
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
            Align(
              alignment: Alignment.centerRight,
              child: _deliveryChip(_formatDeliveryMethod(deliveryMethod)),
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
  final boxCode = data['boxCode'] ?? '---';
  final parts = boxCode.split('-');
  final leftPart = parts.isNotEmpty ? parts[0] : '';
  final rightPart = parts.length >= 2 ? parts[1] : '';
  final items = data['items'] ?? [];

  

  return Container(
    margin: const EdgeInsets.only(bottom: AppDesign.spaceSM),
    decoration: AppDesign.softCardDecoration,
    child: ExpansionTile(

      
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spaceMD,
        vertical: AppDesign.spaceSM,
      ),

      
      title: Row(
        children: [

          
Row(
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
            child: RichText(
            textAlign: TextAlign.left,
             text: TextSpan(
                children: [
                  TextSpan(
                    text: leftPart,
                    style: AppDesign.h2Style.copyWith(
                    color: AppDesign.primary,
                      fontWeight: FontWeight.bold,
                  ),
                 ),
                TextSpan(
                text: rightPart.isNotEmpty ? '-$rightPart' : '',
                style: AppDesign.h2Style.copyWith(
               color: AppDesign.secondary,
                fontWeight: FontWeight.bold,
             ),
            ),
          ],
         ),
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
                margin: const EdgeInsets.only(bottom: AppDesign.spaceSM),
                padding: const EdgeInsets.all(AppDesign.spaceSM),
                decoration: BoxDecoration(
                  color: AppDesign.surface,
                  borderRadius: BorderRadius.circular(AppDesign.radiusMD),
                  border: Border.all(color: AppDesign.border),
                ),
                child: Row(
                  children: [

                    /// 🖼️ صورة القطعة
                  (item['imageUrl'] != null &&
        item['imageUrl'].toString().isNotEmpty)
    ? ClipRRect(
        borderRadius: BorderRadius.circular(AppDesign.radiusSM),
        child: Image.network(
          item['imageUrl'],
          width: 55,
          height: 55,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 55,
              height: 55,
              color: AppDesign.surfaceAlt,
              child: const Icon(Icons.broken_image),
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
                                  BorderRadius.circular(AppDesign.radiusSM),
                            ),
                            child: const Icon(Icons.image_not_supported),
                          ),

                    AppGap.wMD,

                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "القطعة ${index + 1}",
                            style: AppDesign.bodyStyle.copyWith(
                              fontWeight: FontWeight.w700,
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
  padding: const EdgeInsets.symmetric(
    vertical: 10,
  ),
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
                       padding: const EdgeInsets.symmetric(
    vertical: 10,
  ),
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
  padding: const EdgeInsets.symmetric(
    vertical: 10,
  ),
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
          .where('donorID', isEqualTo: widget.userId)
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
            selectedIcon:
                Icon(Icons.more_horiz_rounded, color: AppDesign.primary),
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
                      splashBorderRadius:
                          BorderRadius.circular(AppDesign.radiusMD),
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
