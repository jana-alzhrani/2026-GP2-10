import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';

// ======================================================================
// صفحة "طلبات تغيير رقم الجوال" (تفتح من خانة في هوم الأدمن)
// - يعرض الطلبات المعلّقة (مندوب / مستفيد) لحظياً
// - موافقة: تفتح للمستخدم نافذة تغيير الرقم لمدة أسبوع + يوصله إشعار
// - رفض: يوصله إشعار بالرفض
// ======================================================================

class AdminPhoneRequestsPage extends StatefulWidget {
  final String adminId;

  const AdminPhoneRequestsPage({super.key, required this.adminId});

  @override
  State<AdminPhoneRequestsPage> createState() => _AdminPhoneRequestsPageState();
}

class _AdminPhoneRequestsPageState extends State<AdminPhoneRequestsPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();

    // بدون orderBy عشان ما نحتاج Index. نرتب في الكود.
    _stream = FirebaseFirestore.instance
        .collection('phone_change_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // ───────────────────────── مساعدات ─────────────────────────

  DateTime _requestedAtOf(Map<String, dynamic> data) {
    final v = data['requestedAt'];
    return v is Timestamp ? v.toDate() : DateTime.now();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'courier':
        return 'مندوب';
      case 'beneficiary':
        return 'مستفيد';
      default:
        return 'مستخدم';
    }
  }

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');

    return '${d.year}/$m/$day  $h:$min';
  }

  String _nameOf(Map<String, dynamic> data) {
    final name = (data['userName'] ?? '').toString().trim();
    return name.isEmpty ? 'مستخدم' : name;
  }

  // ───────────────────────── موافقة ─────────────────────────

  Future<void> _approve(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final userId = (data['userId'] ?? '').toString();

    if (userId.isEmpty || _busyIds.contains(doc.id)) return;

    final confirmed = await AppDesign.showAppDialog(
      context: context,
      title: 'الموافقة على الطلب',
      message: 'سيتمكن المستخدم من تغيير رقم جواله هل انت متاكد؟',
      confirmText: 'موافقة',
      cancelText: 'إلغاء',
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(doc.id));

    try {
      final db = FirebaseFirestore.instance;

      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      );

      final batch = db.batch();

      // 1) تحديث الطلب
      batch.update(doc.reference, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': widget.adminId,
        'expiresAt': expiresAt,
      });

      // 2) السماح بتغيير الرقم لمدة 7 أيام
      batch.set(db.collection('Users').doc(userId), {
        'phoneChangeAllowedUntil': expiresAt,
      }, SetOptions(merge: true));

      // 3) إرسال إشعار للمستخدم
      batch.set(db.collection('notifications').doc(), {
        'userId': userId,
        'type': 'phone_change_approved',
        'title': 'تمت الموافقة على طلبك',
        'message':
            'وافق الأدمن على طلب تغيير رقم جوالك. يمكنك تغييره من صفحة المزيد خلال 7 أيام، وبعدها ستحتاج لتقديم طلب جديد.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      AppDesign.showSuccessSnackBar(context, 'تمت الموافقة وإرسال الإشعار');
    } catch (e) {
      debugPrint('Approve phone change error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, 'تعذّرت الموافقة. حاول مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(doc.id));
      }
    }
  }

  // ───────────────────────── رفض ─────────────────────────

  Future<void> _reject(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final userId = (data['userId'] ?? '').toString();

    if (userId.isEmpty || _busyIds.contains(doc.id)) return;

    final confirmed = await AppDesign.showAppDialog(
      context: context,
      title: 'رفض الطلب',
      message: 'هل تريد رفض طلب تغيير رقم الجوال لهذا المستخدم ؟',
      confirmText: 'رفض',
      cancelText: 'إلغاء',
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(doc.id));

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // تحديث حالة الطلب
      batch.update(doc.reference, {
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': widget.adminId,
      });

      // إرسال إشعار بالرفض
      batch.set(db.collection('notifications').doc(), {
        'userId': userId,
        'type': 'phone_change_rejected',
        'title': 'تم رفض طلبك',
        'message':
            'تم رفض طلب تغيير رقم الجوال. يمكنك تقديم طلب جديد من صفحة المزيد.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      AppDesign.showSuccessSnackBar(context, 'تم رفض الطلب');
    } catch (e) {
      debugPrint('Reject phone change error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, 'تعذّر رفض الطلب. حاول مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(doc.id));
      }
    }
  }

  // ───────────────────────── الواجهة ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),

              const SizedBox(height: 18),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppDesign.primary,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'تعذّر تحميل طلبات تغيير رقم الجوال',
                          style: AppDesign.bodySecondaryStyle,
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs.toList() ?? [];

                    // ترتيب الطلبات من الأحدث إلى الأقدم
                    docs.sort(
                      (a, b) => _requestedAtOf(
                        b.data(),
                      ).compareTo(_requestedAtOf(a.data())),
                    );

                    if (docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildRequestTile(docs[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── عنوان الصفحة ─────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: Text(
                'طلبات تغيير رقم الجوال',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppDesign.fontFamily,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppDesign.primary,
                ),
              ),
            ),

            Positioned(
              left: 0,
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back,
                  textDirection: TextDirection.ltr,
                  color: AppDesign.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── حالة عدم وجود طلبات ─────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.phone_android_rounded,
              size: 68,
              color: AppDesign.textSecondary,
            ),
            AppGap.md,
            Text(
              'لا توجد طلبات تغيير رقم جوال حاليًا',
              textAlign: TextAlign.center,
              style: AppDesign.h2Style,
            ),
            AppGap.sm,
            Text(
              'ستظهر هنا طلبات تغيير الأرقام المقدمة من المناديب والمستفيدين',
              textAlign: TextAlign.center,
              style: AppDesign.bodySecondaryStyle,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── بطاقة الطلب ─────────────────────────

  Widget _buildRequestTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final busy = _busyIds.contains(doc.id);

    final role = (data['userRole'] ?? '').toString();

    final oldPhone = (data['oldPhone'] ?? '').toString().trim();

    final name = _nameOf(data);

    final firstLetter = name.trim().isNotEmpty ? name.trim()[0] : 'م';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesign.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppDesign.secondary.withOpacity(0.17),
                child: Text(
                  firstLetter,
                  style: AppDesign.h1Style.copyWith(
                    color: AppDesign.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesign.h1Style.copyWith(
                        color: AppDesign.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: AppDesign.textSecondary,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            oldPhone.isEmpty
                                ? 'الرقم الحالي: غير متوفر'
                                : oldPhone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppDesign.bodyStyle.copyWith(
                              color: AppDesign.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 7),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppDesign.secondary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _roleLabel(role),
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Divider(color: AppDesign.border, height: 1),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppDesign.primary,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text('تاريخ الطلب', style: AppDesign.bodySecondaryStyle),
              ),

              Text(
                _formatDate(_requestedAtOf(data)),
                style: AppDesign.bodyStyle.copyWith(
                  color: AppDesign.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // أزرار الرفض والموافقة
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _reject(doc),
                    icon: const Icon(Icons.close_rounded, size: 19),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: AppDesign.bodyStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : () => _approve(doc),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppDesign.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 19),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.primary,
                      foregroundColor: AppDesign.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: AppDesign.bodyStyle.copyWith(
                        color: AppDesign.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
