class SubscriptionTrialSetupResult {
  final String setupIntentId;
  final String status;
  final String clientSecret;
  final String stripeCustomerId;
  final DateTime trialEndsAt;
  final String paymentMethodId;

  const SubscriptionTrialSetupResult({
    required this.setupIntentId,
    required this.status,
    required this.clientSecret,
    required this.stripeCustomerId,
    required this.trialEndsAt,
    required this.paymentMethodId,
  });

  factory SubscriptionTrialSetupResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionTrialSetupResult(
      setupIntentId: json['setup_intent_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      clientSecret: json['client_secret'] as String? ?? '',
      stripeCustomerId: json['stripe_customer_id'] as String? ?? '',
      trialEndsAt:
          DateTime.tryParse(json['trial_ends_at'] as String? ?? '') ??
          DateTime.now(),
      paymentMethodId: json['payment_method_id'] as String? ?? '',
    );
  }
}
