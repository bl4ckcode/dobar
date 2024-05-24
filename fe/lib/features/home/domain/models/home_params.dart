class HomeParams {
  HomeParams({
    required this.identification,
  });

  late final String identification;

  HomeParams.fromJson(Map<String, dynamic> json) {
    identification = json['period'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['period'] = identification;
    return data;
  }
}
