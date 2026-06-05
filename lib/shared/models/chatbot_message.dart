/// A single message in the chatbot conversation.
class ChatbotMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  final bool isLoading; // true while assistant is typing

  const ChatbotMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.isLoading = false,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatbotMessage copyWith({
    String? role,
    String? text,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return ChatbotMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// The greeting message shown when the sheet first opens.
  static ChatbotMessage greeting(String pageName) {
    return ChatbotMessage(
      role: 'assistant',
      text: 'Hi! I\'m Mano Copilot 👋\nI can help you with anything on the $pageName page, or anywhere in the app. What would you like to know?',
      timestamp: DateTime.now(),
    );
  }

  /// A loading placeholder while waiting for the API.
  static ChatbotMessage loading() {
    return ChatbotMessage(
      role: 'assistant',
      text: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }
}
