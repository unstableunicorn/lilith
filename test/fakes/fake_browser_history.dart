import 'package:lilith/ui/core/browser_history.dart';

/// A browser history that counts the steps back the app asked for.
class FakeBrowserHistory implements BrowserHistory {
  FakeBrowserHistory({this.isActive = true});

  @override
  final bool isActive;
  int backs = 0;

  @override
  void back() => backs++;
}
