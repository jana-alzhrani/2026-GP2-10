import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ================================================================
// SETTINGS
// ================================================================

const String kRequestsCollection = 'requests';
const String kRequestOwnerField = 'beneficiaryId';
const String kRequestDateField = 'createdAt';
const String kRequestItemsCountField = 'itemsCount';

/// Cancelled and rejected requests do not count toward the item quota.
const Set<String> kIgnoredRequestStatuses = {'cancelled', 'rejected'};

/// One quota period starts with the beneficiary's first request and lasts 90 days.
const int kLimitPeriodDays = 90;

/// Maximum number of items a beneficiary can receive in one period.
const int kMaxItemsPerPeriod = 30;

// ================================================================
// RESULT
// ================================================================

class OrderLimits {
  final int maxItemsPerPeriod;
  final int itemsUsed;
  final DateTime? cycleEnd;

  const OrderLimits({
    required this.maxItemsPerPeriod,
    required this.itemsUsed,
    required this.cycleEnd,
  });

  int get itemsRemaining =>
      (maxItemsPerPeriod - itemsUsed).clamp(0, maxItemsPerPeriod);

  bool exceedsItems(int count) => count > itemsRemaining;

  int? get daysUntilReset {
    final end = cycleEnd;
    if (end == null) return null;

    final hours = end.difference(DateTime.now()).inHours;
    if (hours <= 0) return 0;
    return (hours / 24).ceil();
  }

  String get itemsMessage => itemsRemaining == 0
      ? 'وصلت للحد الأقصى ($maxItemsPerPeriod قطعة) خلال $kLimitPeriodDays يومًا'
      : 'المتبقي لك $itemsRemaining قطعة فقط من أصل $maxItemsPerPeriod خلال $kLimitPeriodDays يومًا';
}

// ================================================================
// SERVICE
// ================================================================

class OrderLimitsService {
  /// One-time quota fetch. Kept for pages that only need a fresh check.
  static Future<OrderLimits> fetch(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection(kRequestsCollection)
        .where(kRequestOwnerField, isEqualTo: userId)
        .get();

    return _calculate(snap.docs);
  }

  /// Live quota stream.
  ///
  /// Whenever a request for this beneficiary is added, edited, or deleted
  /// in Firestore, the quota is recalculated and the UI receives a new value.
  static Stream<OrderLimits> watch(String userId) {
    return FirebaseFirestore.instance
        .collection(kRequestsCollection)
        .where(kRequestOwnerField, isEqualTo: userId)
        .snapshots()
        .map((snapshot) => _calculate(snapshot.docs));
  }

  static OrderLimits _calculate(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final requests = <({DateTime date, int items})>[];

    for (final doc in documents) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString();
      if (kIgnoredRequestStatuses.contains(status)) continue;

      final created = (data[kRequestDateField] as Timestamp?)?.toDate();
      if (created == null) continue;

      requests.add((
        date: created,
        items: (data[kRequestItemsCountField] as num?)?.toInt() ?? 0,
      ));
    }

    requests.sort((a, b) => a.date.compareTo(b.date));

    const period = Duration(days: kLimitPeriodDays);
    DateTime? cycleStart;
    var itemsUsed = 0;

    for (final request in requests) {
      if (cycleStart == null ||
          !request.date.isBefore(cycleStart.add(period))) {
        cycleStart = request.date;
        itemsUsed = 0;
      }
      itemsUsed += request.items;
    }

    DateTime? cycleEnd;
    if (cycleStart != null && DateTime.now().isBefore(cycleStart.add(period))) {
      cycleEnd = cycleStart.add(period);
    } else {
      // The previous period has ended, or the beneficiary has no requests.
      itemsUsed = 0;
    }

    return OrderLimits(
      maxItemsPerPeriod: kMaxItemsPerPeriod,
      itemsUsed: itemsUsed,
      cycleEnd: cycleEnd,
    );
  }

  /// Returns null on error for one-time fetches, so technical problems
  /// do not block the user.
  static Future<OrderLimits?> tryFetch(String userId) async {
    try {
      return await fetch(userId);
    } catch (e) {
      debugPrint('ORDER LIMITS ERROR: $e');
      return null;
    }
  }
}
