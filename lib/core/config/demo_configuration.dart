import 'dart:convert';

class ConfigurationException implements Exception {
  ConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}

class FreshnessConfig {
  const FreshnessConfig({
    this.freshThreshold = const Duration(seconds: 30),
    this.agingThreshold = const Duration(seconds: 300),
    this.offlineThreshold = const Duration(seconds: 600),
  });

  final Duration freshThreshold;
  final Duration agingThreshold;
  final Duration offlineThreshold;

  void validate() {
    if (freshThreshold <= Duration.zero ||
        agingThreshold <= freshThreshold ||
        offlineThreshold <= agingThreshold) {
      throw ConfigurationException(
        'Batas waktu freshness tidak valid: fresh < aging < offline wajib terpenuhi.',
      );
    }
  }

  Map<String, dynamic> toMap() => {
    'freshThresholdSeconds': freshThreshold.inSeconds,
    'agingThresholdSeconds': agingThreshold.inSeconds,
    'offlineThresholdSeconds': offlineThreshold.inSeconds,
  };

  factory FreshnessConfig.fromMap(Map<String, dynamic> map) => FreshnessConfig(
    freshThreshold: Duration(
      seconds: map['freshThresholdSeconds'] as int? ?? 30,
    ),
    agingThreshold: Duration(
      seconds: map['agingThresholdSeconds'] as int? ?? 300,
    ),
    offlineThreshold: Duration(
      seconds: map['offlineThresholdSeconds'] as int? ?? 600,
    ),
  );
}

class SubstrateTemperatureRuleConfig {
  const SubstrateTemperatureRuleConfig({
    this.optimalMin = 26.0,
    this.optimalMax = 35.0,
    this.attentionMax = 38.0,
    this.criticalMax = 38.0,
  });

  final double optimalMin;
  final double optimalMax;
  final double attentionMax;
  final double criticalMax;

  void validate() {
    if (!optimalMin.isFinite ||
        !optimalMax.isFinite ||
        !attentionMax.isFinite ||
        !criticalMax.isFinite) {
      throw ConfigurationException(
        'Nilai threshold suhu substrat harus finite.',
      );
    }
    if (optimalMin >= optimalMax || optimalMax > attentionMax) {
      throw ConfigurationException(
        'Threshold suhu substrat tidak valid: optimalMin < optimalMax <= attentionMax.',
      );
    }
  }

  Map<String, dynamic> toMap() => {
    'optimalMin': optimalMin,
    'optimalMax': optimalMax,
    'attentionMax': attentionMax,
    'criticalMax': criticalMax,
  };

  factory SubstrateTemperatureRuleConfig.fromMap(Map<String, dynamic> map) =>
      SubstrateTemperatureRuleConfig(
        optimalMin: (map['optimalMin'] as num?)?.toDouble() ?? 26.0,
        optimalMax: (map['optimalMax'] as num?)?.toDouble() ?? 35.0,
        attentionMax: (map['attentionMax'] as num?)?.toDouble() ?? 38.0,
        criticalMax: (map['criticalMax'] as num?)?.toDouble() ?? 38.0,
      );
}

class SubstrateMoistureRuleConfig {
  const SubstrateMoistureRuleConfig({
    this.optimalMin = 50.0,
    this.optimalMax = 80.0,
  });

  final double optimalMin;
  final double optimalMax;

  void validate() {
    if (!optimalMin.isFinite || !optimalMax.isFinite) {
      throw ConfigurationException(
        'Nilai threshold kelembapan substrat harus finite.',
      );
    }
    if (optimalMin < 0 || optimalMax > 100 || optimalMin >= optimalMax) {
      throw ConfigurationException(
        'Threshold kelembapan substrat tidak valid: 0 <= optimalMin < optimalMax <= 100.',
      );
    }
  }

  Map<String, dynamic> toMap() => {
    'optimalMin': optimalMin,
    'optimalMax': optimalMax,
  };

  factory SubstrateMoistureRuleConfig.fromMap(Map<String, dynamic> map) =>
      SubstrateMoistureRuleConfig(
        optimalMin: (map['optimalMin'] as num?)?.toDouble() ?? 50.0,
        optimalMax: (map['optimalMax'] as num?)?.toDouble() ?? 80.0,
      );
}

class ValidationConfig {
  const ValidationConfig({
    this.minTemperature = -20.0,
    this.maxTemperature = 80.0,
    this.minHumidity = 0.0,
    this.maxHumidity = 100.0,
    this.minMoisture = 0.0,
    this.maxMoisture = 100.0,
  });

  final double minTemperature;
  final double maxTemperature;
  final double minHumidity;
  final double maxHumidity;
  final double minMoisture;
  final double maxMoisture;

