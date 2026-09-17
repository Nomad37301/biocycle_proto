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

enum DemoScenario { normal, hot, humid, offline }

extension DemoScenarioLabel on DemoScenario {
  String get label => switch (this) {
    DemoScenario.normal => 'Normal',
    DemoScenario.hot => 'Suhu meningkat',
    DemoScenario.humid => 'Kelembapan meningkat',
    DemoScenario.offline => 'Perangkat offline',
  };
}

class DemoSessionState {
  const DemoSessionState({
    this.role = DemoRole.operator,
    this.scenario = DemoScenario.normal,
    this.revision = 0,
    this.running = false,
    this.manuallyPaused = false,
  });

  final DemoRole role;
  final DemoScenario scenario;
  final int revision;
  final bool running;
  final bool manuallyPaused;

  DemoSessionState copyWith({
    DemoRole? role,
    DemoScenario? scenario,
    int? revision,
    bool? running,
    bool? manuallyPaused,
  }) => DemoSessionState(
    role: role ?? this.role,
    scenario: scenario ?? this.scenario,
    revision: revision ?? this.revision,
    running: running ?? this.running,
    manuallyPaused: manuallyPaused ?? this.manuallyPaused,
  );
}
