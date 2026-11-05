import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

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
      // Check API key and connectivity (distinct messages for each)
      final unavailableReason = _aiService.unavailableReason;
      if (unavailableReason != null) {
        throw AIServiceException(unavailableReason);
      }

      // Get AI response
      final response = await _aiService.answerFitnessQuestion(message);
      
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
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I encountered an error: ${error.toString()}",
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

  @override
  Widget build(BuildContext context) {
    return OfflineIndicator(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Fitness Coach'),
          actions: [
            AccessibilityHelper.accessibleIconButton(
              icon: Icons.help_outline,
              onPressed: _showQuickActions,
              semanticLabel: 'Show quick actions',
              tooltip: 'Quick Actions',
            ),
          ],
        ),
        body: Column(
          children: [
            // Connection status banner
            ConnectivityBuilder(
              builder: (context, isOnline) {
                if (!isOnline) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange,
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI features require internet connection',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
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
                    child: AccessibilityHelper.accessibleTextField(
                      controller: _messageController,
                      label: 'Ask me anything about fitness...',
                      hint: 'Type your fitness question here',
                      semanticLabel: 'Fitness question input field',
                      keyboardType: TextInputType.multiline,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AccessibilityHelper.accessibleIconButton(
                    icon: Icons.send,
                    onPressed: _messageController.text.trim().isNotEmpty && !_isLoading
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