  void validate() {
    if (!minTemperature.isFinite ||
        !maxTemperature.isFinite ||
        minTemperature >= maxTemperature) {
      throw ConfigurationException('Batas validasi suhu tidak valid.');
    }
    if (!minHumidity.isFinite ||
        !maxHumidity.isFinite ||
        minHumidity < 0 ||
        maxHumidity > 100 ||
        minHumidity >= maxHumidity) {
      throw ConfigurationException('Batas validasi kelembapan tidak valid.');
    }
  }

  bool isValueValid(String parameterKey, double value) {
    if (!value.isFinite) return false;
    switch (parameterKey) {
      case 'substrateTemperature':
      case 'ambientTemperature':
        return value >= minTemperature && value <= maxTemperature;
      case 'substrateMoisture':
        return value >= minMoisture && value <= maxMoisture;
      case 'ambientHumidity':
        return value >= minHumidity && value <= maxHumidity;
      default:
        return false;
    }
  }

  Map<String, dynamic> toMap() => {
    'minTemperature': minTemperature,
    'maxTemperature': maxTemperature,
    'minHumidity': minHumidity,
    'maxHumidity': maxHumidity,
    'minMoisture': minMoisture,
    'maxMoisture': maxMoisture,
  };

  factory ValidationConfig.fromMap(Map<String, dynamic> map) =>
      ValidationConfig(
        minTemperature: (map['minTemperature'] as num?)?.toDouble() ?? -20.0,
        maxTemperature: (map['maxTemperature'] as num?)?.toDouble() ?? 80.0,
        minHumidity: (map['minHumidity'] as num?)?.toDouble() ?? 0.0,
        maxHumidity: (map['maxHumidity'] as num?)?.toDouble() ?? 100.0,
        minMoisture: (map['minMoisture'] as num?)?.toDouble() ?? 0.0,
        maxMoisture: (map['maxMoisture'] as num?)?.toDouble() ?? 100.0,
      );
}

class SimulatorConfig {
  const SimulatorConfig({
    this.tickInterval = const Duration(seconds: 5),
    this.historySampleCount = 25,
    this.historyInterval = const Duration(hours: 1),
    this.temperatureNoiseAmplitude = 0.3,
    this.moistureNoiseAmplitude = 1.0,
  });

  final Duration tickInterval;
  final int historySampleCount;
  final Duration historyInterval;
  final double temperatureNoiseAmplitude;
  final double moistureNoiseAmplitude;

  void validate() {
    if (tickInterval <= Duration.zero ||
        historySampleCount <= 0 ||
        historyInterval <= Duration.zero ||
        !temperatureNoiseAmplitude.isFinite ||
        temperatureNoiseAmplitude < 0 ||
        !moistureNoiseAmplitude.isFinite ||
        moistureNoiseAmplitude < 0) {
      throw ConfigurationException('Konfigurasi simulator tidak valid.');
    }
  }

  Map<String, dynamic> toMap() => {
    'tickIntervalSeconds': tickInterval.inSeconds,
    'historySampleCount': historySampleCount,
    'historyIntervalMinutes': historyInterval.inMinutes,
    'temperatureNoiseAmplitude': temperatureNoiseAmplitude,
    'moistureNoiseAmplitude': moistureNoiseAmplitude,
  };

  factory SimulatorConfig.fromMap(Map<String, dynamic> map) => SimulatorConfig(
    tickInterval: Duration(seconds: map['tickIntervalSeconds'] as int? ?? 5),
    historySampleCount: map['historySampleCount'] as int? ?? 25,
    historyInterval: Duration(
      minutes: map['historyIntervalMinutes'] as int? ?? 60,
    ),
    temperatureNoiseAmplitude:
        (map['temperatureNoiseAmplitude'] as num?)?.toDouble() ?? 0.3,
    moistureNoiseAmplitude:
        (map['moistureNoiseAmplitude'] as num?)?.toDouble() ?? 1.0,
  );
}

class AlertConfig {
  const AlertConfig({
    this.recoveryConsecutiveSamples = 2,
    this.notificationPerEpisodeOnly = true,
  });

  final int recoveryConsecutiveSamples;
  final bool notificationPerEpisodeOnly;

  void validate() {
    if (recoveryConsecutiveSamples <= 0) {
      throw ConfigurationException('Jumlah sampel pemulihan alert minimal 1.');
    }
  }

  Map<String, dynamic> toMap() => {
    'recoveryConsecutiveSamples': recoveryConsecutiveSamples,
    'notificationPerEpisodeOnly': notificationPerEpisodeOnly,
  };

  factory AlertConfig.fromMap(Map<String, dynamic> map) => AlertConfig(
    recoveryConsecutiveSamples: map['recoveryConsecutiveSamples'] as int? ?? 2,
    notificationPerEpisodeOnly:
        map['notificationPerEpisodeOnly'] as bool? ?? true,
  );
}

