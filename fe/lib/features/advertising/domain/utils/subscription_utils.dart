int calculateProrationCredit({
  required int planPriceCents,
  required DateTime cycleStart,
  required DateTime cycleEnd,
  required DateTime upgradeDate,
}) {
  final totalDays = cycleEnd.difference(cycleStart).inDays;
  // If cycle is less than a day (unlikely but safe), return 0
  if (totalDays <= 0) return 0;

  final usedDays = upgradeDate.difference(cycleStart).inDays;
  final remainingDays = totalDays - usedDays;

  // Credit for unused days
  if (remainingDays <= 0) return 0;

  return ((planPriceCents / totalDays) * remainingDays).round();
}
