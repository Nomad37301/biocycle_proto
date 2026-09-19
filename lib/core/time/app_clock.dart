abstract class AppClock {
  DateTime get now;
}

class SystemAppClock implements AppClock {
  const SystemAppClock();

  @override
  DateTime get now => DateTime.now().toUtc();
}

class OffsetAppClock implements AppClock {
  OffsetAppClock({AppClock? baseClock, this._offset = Duration.zero})
    : _baseClock = baseClock ?? const SystemAppClock();

  final AppClock _baseClock;
  Duration _offset;

  Duration get offset => _offset;

  void advance(Duration duration) {
    _offset += duration;
  }

  void reset() {
    _offset = Duration.zero;
  }

  @override
  DateTime get now => _baseClock.now.add(_offset);
}

class FakeAppClock implements AppClock {
  FakeAppClock([DateTime? initialTime])
    : _currentTime = (initialTime ?? DateTime.utc(2026, 9, 19, 8, 0, 0))
          .toUtc();

  DateTime _currentTime;

  @override
  DateTime get now => _currentTime;

  void set(DateTime time) {
    _currentTime = time.toUtc();
  }

  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }
}