class SopConfig {
  const SopConfig({
    this.sopVersion = 'demo-sop-v1',
    this.evaluationWindow = const Duration(minutes: 15),
    this.searchGracePeriod = const Duration(minutes: 5),
  });

  final String sopVersion;
  final Duration evaluationWindow;
  final Duration searchGracePeriod;

  void validate() {
    if (sopVersion.isEmpty ||
        evaluationWindow <= Duration.zero ||
        searchGracePeriod < Duration.zero) {
      throw ConfigurationException('Konfigurasi SOP tidak valid.');
    }
  }

  Map<String, dynamic> toMap() => {
    'sopVersion': sopVersion,
    'evaluationWindowMinutes': evaluationWindow.inMinutes,
    'searchGracePeriodMinutes': searchGracePeriod.inMinutes,
  };

  factory SopConfig.fromMap(Map<String, dynamic> map) => SopConfig(
    sopVersion: map['sopVersion'] as String? ?? 'demo-sop-v1',
    evaluationWindow: Duration(
      minutes: map['evaluationWindowMinutes'] as int? ?? 15,
    ),
    searchGracePeriod: Duration(
      minutes: map['searchGracePeriodMinutes'] as int? ?? 5,
    ),
  );
}

class PitchConfig {
  const PitchConfig({
    this.subscriptionPriceMonthly = 299000.0,
    this.larvaPricePerKg = 8000.0,
    this.frassPricePerKg = 2000.0,
    this.larvaYieldFactor = 0.16,
    this.frassYieldFactor = 0.425,
    this.emissionReductionFactor = 1.9,
  });

  final double subscriptionPriceMonthly;
  final double larvaPricePerKg;
  final double frassPricePerKg;
  final double larvaYieldFactor;
  final double frassYieldFactor;
  final double emissionReductionFactor;

  void validate() {
    if (!subscriptionPriceMonthly.isFinite ||
        subscriptionPriceMonthly < 0 ||
        !larvaPricePerKg.isFinite ||
        larvaPricePerKg < 0 ||
        !frassPricePerKg.isFinite ||
        frassPricePerKg < 0 ||
        !larvaYieldFactor.isFinite ||
        larvaYieldFactor < 0 ||
        !frassYieldFactor.isFinite ||
        frassYieldFactor < 0 ||
        !emissionReductionFactor.isFinite ||
        emissionReductionFactor < 0) {
      throw ConfigurationException('Konfigurasi kalkulator pitch tidak valid.');
    }
  }

  Map<String, dynamic> toMap() => {
    'subscriptionPriceMonthly': subscriptionPriceMonthly,
    'larvaPricePerKg': larvaPricePerKg,
    'frassPricePerKg': frassPricePerKg,
    'larvaYieldFactor': larvaYieldFactor,
    'frassYieldFactor': frassYieldFactor,
    'emissionReductionFactor': emissionReductionFactor,
  };

  factory PitchConfig.fromMap(Map<String, dynamic> map) => PitchConfig(
    subscriptionPriceMonthly:
        (map['subscriptionPriceMonthly'] as num?)?.toDouble() ?? 299000.0,
    larvaPricePerKg: (map['larvaPricePerKg'] as num?)?.toDouble() ?? 8000.0,
    frassPricePerKg: (map['frassPricePerKg'] as num?)?.toDouble() ?? 2000.0,
    larvaYieldFactor: (map['larvaYieldFactor'] as num?)?.toDouble() ?? 0.16,
    frassYieldFactor: (map['frassYieldFactor'] as num?)?.toDouble() ?? 0.425,
    emissionReductionFactor:
        (map['emissionReductionFactor'] as num?)?.toDouble() ?? 1.9,
  );
}

class ChartConfig {
  const ChartConfig({
    this.minTemperatureSpan = 2.0,
    this.minMoistureSpan = 5.0,
    this.paddingRatio = 0.1,
    this.gapMultiplier = 1.5,
  });

  final double minTemperatureSpan;
  final double minMoistureSpan;
  final double paddingRatio;
  final double gapMultiplier;

  void validate() {
    if (!minTemperatureSpan.isFinite ||
        minTemperatureSpan <= 0 ||
        !minMoistureSpan.isFinite ||
        minMoistureSpan <= 0 ||
        !paddingRatio.isFinite ||
        paddingRatio < 0 ||
        !gapMultiplier.isFinite ||
        gapMultiplier <= 1.0) {
      throw ConfigurationException('Konfigurasi chart tidak valid.');
    }
  }

