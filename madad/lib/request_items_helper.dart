import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';

/// Fetch items directly using requestId.
Future<List<Map<String, dynamic>>> fetchRequestItems(String requestId) async {
  final db = FirebaseFirestore.instance;

  final snapshot = await db
      .collection('items')
      .where('requestId', isEqualTo: requestId)
      .get();

  final List<Map<String, dynamic>> items = snapshot.docs.map((doc) {
    return <String, dynamic>{...doc.data(), 'itemId': doc.id};
  }).toList();

  // Box data is optional: if anything fails here, the items still load.
  try {
    final boxIds = items
        .map((i) => (i['boxId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final Map<String, Map<String, dynamic>> boxesData = {};

    for (final id in boxIds) {
      try {
        final snap = await db.collection('donation_boxes').doc(id).get();
        final data = snap.data();
        if (data != null) boxesData[id] = data;
      } catch (e) {
        debugPrint('BOX FETCH ERROR ($id): $e');
      }
    }

    for (final item in items) {
      final box = boxesData[(item['boxId'] ?? '').toString()];
      if (box == null) continue;

      item['gender'] = box['gender'];

      final rawAge = box['ageGroup'];
      item['ageGroup'] = rawAge is Map
          ? (rawAge['label'] ?? '').toString()
          : (rawAge ?? '').toString();

      final size = (item['size'] ?? '').toString().trim();
      if (size.isEmpty || size == 'null') {
        item['size'] = box['generalSize'];
      }
    }
  } catch (e) {
    debugPrint('REQUEST ITEMS ENRICH ERROR: $e');
  }

  int toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  items.sort((a, b) {
    final boxComparison = toInt(
      a['boxNumber'],
    ).compareTo(toInt(b['boxNumber']));
    if (boxComparison != 0) return boxComparison;
    return toInt(a['itemNumber']).compareTo(toInt(b['itemNumber']));
  });

  return items;
}

/// Expandable list of items inside the beneficiary request card.
class RequestItemsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const RequestItemsList({super.key, required this.items});

  String _clean(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s == 'null' ? '' : s;
  }

  String _ageLabel(dynamic raw) {
    if (raw is Map) return _clean(raw['label']);
    return _clean(raw);
  }

  String _itemTitle(Map<String, dynamic> item) {
    final type = _clean(item['type']);
    return type.isEmpty ? 'قطعة' : type;
  }

  List<String> _itemDetails(Map<String, dynamic> item) {
    final gender = _clean(item['gender']);
    final age = _ageLabel(item['ageGroup']);
    final size = _clean(item['size']);

    return [
      if (gender.isNotEmpty) 'الجنس: $gender',
      if (age.isNotEmpty) 'الفئة العمرية: $age',
      if (size.isNotEmpty) 'المقاس: $size',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppDesign.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesign.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: AppDesign.primary,
        collapsedIconColor: AppDesign.primary,
        title: Row(
          children: [
            const Icon(
              Icons.checkroom_outlined,
              color: AppDesign.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'القطع المرتبطة بالطلب',
                style: AppDesign.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppDesign.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length} قطع',
                style: const TextStyle(
                  color: AppDesign.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا توجد قطع مرتبطة بهذا الطلب'),
            )
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              final imageUrl = (item['imageUrl'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'القطعة ${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppDesign.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _itemTitle(item),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ..._itemDetails(item).map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                line,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppDesign.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 55,
      height: 55,
      color: AppDesign.secondary.withOpacity(0.15),
      child: const Icon(
        Icons.checkroom_outlined,
        color: AppDesign.primary,
        size: 25,
      ),
    );
  }
}

/// Sort key for tasks: newest first.
DateTime taskSortTime(
  Map<String, dynamic> data, {
  required bool isDonation,
  bool completed = false,
}) {
  dynamic raw;
  if (completed) raw = data['deliveredAt'];
  raw ??= isDonation
      ? (data['updatedAt'] ?? data['createdAt'])
      : data['createdAt'];

  if (raw is Timestamp) return raw.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}
