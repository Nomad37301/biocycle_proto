enum DemoRole { operator, supplier, buyer }

extension DemoRoleLabel on DemoRole {
  int get organizationId => switch (this) {
    DemoRole.supplier => 1,
    DemoRole.operator => 3,
    DemoRole.buyer => 4,
  };

  String get label => switch (this) {
    DemoRole.operator => 'Operator BSF',
    DemoRole.supplier => 'Penyedia Limbah',
    DemoRole.buyer => 'Pembeli Hasil',
  };

  String get organization => switch (this) {
    DemoRole.operator => 'Unit BSF Taman Sari',
    DemoRole.supplier => 'Pasar Organik Jimbaran',
    DemoRole.buyer => 'Ternak Sejahtera Bali',
  };
}

enum DemoScenario {
  normal,
  thermalAttention,
  thermalCritical,
  substrateWet,
  substrateDry,
  deviceOffline,
  sensorError,
  recovery,
}

extension DemoScenarioLabel on DemoScenario {
  String get label => switch (this) {
    DemoScenario.normal => 'Normal',
    DemoScenario.thermalAttention => 'Suhu substrat meningkat (Perhatian)',
    DemoScenario.thermalCritical => 'Suhu substrat kritis',
    DemoScenario.substrateWet => 'Media basah',
    DemoScenario.substrateDry => 'Media kering',
    DemoScenario.deviceOffline => 'Perangkat terputus (Offline)',
    DemoScenario.sensorError => 'Gangguan sensor (Error)',
    DemoScenario.recovery => 'Pemulihan (Recovery)',
  };
}

class DemoSessionState {
  const DemoSessionState({
    this.role = DemoRole.operator,
    this.scenario = DemoScenario.normal,
    this.revision = 0,
    this.running = false,
    this.manuallyPaused = false,
    this.selectedUnitId = 1,
    this.isFastForwarding = false,
    this.fastForwardLabel,
  });

  final DemoRole role;
  final DemoScenario scenario;
  final int revision;
  final bool running;
  final bool manuallyPaused;
  final int selectedUnitId;
  final bool isFastForwarding;
  final String? fastForwardLabel;

  DemoSessionState copyWith({
    DemoRole? role,
    DemoScenario? scenario,
    int? revision,
    bool? running,
    bool? manuallyPaused,
    int? selectedUnitId,
    bool? isFastForwarding,
    String? fastForwardLabel,
  }) => DemoSessionState(
    role: role ?? this.role,
    scenario: scenario ?? this.scenario,
    revision: revision ?? this.revision,
    running: running ?? this.running,
    manuallyPaused: manuallyPaused ?? this.manuallyPaused,
    selectedUnitId: selectedUnitId ?? this.selectedUnitId,
    isFastForwarding: isFastForwarding ?? this.isFastForwarding,
    fastForwardLabel: fastForwardLabel ?? this.fastForwardLabel,
  );
}
