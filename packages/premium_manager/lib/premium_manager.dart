abstract interface class PremiumEntitlement {
  bool get isPremium;
}

class DemoPremiumEntitlement implements PremiumEntitlement {
  const DemoPremiumEntitlement({this.isPremium = false});
  @override
  final bool isPremium;
}
