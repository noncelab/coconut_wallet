class ElectrumDomain {
  final String domain;
  final int port;
  final bool ssl;

  const ElectrumDomain({
    required this.domain,
    required this.port,
    required this.ssl,
  });

  factory ElectrumDomain.fromJson(Map<String, dynamic> json) {
    return ElectrumDomain(
      domain: json['domain'] as String,
      port: json['port'] as int,
      ssl: json['ssl'] as bool,
    );
  }
}

class ElectrumDomainsResponse {
  final List<ElectrumDomain> domains;

  ElectrumDomainsResponse({required this.domains});

  factory ElectrumDomainsResponse.fromJson(List<dynamic> json) {
    return ElectrumDomainsResponse(
      domains: json.map((e) => ElectrumDomain.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
