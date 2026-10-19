enum UserRole {
  admin,
  coAdmin,
  agent,
}

class StaffAgent {
  final String id;
  final String name;
  final String pin;
  final String? phone;

  StaffAgent({
    required this.id,
    required this.name,
    required this.pin,
    this.phone,
  });

  factory StaffAgent.fromJson(Map<String, dynamic> json) {
    return StaffAgent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Agent',
      pin: json['pin']?.toString() ?? '0000',
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pin': pin,
      if (phone != null) 'phone': phone,
    };
  }
}

class SecuritySettings {
  final String vaultId; // Unique UUID for complete database isolation
  final bool isRegistered;
  final String firmName;
  final String adminName;
  final String adminPin;
  final String? coAdminPin;
  final String securityQuestion;
  final String securityAnswer;
  final String ownerUpiId;
  final List<StaffAgent> agents;
  final String supabaseUrl;
  final String supabaseKey;
  final bool cloudSyncEnabled;
  final bool useCustomCloud;
  final String customSupabaseUrl;
  final String customSupabaseKey;
  final String language; // 'en', 'te', 'hi', 'ta', 'kn'

  SecuritySettings({
    this.vaultId = '',
    this.isRegistered = false,
    this.firmName = 'FinVault',
    this.adminName = 'Admin',
    this.adminPin = '1234',
    this.coAdminPin,
    this.securityQuestion = 'City where business was started?',
    this.securityAnswer = 'chennai',
    this.ownerUpiId = 'owner@okhdfcbank',
    this.agents = const [],
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.cloudSyncEnabled = false,
    this.useCustomCloud = false,
    this.customSupabaseUrl = '',
    this.customSupabaseKey = '',
    this.language = 'en',
  });

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    var rawAgents = json['agents'];
    List<StaffAgent> parsedAgents = [];
    if (rawAgents is List) {
      parsedAgents = rawAgents
          .map((a) => StaffAgent.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    }

    return SecuritySettings(
      vaultId: json['vaultId']?.toString() ?? '',
      isRegistered: json['isRegistered'] ?? false,
      firmName: json['firmName']?.toString() ?? 'FinVault',
      adminName: json['adminName']?.toString() ?? 'Admin',
      adminPin: json['adminPin']?.toString() ?? '1234',
      coAdminPin: json['coAdminPin']?.toString(),
      securityQuestion: json['securityQuestion']?.toString() ?? 'City where business was started?',
      securityAnswer: json['securityAnswer']?.toString() ?? 'chennai',
      ownerUpiId: json['ownerUpiId']?.toString() ?? 'owner@okhdfcbank',
      agents: parsedAgents,
      supabaseUrl: json['supabaseUrl']?.toString() ?? '',
      supabaseKey: json['supabaseKey']?.toString() ?? '',
      cloudSyncEnabled: json['cloudSyncEnabled'] ?? false,
      useCustomCloud: json['useCustomCloud'] ?? false,
      customSupabaseUrl: json['customSupabaseUrl']?.toString() ?? '',
      customSupabaseKey: json['customSupabaseKey']?.toString() ?? '',
      language: json['language']?.toString() ?? 'en',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vaultId': vaultId,
      'isRegistered': isRegistered,
      'firmName': firmName,
      'adminName': adminName,
      'adminPin': adminPin,
      if (coAdminPin != null) 'coAdminPin': coAdminPin,
      'securityQuestion': securityQuestion,
      'securityAnswer': securityAnswer,
      'ownerUpiId': ownerUpiId,
      'agents': agents.map((a) => a.toJson()).toList(),
      'supabaseUrl': supabaseUrl,
      'supabaseKey': supabaseKey,
      'cloudSyncEnabled': cloudSyncEnabled,
      'useCustomCloud': useCustomCloud,
      'customSupabaseUrl': customSupabaseUrl,
      'customSupabaseKey': customSupabaseKey,
      'language': language,
    };
  }

  SecuritySettings copyWith({
    String? vaultId,
    bool? isRegistered,
    String? firmName,
    String? adminName,
    String? adminPin,
    String? coAdminPin,
    String? securityQuestion,
    String? securityAnswer,
    String? ownerUpiId,
    List<StaffAgent>? agents,
    String? supabaseUrl,
    String? supabaseKey,
    bool? cloudSyncEnabled,
    bool? useCustomCloud,
    String? customSupabaseUrl,
    String? customSupabaseKey,
    String? language,
  }) {
    return SecuritySettings(
      vaultId: vaultId ?? this.vaultId,
      isRegistered: isRegistered ?? this.isRegistered,
      firmName: firmName ?? this.firmName,
      adminName: adminName ?? this.adminName,
      adminPin: adminPin ?? this.adminPin,
      coAdminPin: coAdminPin ?? this.coAdminPin,
      securityQuestion: securityQuestion ?? this.securityQuestion,
      securityAnswer: securityAnswer ?? this.securityAnswer,
      ownerUpiId: ownerUpiId ?? this.ownerUpiId,
      agents: agents ?? this.agents,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseKey: supabaseKey ?? this.supabaseKey,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      useCustomCloud: useCustomCloud ?? this.useCustomCloud,
      customSupabaseUrl: customSupabaseUrl ?? this.customSupabaseUrl,
      customSupabaseKey: customSupabaseKey ?? this.customSupabaseKey,
      language: language ?? this.language,
    );
  }
}
