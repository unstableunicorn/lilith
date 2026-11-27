// How the person uses Lilith: for their own cycle, to follow someone who
// shares with them, or both. Kept in the pod document, so every device
// opens the same way.

enum AppMode {
  /// Tracks their own cycle; the app as it always was.
  tracker,

  /// Follows someone who shares with them; no tracker screens.
  partner,

  /// Tracks their own cycle and follows someone.
  both;

  /// The mode written as [name]; null for anything else, absent included.
  static AppMode? fromName(Object? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return null;
  }

  /// Whether the tracker screens (Log, History, Relief) show.
  bool get tracksOwnCycle => this != partner;

  /// Whether Today shows the person they follow.
  bool get followsSomeone => this != tracker;
}
