class GapRecommendation {
  final String type; // 'hostel', 'canteen', 'stay_short', 'stay_none', 'at_hostel'
  final String message;
  final int gapMinutes;

  GapRecommendation({
    required this.type,
    required this.message,
    required this.gapMinutes,
  });
}

const int hostelEatBuffer = 30;
const int canteenEatBuffer = 20;
const int safetyMargin = 10;

GapRecommendation computeRecommendation({
  required String currentLocationId,
  required String nextLocationId,
  required int gapMinutes,
  required String hostelId,
  required List<String> canteenIds,
  required Map<String, Map<String, dynamic>> distanceMatrix,
  required bool messWindowActiveDuringGap,
}) {
  int? walk(String from, String to) {
    final v = distanceMatrix[from]?[to];
    if (v == null) return null;
    return (v as num).round();
  }

  // Already at the hostel — no "go eat" recommendation needed, just a heads up.
  if (currentLocationId == hostelId) {
    return GapRecommendation(
      type: 'at_hostel',
      message: "You're at the hostel. Head out in time for your next class.",
      gapMinutes: gapMinutes,
    );
  }

  final toHostel = walk(currentLocationId, hostelId);
  final hostelToNext = walk(hostelId, nextLocationId);
  int? hostelRoundTrip;
  if (toHostel != null && hostelToNext != null) {
    hostelRoundTrip = toHostel + hostelEatBuffer + hostelToNext + safetyMargin;
  }

  if (hostelRoundTrip != null &&
      gapMinutes >= hostelRoundTrip &&
      messWindowActiveDuringGap) {
    return GapRecommendation(
      type: 'hostel',
      message:
          "You have $gapMinutes min — enough time to go back to your hostel mess and return with time to spare.",
      gapMinutes: gapMinutes,
    );
  }

  // Try every canteen, pick the cheapest feasible round trip.
  String? bestCanteen;
  int? bestRoundTrip;
  for (final canteenId in canteenIds) {
    final toCanteen = walk(currentLocationId, canteenId);
    final canteenToNext = walk(canteenId, nextLocationId);
    if (toCanteen == null || canteenToNext == null) continue;
    final roundTrip = toCanteen + canteenEatBuffer + canteenToNext + safetyMargin;
    if (bestRoundTrip == null || roundTrip < bestRoundTrip) {
      bestRoundTrip = roundTrip;
      bestCanteen = canteenId;
    }
  }

  if (bestRoundTrip != null && gapMinutes >= bestRoundTrip) {
    final name = bestCanteen!.replaceAll('_', ' ');
    return GapRecommendation(
      type: 'canteen',
      message:
          "You have $gapMinutes min — enough time to grab something at $name and get back comfortably.",
      gapMinutes: gapMinutes,
    );
  }

  if (gapMinutes >= 20) {
    return GapRecommendation(
      type: 'stay_short',
      message:
          "You have $gapMinutes min — not quite enough for a full trip. Grab something close by if there's an option, otherwise stay put.",
      gapMinutes: gapMinutes,
    );
  }

  return GapRecommendation(
    type: 'stay_none',
    message: "Only $gapMinutes min until your next class — stay put.",
    gapMinutes: gapMinutes,
  );
}