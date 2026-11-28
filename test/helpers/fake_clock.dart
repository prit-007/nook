/// Deterministic injectable clock for tests.
class FakeClock {
  FakeClock([DateTime? initial])
      : _now = initial ?? DateTime.utc(2026, 11, 28, 12, 0);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration delta) {
    _now = _now.add(delta);
  }

  void set(DateTime value) {
    _now = value;
  }
}
