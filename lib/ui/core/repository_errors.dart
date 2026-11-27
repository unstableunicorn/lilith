// What to say when the pod document could not be loaded or saved.

import 'package:lilith/data/health_repository.dart';

String describeRepositoryError(RepositoryError error) => switch (error) {
  RepositoryError.notLoggedIn => 'Your session has ended. Log in again.',
  RepositoryError.loadFailed => 'Your data could not be loaded from your pod.',
  RepositoryError.malformed => 'The data on your pod could not be read.',
  RepositoryError.newerVersion =>
    'The data on your pod comes from a newer version of Lilith. '
        'Update the app.',
  RepositoryError.saveFailed =>
    'Your change is kept here but could not be saved to your pod.',
  RepositoryError.notLoaded => 'Your data has not loaded yet.',
};
