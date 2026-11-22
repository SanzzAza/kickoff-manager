import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tactics_screen.dart';
import 'inbox_screen.dart';
import 'club_pages.dart';

class MenuScreen extends StatelessWidget {
  final GameService service;
  const MenuScreen({super.key, required this.service});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        children: [
          SectionTitle('Tim'),
          _item(context, Icons.psychology, 'Taktik & formasi',
              'Formasi, mentalitas, pressing, gaya main',
              (ctx) => TacticsScreen(service: service)),
          _item(context, Icons.fitness_center, 'Latihan',
              'Program latihan mingguan dan perkembangan pemain',
              (ctx) => TrainingScreen(service: service)),
          _item(context, Icons.stadium, 'Stadion',
              'Kapasitas tribun, harga tiket, ekspansi',
              (ctx) => StadiumScreen(service: service)),
          const Divider(),
          SectionTitle('Klub'),
          _item(context, Icons.savings, 'Finansial',
              'Pemasukan, gaji, operasional, sponsor',
              (ctx) => FinanceScreen(service: service)),
          _item(context, Icons.mail_outline, 'Kotak masuk',
              'Pesan dari direksi, agen, dan media',
              (ctx) => InboxScreen(service: service)),
          _item(context, Icons.emoji_events, 'Sejarah & trofi',
              'Musim-musim sebelumnya',
              (ctx) => HistoryScreen(service: service)),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String sub,
      Widget Function(BuildContext) builder) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(sub,
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: builder)),
    );
  }
}
