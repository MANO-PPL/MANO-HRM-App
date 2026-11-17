/// Decoupled interface breaking the circular dependency between Dio interceptors
/// and ContextService (R10).
abstract class ContextTransportHooks {
  /// Provides outgoing context version headers ('X-Context-Known').
  Map<String, String> outgoingHeaders();

  /// Processes incoming response headers ('X-Context-Version', 'X-App-Update')
  /// and inline payloads ('_contextDelta').
  void onResponse(Map<String, List<String>> headers, Object? body);
}
