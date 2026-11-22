import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../theme.dart';
import '../widgets.dart';

class InboxScreen extends StatefulWidget {
  final GameService service;
  const InboxScreen({super.key, required this.service});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>>? msgs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await widget.service.world.messages();
    await widget.service.markMessagesRead();
    if (!mounted) return;
    setState(() => msgs = m);
  }

  IconData _icon(String type) {
    switch (type) {
      case 'finance':
        return Icons.savings;
      case 'transfer':
        return Icons.swap_horiz;
      case 'season':
        return Icons.emoji_events;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kotak Masuk')),
      body: msgs == null
          ? const Center(child: CircularProgressIndicator())
          : msgs!.isEmpty
              ? const EmptyState(
                  icon: Icons.mail_outline, text: 'Belum ada pesan.')
              : ListView.separated(
                  itemCount: msgs!.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final m = msgs![i];
                    final unread = (m['msg_leido'] as int? ?? 1) == 0;
                    return ListTile(
                      leading: Icon(_icon(m['msg_tipo'] as String? ?? 'info'),
                          color: unread ? AppColors.primary : AppColors.muted),
                      title: Text(m['msg_titulo'] ?? '',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w500)),
                      subtitle: Text(m['msg_texto'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted)),
                      onTap: () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(m['msg_titulo'] ?? ''),
                          content: Text(m['msg_texto'] ?? '',
                              style: const TextStyle(fontSize: 13, height: 1.4)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Tutup'))
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
