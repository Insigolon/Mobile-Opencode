import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:opencode/agent.dart';
import 'package:opencode/Screens/agents_dashboard.dart';
import 'package:opencode/Screens/onboarding_page.dart';
import 'package:opencode/Screens/settings_page.dart';
import 'package:opencode/Screens/skills_page.dart';
import 'package:opencode/Screens/splash_page.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final connection = ConnectionService();
  await connection.loadSaved();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connection),
        ChangeNotifierProxyProvider<ConnectionService, ChatService>(
          create: (context) => ChatService(
            client: connection.client,
            events: EventService(client: connection.client),
          ),
          update: (_, conn, prev) => prev!,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionService>(
      builder: (context, conn, _) {
        Widget home;
        switch (conn.status) {
          case ConnectionStatus.connected:
            home = const OpenCodeScreen();
          case ConnectionStatus.disconnected:
            home = OnboardingConnectPage(
              onConnected: () {},
            );
          case ConnectionStatus.connecting:
          case ConnectionStatus.error:
            home = const SplashPage();
        }

        return MaterialApp(
          title: 'OpenCode',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0B0B0B),
          ),
          home: home,
        );
      },
    );
  }
}

class OpenCodeScreen extends StatefulWidget {
  const OpenCodeScreen({super.key});

  @override
  State<OpenCodeScreen> createState() => _OpenCodeScreenState();
}

class _OpenCodeScreenState extends State<OpenCodeScreen> {
  bool showAgents = false;
  bool showModelSheet = false;
  bool showMenu = false;
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat() async {
    final chat = context.read<ChatService>();
    try {
      await chat.init();
      if (chat.sessions.isEmpty) {
        await chat.createSession(title: 'New chat');
      }
      await chat.setActiveSession(chat.sessions.first.id);
    } catch (_) {
      // Server not available yet — user can start a new chat manually
    }
  }

  void closeAll() {
    setState(() {
      showAgents = false;
      showModelSheet = false;
    });
  }

  void _startNewChat() async {
    final chat = context.read<ChatService>();
    try {
      final session = await chat.createSession(title: 'New chat');
      await chat.setActiveSession(session.id);
    } catch (_) {}
    setState(() {
      showMenu = false;
    });
    _chatFocus.requestFocus();
  }

  void _openAgentsDashboard() {
    setState(() {
      showMenu = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgentsDashboardPage(onNewChat: _startNewChat),
      ),
    );
  }

  void _openSettings() {
    setState(() {
      showMenu = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openSkills() {
    setState(() {
      showMenu = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SkillsPage()),
    );
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final chat = context.read<ChatService>();
    chat.sendMessage(text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatService>();
    final messages = chat.activeSessionId != null
        ? chat.messagesFor(chat.activeSessionId!)
        : <ChatMessage>[];
    final inChat = messages.isNotEmpty || chat.activeSessionId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: GestureDetector(
        onTap: closeAll,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              showMenu = !showMenu;
                            });
                          },
                          child: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const Text(
                          "•ts",
                          style: TextStyle(
                            color: Color(0xFF00FF66),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: messages.isNotEmpty
                        ? ChatScreen(messages: messages)
                        : Center(
                            child: Opacity(
                              opacity: 0.5,
                              child: SvgPicture.asset(
                                "assets/opencode.svg",
                                width: 220,
                              ),
                            ),
                          ),
                  ),

                  ChatBar(
                    controller: _chatController,
                    focusNode: _chatFocus,
                    inChat: inChat,
                    onSend: _sendMessage,
                    onAgentsTap: () {
                      setState(() {
                        showAgents = !showAgents;
                        showModelSheet = false;
                      });
                    },
                    onModelTap: () {
                      setState(() {
                        showModelSheet = !showModelSheet;
                        showAgents = false;
                      });
                    },
                  ),
                ],
              ),

              if (showMenu)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showMenu = false;
                    });
                  },
                  child: Container(color: Colors.black54),
                ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                top: 0,
                bottom: 0,
                left: showMenu ? 0 : -300,
                child: SideMenu(
                  onNewChat: _startNewChat,
                  onAgentsTap: _openAgentsDashboard,
                  onSettingsTap: _openSettings,
                  onSkillsTap: _openSkills,
                ),
              ),

              Positioned(
                bottom: 110,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: showAgents ? 1 : 0,
                  child: showAgents ? const AgentsPopup() : const SizedBox(),
                ),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                bottom: showModelSheet ? 0 : -320,
                left: 0,
                right: 0,
                child: const ModelSheet(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatBar extends StatelessWidget {
  final VoidCallback onAgentsTap;
  final VoidCallback onModelTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool inChat;
  final VoidCallback? onSend;

  const ChatBar({
    super.key,
    required this.onAgentsTap,
    required this.onModelTap,
    this.controller,
    this.focusNode,
    this.inChat = false,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inChat)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Ask anything",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => onSend?.call(),
                    ),
                  ),
                  GestureDetector(
                    onTap: onSend,
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              )
            else
              const Text("Ask anything", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "~/ProjectDir",
                  style: TextStyle(color: Colors.grey),
                ),
                Row(
                  children: [
                    _pill("Agents", onAgentsTap),
                    const SizedBox(width: 8),
                    _pill("Claude Opus 4.8", onModelTap),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class AgentsPopup extends StatelessWidget {
  const AgentsPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Current Agents",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("/Build"),
            Text("/Plan"),
            Text("MCPs"),
            SizedBox(height: 8),
            Text(
              "+ Custom Agents.md",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class ModelSheet extends StatelessWidget {
  const ModelSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1F1F1F),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            const Text("Server", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _sectionTitle("Switch Model"),
            _option("Opus 4.8 (High)"),
            _option("Deepseek V4"),
            const SizedBox(height: 10),
            _sectionTitle("Switch Provider"),
            _option("Zen"),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }

  Widget _option(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  final List<ChatMessage> messages;

  const ChatScreen({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Opacity(
          opacity: 0.5,
          child: SvgPicture.asset("assets/opencode.svg", width: 220),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg.role == MessageRole.user;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF1A5CFF)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg.content,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SideMenu extends StatelessWidget {
  final VoidCallback? onNewChat;
  final VoidCallback? onAgentsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSkillsTap;

  const SideMenu({
    super.key,
    this.onNewChat,
    this.onAgentsTap,
    this.onSettingsTap,
    this.onSkillsTap,
  });

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<ChatService>().sessions;

    return Container(
      width: 280,
      color: const Color(0xFF000000),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset("assets/opencode-dark.svg", width: 40),
          const SizedBox(height: 34),

          GestureDetector(
            onTap: onNewChat,
            child: const Text(
              "New Chats",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: onAgentsTap,
            child: const Text(
              "Agents",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: onSkillsTap,
            child: const Text(
              "Skill.md",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(height: 40),

          const Text(
            "Previous Chats",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      context.read<ChatService>().setActiveSession(session.id);
                      Navigator.pop(context);
                    },
                    child: Text(
                      session.title,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              },
            ),
          ),

          GestureDetector(
            onTap: onSettingsTap,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Account Name", style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        "hostname 0.0.0.0 --port 4096",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
