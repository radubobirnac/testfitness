import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/utils/accessibility_helper.dart';
import 'package:testfitness/widgets/offline_indicator.dart';

/// AI Chat Screen for fitness assistance
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final AIService _aiService = AIService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: "Hi! I'm your AI fitness coach powered by Gemini 2.5 Flash Lite. I can help you with workout plans, exercise alternatives, progress analysis, and answer any fitness questions you have!\n\n⚠️ **Note: AI features require an internet connection**",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  /// Index of the Profile tab in MainScreen (holds the AI settings).
  static const int _profileTabIndex = 4;

  /// Leaves the chat and opens Profile, where the Gemini API key is set.
  void _openAiSettings() {
    AppBloc? appBloc;
    try {
      appBloc = context.read<AppBloc>();
    } catch (_) {
      appBloc = null;
    }
    if (appBloc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Open Profile → AI settings to add your Gemini API key.'),
      ));
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    appBloc.add(const AppTabChanged(_profileTabIndex));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    if (_aiService.unavailableReason != null) {
      // The banner explains why; just refresh so it shows the latest reason.
      setState(() {});
      return;
    }

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Get AI response
      final response = await _aiService.answerFitnessQuestion(message);
      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });

      HapticFeedback.lightImpact();
      AccessibilityHelper.announceMessage('AI response received');
      
    } catch (error) {
      if (!mounted) return;
      final text = error is AIServiceException
          ? error.message
          : 'Sorry, something went wrong. Please try again.';
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });

      HapticFeedback.heavyImpact();
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildQuickActionTile(
              icon: Icons.fitness_center,
              title: 'Generate Workout Plan',
              subtitle: 'Get a personalized workout',
              onTap: () => _sendQuickMessage('Create a 30-minute strength training workout for intermediate level using dumbbells and bodyweight exercises'),
            ),
            
            _buildQuickActionTile(
              icon: Icons.swap_horiz,
              title: 'Exercise Alternatives',
              subtitle: 'Find substitute exercises',
              onTap: () => _sendQuickMessage('What are some alternatives to push-ups that I can do at home?'),
            ),
            
            _buildQuickActionTile(
              icon: Icons.insights,
              title: 'Progress Analysis',
              subtitle: 'Analyze my fitness progress',
              onTap: () => _sendQuickMessage('How can I track my fitness progress effectively?'),
            ),
            
            _buildQuickActionTile(
              icon: Icons.help_outline,
              title: 'Fitness Tips',
              subtitle: 'Get general fitness advice',
              onTap: () => _sendQuickMessage('What are the most important principles for building muscle?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AccessibilityHelper.accessibleListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      semanticLabel: '$title: $subtitle',
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _sendQuickMessage(String message) {
    _messageController.text = message;
    _sendMessage();
  }

  /// Up-front explanation when AI chat can't be used (no key / offline).
  Widget _buildUnavailableBanner(String reason) {
    final scheme = Theme.of(context).colorScheme;
    final missingKey = !_aiService.hasApiKey;
    return Semantics(
      container: true,
      label: 'AI chat unavailable. $reason',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(missingKey ? Icons.key : Icons.wifi_off,
                    color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    missingKey
                        ? 'Connect your AI coach'
                        : 'AI chat is offline',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(reason, style: TextStyle(color: scheme.onSecondaryContainer)),
            if (missingKey) ...[
              const SizedBox(height: 4),
              Text(
                'You can add a free Gemini API key in Profile → AI settings. '
                'Your offline coach still plans workouts without it.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openAiSettings,
                icon: const Icon(Icons.key),
                label: const Text('Add API key'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt on connectivity changes so the banner and input stay current.
    return ConnectivityBuilder(
      builder: (context, _) => _buildChat(context),
    );
  }

  Widget _buildChat(BuildContext context) {
    final unavailableReason = _aiService.unavailableReason;
    final canChat = unavailableReason == null;
    return OfflineIndicator(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Fitness Coach'),
          actions: [
            AccessibilityHelper.accessibleIconButton(
              icon: Icons.help_outline,
              onPressed: canChat ? _showQuickActions : null,
              semanticLabel: 'Show quick actions',
              tooltip: 'Quick Actions',
            ),
          ],
        ),
        body: Column(
          children: [
            if (unavailableReason != null)
              _buildUnavailableBanner(unavailableReason),

            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildLoadingMessage();
                  }
                  
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            
            // Input area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Fitness question input field',
                      textField: true,
                      child: TextField(
                        controller: _messageController,
                        enabled: canChat,
                        decoration: InputDecoration(
                          labelText: canChat
                              ? 'Ask me anything about fitness...'
                              : 'AI chat unavailable',
                          hintText: 'Type your fitness question here',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.multiline,
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AccessibilityHelper.accessibleIconButton(
                    icon: Icons.send,
                    onPressed: canChat &&
                            _messageController.text.trim().isNotEmpty &&
                            !_isLoading
                        ? _sendMessage
                        : null,
                    semanticLabel: 'Send message',
                    tooltip: 'Send',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.isError 
                  ? Colors.red 
                  : Theme.of(context).colorScheme.primary,
              child: Icon(
                message.isError ? Icons.error : Icons.smart_toy,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : message.isError
                        ? Colors.red.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : message.isError
                              ? Colors.red[700]
                              : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(
              Icons.smart_toy,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('AI is thinking...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}
