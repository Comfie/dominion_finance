/// Exception thrown by repository implementations when an operation fails,
/// whether due to a non-success HTTP status, a network error, or any other
/// failure encountered while fulfilling the request.
class RepositoryException implements Exception {
  final String message;

  const RepositoryException(this.message);

  @override
  String toString() => 'RepositoryException: $message';
}
