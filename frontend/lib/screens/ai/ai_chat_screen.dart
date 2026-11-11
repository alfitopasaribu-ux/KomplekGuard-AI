import 'package:flutter/material.dart';

import '../../core/theme/nexus_guard_theme.dart';
import '../../services/safety_ai_service.dart';
import '../../services/voice_service.dart';
import '../../services/safety_quick_guide.dart';
import '../../widgets/safety_response_text.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'ASSISTANT',
      'message':
          'Halo, saya KomplekGuard AI. Kamu bisa bertanya dengan mengetik atau menekan tombol mic untuk bicara tentang risiko lingkungan, langkah darurat, dan keamanan komplek.',
    }
  ];

  bool _loading = false;
  bool _listening = false;
  String? _sessionId;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    try {
      if (_listening) {
        await VoiceService.instance.stopListening();
        if (mounted) setState(() => _listening = false);
        return;
      }

      setState(() => _listening = true);

      await VoiceService.instance.startListening(
        onResult: (text) {
          if (!mounted) return;

          setState(() {
            _messageCtrl.text = text;
            _messageCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageCtrl.text.length),
            );
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _listening = false);
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _listening = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice gagal: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();

    if (text.isEmpty || _loading) return;

    if (_listening) {
      await VoiceService.instance.stopListening();
      if (mounted) setState(() => _listening = false);
    }

    setState(() {
      _messages.add({
        'role': 'USER',
        'message': text,
      });
      _loading = true;
      _messageCtrl.clear();
    });

    _scrollToBottom();

    try {
      final res = await SafetyAiService.chat(
        message: text,
        sessionId: _sessionId,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'];

        setState(() {
          _sessionId = data['sessionId']?.toString();
          _messages.add({
            'role': 'ASSISTANT',
            'message': data['answer']?.toString() ??
                'AI belum dapat memberikan jawaban.',
          });
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'ASSISTANT',
            'message': res['message']?.toString() ??
                'Maaf, AI gagal menjawab pertanyaan.',
          });
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'ASSISTANT',
          'message': 'Koneksi ke AI gagal: $e',
        });
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _quickAsk(String question) {
    _messageCtrl.text = question;
    _sendMessage();
  }

  void _openQuickGuides() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9FBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Panduan Kilat Keselamatan',
                  style: TextStyle(fontWeight: FontWeight.w800,
                      color: NexusGuard.slate, fontSize: 20)),
              const SizedBox(height: 8),
              const Text(
                'Tidak memakai token AI. Pilih panduan untuk langkah awal; '
                'bukan informasi kondisi komplek secara langsung.',
                style: TextStyle(color: NexusGuard.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: SafetyQuickGuide.guides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 5),
                  itemBuilder: (_, index) {
                    final guide = SafetyQuickGuide.guides[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.health_and_safety_outlined,
                          color: NexusGuard.emerald),
                      title: Text(guide.title,
                          style: const TextStyle(
                              color: NexusGuard.slate,
                              fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right,
                          color: NexusGuard.emerald),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showGuide(guide);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuide(SafetyQuickGuide guide) {
    final content = [
      guide.subtitle,
      '',
      for (var i = 0; i < guide.steps.length; i++)
        '${i + 1}. ${guide.steps[i]}',
      '',
      'Jika ada bahaya langsung, utamakan evakuasi dan hubungi petugas. '
          'Panduan ini bukan analisis AI atau laporan real-time.',
    ].join('\n');

    setState(() {
      _messages.add({
        'role': 'ASSISTANT',
        'message': content,
        'offlineGuide': true,
      });
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusGuard.bg,
      appBar: AppBar(
        backgroundColor: NexusGuard.bg.withValues(alpha: 0.96),
        elevation: 0,
        foregroundColor: NexusGuard.text,
        title: Text(
          'AI SAFETY CHAT',
          style: NexusGuard.orbitron(
            size: 16,
            color: NexusGuard.cyan,
            spacing: 1.4,
          ),
        ),
      ),
      body: NexusBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _header(),
                _quickGuideBar(),
                _quickQuestions(),
                Expanded(child: _chatList()),
                if (_listening) _voiceIndicator(),
                if (_loading) _typingIndicator(),
                _inputBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: NexusHudCard(
        glowColor: _listening ? NexusGuard.red : NexusGuard.purple,
        active: true,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: NexusGuard.purple.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: NexusGuard.purple.withValues(alpha: 0.45),
                ),
              ),
              child: Icon(
                _listening
                    ? Icons.graphic_eq_rounded
                    : Icons.auto_awesome_rounded,
                color: _listening ? NexusGuard.red : NexusGuard.purple,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KOMPLEKGUARD VOICE AI',
                    style: NexusGuard.orbitron(
                      size: 15,
                      color: NexusGuard.purple,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _listening
                        ? 'Sedang mendengarkan suara kamu...'
                        : 'Tanya AI dengan teks atau suara tentang keamanan lingkungan.',
                    style: NexusGuard.rajdhani(
                      size: 14,
                      color: NexusGuard.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickGuideBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('chat_offline_guide'),
          onPressed: _openQuickGuides,
          icon: const Icon(Icons.offline_bolt_outlined, size: 20),
          label: const Text('Panduan Kilat • Tanpa Token AI'),
          style: OutlinedButton.styleFrom(
            foregroundColor: NexusGuard.emerald,
            side: const BorderSide(color: NexusGuard.emerald),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _quickQuestions() {
    final questions = [
      'Apa yang harus dilakukan jika mencium bau gas?',
      'Bagaimana menghadapi orang mencurigakan?',
      'Apa langkah awal saat terjadi kebakaran?',
      'Apakah lingkungan sedang aman hari ini?',
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ActionChip(
            backgroundColor: NexusGuard.panel.withValues(alpha: 0.9),
            side: BorderSide(
              color: NexusGuard.cyan.withValues(alpha: 0.35),
            ),
            label: Text(
              questions[index],
              style: NexusGuard.rajdhani(
                color: NexusGuard.text,
                size: 13,
              ),
            ),
            onPressed: () => _quickAsk(questions[index]),
          );
        },
      ),
    );
  }

  Widget _chatList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['role'] == 'USER';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth: 680),
            decoration: BoxDecoration(
              color: isUser
                  ? NexusGuard.cyan.withValues(alpha: 0.15)
                  : NexusGuard.panel.withValues(alpha: 0.92),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: Border.all(
                color: isUser
                    ? NexusGuard.cyan.withValues(alpha: 0.45)
                    : NexusGuard.purple.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isUser ? NexusGuard.cyan : NexusGuard.purple)
                      .withValues(alpha: 0.08),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'KAMU' : (msg['offlineGuide'] == true ? 'PANDUAN OFFLINE' : 'KOMPLEKGUARD AI'),
                  style: NexusGuard.mono(
                    size: 11,
                    color: isUser ? NexusGuard.cyan : NexusGuard.purple,
                  ),
                ),
                const SizedBox(height: 8),
                SafetyResponseText(
                  msg['message']?.toString() ?? '',
                  style: NexusGuard.rajdhani(
                    size: 16,
                    color: NexusGuard.text,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _voiceIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '🎙 Mendengarkan suara...',
        style: NexusGuard.mono(
          color: NexusGuard.red,
          size: 12,
        ),
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'AI sedang menganalisis...',
        style: NexusGuard.mono(
          color: NexusGuard.green,
          size: 12,
        ),
      ),
    );
  }

  Widget _inputBox() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: NexusGuard.bg.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
              color: NexusGuard.border.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                minLines: 1,
                maxLines: 4,
                style: NexusGuard.rajdhani(
                  color: NexusGuard.text,
                  size: 16,
                ),
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _listening
                      ? 'Suara kamu sedang ditulis otomatis...'
                      : 'Tanya AI tentang keamanan komplek...',
                  hintStyle: NexusGuard.rajdhani(
                    color: NexusGuard.muted2,
                  ),
                  filled: true,
                  fillColor: NexusGuard.panel.withValues(alpha: 0.85),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: NexusGuard.border.withValues(alpha: 0.7),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: NexusGuard.cyan,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              width: 52,
              child: ElevatedButton(
                onPressed: _toggleVoice,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor:
                      _listening ? NexusGuard.red : NexusGuard.purple,
                  foregroundColor: NexusGuard.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              width: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: NexusGuard.cyan,
                  foregroundColor: NexusGuard.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