  Map<String, dynamic> toMap() => {
    'minTemperatureSpan': minTemperatureSpan,
    'minMoistureSpan': minMoistureSpan,
    'paddingRatio': paddingRatio,
    'gapMultiplier': gapMultiplier,
  };

  factory ChartConfig.fromMap(Map<String, dynamic> map) => ChartConfig(
    minTemperatureSpan: (map['minTemperatureSpan'] as num?)?.toDouble() ?? 2.0,
    minMoistureSpan: (map['minMoistureSpan'] as num?)?.toDouble() ?? 5.0,
    paddingRatio: (map['paddingRatio'] as num?)?.toDouble() ?? 0.1,
    gapMultiplier: (map['gapMultiplier'] as num?)?.toDouble() ?? 1.5,
  );
}

class DemoConfiguration {
  const DemoConfiguration({
    this.version = 'demo-v1',
    this.freshness = const FreshnessConfig(),
    this.substrateTemperature = const SubstrateTemperatureRuleConfig(),
    this.substrateMoisture = const SubstrateMoistureRuleConfig(),
    this.validation = const ValidationConfig(),
    this.simulator = const SimulatorConfig(),
    this.alert = const AlertConfig(),
    this.sop = const SopConfig(),
    this.pitch = const PitchConfig(),
    this.chart = const ChartConfig(),
  });

  final String version;
  final FreshnessConfig freshness;
  final SubstrateTemperatureRuleConfig substrateTemperature;
  final SubstrateMoistureRuleConfig substrateMoisture;
  final ValidationConfig validation;
  final SimulatorConfig simulator;
  final AlertConfig alert;
  final SopConfig sop;
  final PitchConfig pitch;
  final ChartConfig chart;

  void validate() {
    if (version.isEmpty) {
      throw ConfigurationException(
        'Versi konfigurasi demo tidak boleh kosong.',
      );
    }
    freshness.validate();
    substrateTemperature.validate();
    substrateMoisture.validate();
    validation.validate();
    simulator.validate();
    alert.validate();
    sop.validate();
    pitch.validate();
    chart.validate();
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'freshness': freshness.toMap(),
    'substrateTemperature': substrateTemperature.toMap(),
    'substrateMoisture': substrateMoisture.toMap(),
    'validation': validation.toMap(),
    'simulator': simulator.toMap(),
    'alert': alert.toMap(),
    'sop': sop.toMap(),
    'pitch': pitch.toMap(),
    'chart': chart.toMap(),
  };

  String toJson() => jsonEncode(toMap());

  factory DemoConfiguration.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('version') || map['version'] == null) {
      throw ConfigurationException(
        'Versi konfigurasi demo wajib ada (configurationMissing).',
      );
    }
    final config = DemoConfiguration(
      version: map['version'] as String,
      freshness: map['freshness'] != null
          ? FreshnessConfig.fromMap(map['freshness'] as Map<String, dynamic>)
          : throw ConfigurationException(
              'Konfigurasi freshness tidak ditemukan (configurationMissing).',
            ),
      substrateTemperature: map['substrateTemperature'] != null
          ? SubstrateTemperatureRuleConfig.fromMap(
              map['substrateTemperature'] as Map<String, dynamic>,
            )
          : throw ConfigurationException(
              'Konfigurasi suhu substrat tidak ditemukan (configurationMissing).',
            ),
      substrateMoisture: map['substrateMoisture'] != null
          ? SubstrateMoistureRuleConfig.fromMap(
              map['substrateMoisture'] as Map<String, dynamic>,
            )
          : throw ConfigurationException(
              'Konfigurasi kelembapan substrat tidak ditemukan (configurationMissing).',
            ),
      validation: map['validation'] != null
          ? ValidationConfig.fromMap(map['validation'] as Map<String, dynamic>)
          : throw ConfigurationException(
              'Konfigurasi validasi tidak ditemukan (configurationMissing).',
            ),
      simulator: map['simulator'] != null
          ? SimulatorConfig.fromMap(map['simulator'] as Map<String, dynamic>)
          : const SimulatorConfig(),
      alert: map['alert'] != null
          ? AlertConfig.fromMap(map['alert'] as Map<String, dynamic>)
          : const AlertConfig(),
      sop: map['sop'] != null
          ? SopConfig.fromMap(map['sop'] as Map<String, dynamic>)
          : const SopConfig(),
      pitch: map['pitch'] != null
          ? PitchConfig.fromMap(map['pitch'] as Map<String, dynamic>)
          : const PitchConfig(),
      chart: map['chart'] != null
          ? ChartConfig.fromMap(map['chart'] as Map<String, dynamic>)
          : const ChartConfig(),
    );
    config.validate();
    return config;
  }

  factory DemoConfiguration.fromJson(String jsonStr) =>
      DemoConfiguration.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
}
