import 'package:flutter/material.dart';

class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key});

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  bool showPreview = false;

  String selectedFile = "Skill.md";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080506),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SKILLS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 40),

                  ...List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: SkillFolder(
                        onOpenFile: (file) {
                          setState(() {
                            selectedFile = file;
                            showPreview = true;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (showPreview)
              Align(
                alignment: Alignment.bottomCenter,
                child: SkillPreviewSheet(
                  fileName: selectedFile,
                  onClose: () {
                    setState(() {
                      showPreview = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SkillFolder extends StatelessWidget {
  final Function(String) onOpenFile;

  const SkillFolder({
    super.key,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Agent-Orchestration",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: GestureDetector(
            onTap: () => onOpenFile("Skill.md"),
            child: const Text(
              "Skill.md",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: const [
              Icon(
                Icons.folder,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 4),
              Text(
                "References",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onOpenFile("Orchestration.py"),
                child: const Text(
                  "Orchestration.py",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),

              const Text(
                "Model Client",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SkillPreviewSheet extends StatelessWidget {
  final String fileName;
  final VoidCallback onClose;

  const SkillPreviewSheet({
    super.key,
    required this.fileName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 540,
      decoration: const BoxDecoration(
        color: Color(0xFF232323),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          Container(
            width: 90,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Agent-Orchestration \\ $fileName",
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B2B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  '''
---
name: twitter-analyzer

description:
Analyze a Twitter/X profile page to surface
viral tweets, engagement patterns,
content insights and visualize everything.

# Twitter / X Profile Analyzer

Deeply analyze a Twitter/X profile:

• Surface breakout tweets

• Score all tweets by engagement

• Identify content patterns

• Deliver everything in a beautiful
interactive dashboard

• Export reports

• Generate insights
''',
                  style: TextStyle(
                    color: Color(0xFFE6C38B),
                    fontSize: 13,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
