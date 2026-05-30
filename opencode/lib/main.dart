import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:opencode/Screens/agents_dashboard.dart';
import 'package:opencode/Screens/onboarding_page.dart';
import 'package:opencode/Screens/settings_page.dart';
import 'package:opencode/Screens/skills_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? showOnboarding;

  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUrl = prefs.containsKey('server_url');
    const storage = FlutterSecureStorage();
    final password = await storage.read(key: 'server_password');
    final hasCredentials = hasUrl && password != null;
    setState(() => showOnboarding = !hasCredentials);
  }

  void _onOnboardingComplete() {
    setState(() => showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (showOnboarding == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0B0B0B),
          body: Center(
            child: CircularProgressIndicator(color: Colors.white24),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'OpenCode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
      ),
      home: showOnboarding!
          ? OnboardingConnectPage(onConnected: _onOnboardingComplete)
          : const OpenCodeScreen(),
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
  bool inChat = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocus = FocusNode();

  void closeAll() {
    setState(() {
      showAgents = false;
      showModelSheet = false;
    });
  }

  void _startNewChat() {
    setState(() {
      inChat = true;
      showMenu = false;
      _messages.clear();
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
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: GestureDetector(
        onTap: closeAll,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              /// Main Layout
              Column(
                children: [
                  /// Top Bar with Hamburger
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

                  /// Content: Logo or Chat
                  Expanded(
                    child: inChat
                        ? ChatScreen(messages: _messages)
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

                  /// Chat Bar
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

              /// Side Menu Backdrop
              if (showMenu)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showMenu = false;
                    });
                  },
                  child: Container(color: Colors.black54),
                ),

              /// Side Menu
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

              /// Agents Popup
              Positioned(
                bottom: 110,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: showAgents ? 1 : 0,
                  child: showAgents ? const AgentsPopup() : const SizedBox(),
                ),
              ),

              /// Model Bottom Sheet (NON-DRAGGABLE)
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

//
// 🔹 Chat Bar
//
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

//
// 🔹 Agents Popup
//
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

//
// 🔹 Model Sheet (NON-DRAGGABLE)
//
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
            /// Handle
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

            /// Switch Model
            _sectionTitle("Switch Model"),
            _option("Opus 4.8 (High)"),
            _option("Deepseek V4"),

            const SizedBox(height: 10),

            /// Switch Provider
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

//
// 🔹 Chat Message Model
//
class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});
}

//
// 🔹 Chat Screen
//
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: msg.isUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? const Color(0xFF1A5CFF)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}

//
// 🔹 Side Menu
//
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
            child: ListView(
              padding: EdgeInsets.zero,
              children: const [
                ChatHistoryTile(
                  title: "Project1",
                  subtitle: "Bug Fix in rust codesbas.",
                  expanded: true,
                ),
                SizedBox(height: 16),
                ChatHistoryTile(title: "Download and fix WSL"),
                SizedBox(height: 16),
                ChatHistoryTile(title: "Overlay Width Clamp"),
                SizedBox(height: 16),
                ChatHistoryTile(title: "Populate Feature Service"),
                SizedBox(height: 16),
                ChatHistoryTile(title: "Gemma 4 2b Integration"),
                SizedBox(height: 16),
                ChatHistoryTile(title: "Strip MediaProjection,add"),
              ],
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

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Account Name", style: TextStyle(fontSize: 14)),
                      SizedBox(height: 2),
                      Text(
                        "hostname 0.0.0.0 --port 4096",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
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

//
// 🔹 Chat History Tile
//
class ChatHistoryTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool expanded;

  const ChatHistoryTile({
    super.key,
    required this.title,
    this.subtitle,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
            if (expanded) const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),

        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              subtitle!,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      ],
    );
  }
}
