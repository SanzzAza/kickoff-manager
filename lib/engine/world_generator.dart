// Generator dunia: klub, stadion, pemain, kontrak, kalender.
// Meniru perilaku WizardNuevaPartida / FuncionesEditor pada game asli.

import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../data/football_data.dart';

class WorldGenerator {
  final Database db;
  final Random rng;
  DatabaseExecutor? _ex;

  /// Semua penulisan bisa dialihkan ke transaksi agar cepat.
  set executor(DatabaseExecutor e) => _ex = e;
  DatabaseExecutor get ex => _ex ?? db;

  /// Nama "legenda" fiktif untuk pemain bintang (orisinal, bukan pemain nyata).
  static const List<List<String>> starPool = [
    ['Rafael Montero', '10'], ['Yuri Balacano', '10'], ['Idris Kowalski', '9'],
    ['Tomas Vidal', '6'], ['Samir El Amri', '9'], ['Lautaro Benelli', '10'],
    ['Niko Ferrand', '5'], ['Kasper Lindgren', '6'], ['Davi Marchetti', '10'],
    ['Anwar Haddadi', '9'], ['Ethan Caldwell', '9'], ['Matteo Baresi', '11'],
    ['Luca Wunderlich', '6'], ['Emre Sancak', '6'], ['Diego Valbuena', '7'],
    ['Ilias Becker', '1'], ['Nikola Stanković', '1'], ['Adrián Costa', '1'],
    ['Rúben Salgado', '2'], ['Viktor Halden', '2'], ['Allan Mbeki', '2'],
    ['Yassine Barrada', '4'], ['Joris Van Dale', '4'], ['Sander Kolderup', '6'],
    ['Tarik Ziani', '9'], ['Emmanuel Okoro', '10'], ['Reynaldo Duarte', '9'],
    ['Nico Almeida', '9'], ['Pau Serra', '7'], ['Álvaro Quintero', '7'],
  ];

  WorldGenerator(this.db, [Random? r]) : rng = r ?? Random();

  static const List<List<String>> _colores = [
    ['#C62828', '#FFFFFF'], ['#1565C0', '#FFFFFF'], ['#2E7D32', '#FFFFFF'],
    ['#6A1B9A', '#FFFFFF'], ['#EF6C00', '#212121'], ['#00695C', '#FFFFFF'],
    ['#283593', '#FFEB3B'], ['#AD1457', '#FFFFFF'], ['#212121', '#F44336'],
    ['#F9A825', '#212121'], ['#00838F', '#FFFFFF'], ['#4E342E', '#FFD54F'],
  ];

  int _poderPorRango(int base, double factor) {
    final v = base * factor + rng.nextInt(9) - 4;
    return v.round().clamp(30, 99);
  }

  Future<int> buildWorld({required String playerName, required String leagueName,
      required String clubName, required int seedPaisIndex}) async {
    await _paises();
    int torid = 1;
    int equid = 1;
    int estaid = 1;
    int jugid = 1;
    final stars = List.of(starPool);
    stars.shuffle(rng);

    for (var li = 0; li < leagues.length; li++) {
      final l = leagues[li];
      final leagueSeed = li + 1;
      // Piala domestik untuk tiap negara (organizacion 3 = copa)
      await ex.insert('tor_torneos', {
        'torid': torid,
        'tor_nombre': 'Copa ${l.country}',
        'tor_idiv': 0,
        'tor_status': 1,
        'tor_organizacion': 3,
        'tor_vueltas': 1,
        'tor_fecha_1': '01-02',
        'tor_cupos': 16,
        'tor_pts': 0.8,
        'tor_premio_equipos': (l.prize * 0.5).round(),
        'tor_premio_goleador': 500000,
        'tor_premio_mvps': 100000,
        'tor_pais': l.iso.codeUnitAt(0),
      });
      torid++;
      final ligaTorId = torid;
      await ex.insert('tor_torneos', {
        'torid': ligaTorId,
        'tor_nombre': l.name,
        'tor_idiv': 1,
        'tor_status': 1,
        'tor_organizacion': 1,
        'tor_vueltas': 1,
        'tor_fecha_1': '01-02',
        'tor_cupos': l.teams,
        'tor_pts': 1.0,
        'tor_premio_equipos': l.prize,
        'tor_premio_goleador': (l.prize * 0.12).round(),
        'tor_premio_mvps': (l.prize * 0.06).round(),
        'tor_pais': l.iso.codeUnitAt(0),
      });
      torid++;

      final teamsInLeague = <int>[];
      final n = min(l.clubs.length, l.teams);
      for (var i = 0; i < n; i++) {
        final isUser = clubName == l.clubs[i] && l.name == leagueName;
        // Kekuatan: klub teratas lebih kuat, menyebar halus
        final factor = 1.0 - (i / max(1, n - 1)) * 0.26;
        final poder = (isUser
                ? _poderPorRango(l.base - 3, factor)
                : _poderPorRango(l.base, factor))
            .clamp((l.base * 0.74).round(), (l.base * 1.08).round());
        final colors = _colores[rng.nextInt(_colores.length)];
        final capBase = (8000 + rng.nextInt(22000) * factor).round();

        await ex.insert('eq_estadios', {
          'estaid': estaid,
          'es_nombre': '${l.clubs[i]} Arena',
          'es_tot_general': capBase,
          'es_tot_plateas': (capBase * 0.35).round(),
          'es_tot_tribunas': (capBase * 0.22).round(),
          'es_tot_palcos': (capBase * 0.07).round(),
          'es_max_general': (capBase * 1.4).round(),
          'es_max_plateas': (capBase * 0.49).round(),
          'es_max_tribunas': (capBase * 0.31).round(),
          'es_max_palcos': (capBase * 0.10).round(),
          'es_precio': 18 + rng.nextInt(45),
          'es_paid': leagueSeed,
        });

        final presupuesto = isUser
            ? (poder * poder * 1600).round()
            : (poder * poder * 2400).round();

        await ex.insert('eq_equipos', {
          'equid': equid,
          'equi_abrev': _abrev(l.clubs[i]),
          'equi_nombre': l.clubs[i],
          'equi_funda': 1890 + rng.nextInt(120),
          'equi_valor': (poder * poder * 9000).round(),
          'equi_poder': poder,
          'equi_presupuesto': presupuesto,
          'equi_pts': 0,
          'equi_estaid': estaid,
          'equi_paid': leagueSeed,
          'equi_division': 1,
          'equi_color_a': colors[0],
          'equi_color_b': colors[1],
          'equi_is_user': isUser ? 1 : 0,
          'equi_rep': (55 + poder / 2).round().clamp(50, 98),
        });
        teamsInLeague.add(equid);

        // Skuad 24 pemain
        final usedNumbers = <int>{};
        final usedNames = <String>{};
        final isBig = i < 6;
        for (var s = 0; s < 24; s++) {
          final posid = _posForSlot(s);
          final clubBase = poder;
          int playerPoder;
          if (s < 11) {
            playerPoder = poder_titular(clubBase, s);
          } else {
            playerPoder =
                (poder_titular(clubBase, s) - 5 - rng.nextInt(8)).clamp(30, 99);
          }
          var nombre = _randomName(leagueSeed);
          var guard = 0;
          while (usedNames.contains(nombre) && guard++ < 12) {
            nombre = _randomName(leagueSeed);
          }
          usedNames.add(nombre);
          const star = 0;
          final edad = 17 + rng.nextInt(20);
          final potencial = (playerPoder +
                  (edad <= 21 ? 8 : edad <= 25 ? 4 : 1) +
                  rng.nextInt(10) -
                  rng.nextInt(4))
              .clamp(30, 99);
          final numero = _numberFor(posid, usedNumbers);
          final attrs = _attrsFor(posid, playerPoder);
          final valor = _valorFor(playerPoder, edad, potencial, star);
          final salario = (valor / 180).round() + 8000;
          final perfil = rng.nextBool() ? 'I' : 'D';

          await ex.insert('jug_jugadores', {
            'jugid': jugid,
            'jug_nombre': nombre,
            'jug_edad': edad,
            'jug_estatura': 168 + rng.nextInt(24),
            'jug_star': star,
            'jug_valor': valor,
            'jug_salario': salario,
            'jug_perfil': perfil,
            'jug_experiencia': rng.nextInt(6),
            'jug_condicion': 100,
            'jug_jstdid': 1,
            'jug_poder': playerPoder,
            'jug_potencial': potencial,
            'jug_mercado': (s >= 11 && rng.nextBool()) ? 1 : 0,
            'jug_paid': leagueSeed,
            'jug_posid': posid,
            'jug_titular': s < 11 ? 1 : 0,
            'jug_capitan': (s == 3) ? 1 : 0,
            'jug_numero': numero,
            'jug_campeonatos': 0,
            'jug_pts': 0,
            'jug_habilidad_A': attrs[0],
            'jug_habilidad_B': attrs[1],
            'jug_ritmo': attrs[2],
            'jug_tiro': attrs[3],
            'jug_pase': attrs[4],
            'jug_regate': attrs[5],
            'jug_defensa': attrs[6],
            'jug_fisico': attrs[7],
            'jug_kiper': attrs[8],
            'jug_lesion': 0,
          });
          await ex.insert('eq_equipos_jugadores',
              {'eqju_equid': equid, 'eqju_jugid': jugid});
          await ex.insert('jug_contratos', {
            'jc_jugid': jugid,
            'jc_equid': equid,
            'jc_inicio': 2026,
            'jc_fin': 2026 + 1 + rng.nextInt(4),
            'jc_status': 1,
            'jc_salario': salario,
            'jc_bono_gol': (salario * 0.2).round(),
            'jc_bono_asis': (salario * 0.1).round(),
            'jc_bono_mvp': (salario * 0.15).round(),
            'jc_bono_campe': (salario * 0.8).round(),
            'jc_bono_pj': (salario * 0.3).round(),
          });
          jugid++;
        }

        // Ganti satu pemain dengan bintang dunia untuk klub besar
        if (isBig && stars.isNotEmpty && rng.nextDouble() < 0.32) {
          final s = stars.removeLast();
          final pos = _posIdFromAbrev(s[1]);
          await ex.insert('jug_jugadores', {
            'jugid': jugid,
            'jug_nombre': s[0],
            'jug_edad': 21 + rng.nextInt(9),
            'jug_estatura': 172 + rng.nextInt(20),
            'jug_star': 1,
            'jug_valor': 60000000 + rng.nextInt(140000000),
            'jug_salario': 400000 + rng.nextInt(400000),
            'jug_perfil': 'I',
            'jug_experiencia': 4,
            'jug_condicion': 100,
            'jug_jstdid': 1,
            'jug_poder': 90 + rng.nextInt(7),
            'jug_potencial': 97,
            'jug_mercado': 0,
            'jug_paid': leagueSeed,
            'jug_posid': pos,
            'jug_titular': 1,
            'jug_capitan': 0,
            'jug_numero': _numberFor(pos, usedNumbers),
            'jug_campeonatos': 0,
            'jug_pts': 0,
            'jug_habilidad_A': 9,
            'jug_habilidad_B': 13,
            'jug_ritmo': 88 + rng.nextInt(10),
            'jug_tiro': 86 + rng.nextInt(12),
            'jug_pase': 82 + rng.nextInt(15),
            'jug_regate': 86 + rng.nextInt(12),
            'jug_defensa': 40 + rng.nextInt(30),
            'jug_fisico': 78 + rng.nextInt(18),
            'jug_kiper': pos == 1 ? 90 : 25,
            'jug_lesion': 0,
          });
          await ex.insert('eq_equipos_jugadores',
              {'eqju_equid': equid, 'eqju_jugid': jugid});
          await ex.insert('jug_contratos', {
            'jc_jugid': jugid,
            'jc_equid': equid,
            'jc_inicio': 2026,
            'jc_fin': 2030,
            'jc_status': 1,
            'jc_salario': 700000,
            'jc_bono_gol': 150000,
            'jc_bono_asis': 80000,
            'jc_bono_mvp': 120000,
            'jc_bono_campe': 500000,
            'jc_bono_pj': 200000,
          });
          jugid++;
        }
        estaid++;
        equid++;
      }
    }
    return 0;
  }

  /// Dipakai saat regenerasi skuad (pemain pensiun / klub kekurangan pemain).
  Future<void> fillSquad(int equid, int clubPoder) async {
    final cur = await db.rawQuery(
        'SELECT COUNT(*) c FROM eq_equipos_jugadores WHERE eqju_equid = ?', [equid]);
    var count = (cur.first['c'] as int?) ?? 0;
    final maxRow = await db.rawQuery('SELECT MAX(jugid) m FROM jug_jugadores');
    var nextId = ((maxRow.first['m'] as int?) ?? 0) + 1;
    var slot = count;
    while (count < 22) {
      final posid = _posForSlot(slot % 24);
      final poder = (clubPoder - 3 + rng.nextInt(10)).clamp(30, 95);
      final edad = 17 + rng.nextInt(6);
      final potencial = (poder + rng.nextInt(16)).clamp(30, 99);
      final attrs = _attrsFor(posid, poder);
      final valor = _valorFor(poder, edad, potencial, 0);
      final salario = (valor / 180).round() + 8000;
      await ex.insert('jug_jugadores', {
        'jugid': nextId,
        'jug_nombre': _randomName(rng.nextInt(_isos.length) + 1),
        'jug_edad': edad,
        'jug_estatura': 168 + rng.nextInt(24),
        'jug_star': 0,
        'jug_valor': valor,
        'jug_salario': salario,
        'jug_perfil': rng.nextBool() ? 'I' : 'D',
        'jug_experiencia': 0,
        'jug_condicion': 100,
        'jug_jstdid': 1,
        'jug_poder': poder,
        'jug_potencial': potencial,
        'jug_mercado': 0,
        'jug_paid': 0,
        'jug_posid': posid,
        'jug_titular': count < 11 ? 1 : 0,
        'jug_capitan': 0,
        'jug_numero': count + 1,
        'jug_campeonatos': 0,
        'jug_pts': 0,
        'jug_habilidad_A': attrs[0],
        'jug_habilidad_B': attrs[1],
        'jug_ritmo': attrs[2],
        'jug_tiro': attrs[3],
        'jug_pase': attrs[4],
        'jug_regate': attrs[5],
        'jug_defensa': attrs[6],
        'jug_fisico': attrs[7],
        'jug_kiper': attrs[8],
        'jug_lesion': 0,
      });
      await ex.insert('eq_equipos_jugadores',
          {'eqju_equid': equid, 'eqju_jugid': nextId});
      nextId++;
      count++;
      slot++;
    }
  }

  int poder_titular(int clubPoder, int slot) {
    final delta = rng.nextInt(9) - 4;
    if (slot < 4) return (clubPoder + 1 + delta * 0.7).round().clamp(30, 99);
    if (slot < 11) return (clubPoder + delta * 0.6).round().clamp(30, 99);
    return (clubPoder - 6 + delta).round().clamp(28, 99);
  }

  int _posForSlot(int s) {
    // 1 POR, 2-5 def, 6-8 med, 9-11 del (starter) lalu cadangan
    if (s == 0 || s == 11 || s == 19) return 1;
    if (s >= 1 && s <= 4) return [2, 2, 4, 4][s - 1];
    if (s >= 5 && s <= 7) return [7, 5, 7][s - 5];
    if (s >= 12 && s <= 15) return [2, 3, 4, 4][s - 12];
    if (s >= 16 && s <= 18) return [5, 6, 8][s - 16];
    if (s >= 20 && s <= 22) return [6, 9, 10][s - 20];
    return 11;
  }

  int _posIdFromAbrev(String a) {
    switch (a) {
      case '1':
        return 1;
      case '2':
        return 2;
      case '4':
        return 4;
      case '5':
        return 5;
      case '6':
        return 6;
      case '7':
        return 7;
      case '9':
        return 9;
      case '11':
        return 11;
      default:
        return 10;
    }
  }

  int _numberFor(int posid, Set<int> used) {
    final prefs = posid == 1
        ? [1, 12, 25, 13]
        : posid <= 4
            ? [2, 3, 4, 5, 6, 15, 18, 22, 24]
            : posid <= 8
                ? [8, 10, 14, 16, 17, 20, 21, 23]
                : [7, 9, 11, 19, 26, 27, 29, 30];
    for (final n in prefs) {
      if (!used.contains(n)) {
        used.add(n);
        return n;
      }
    }
    var n = 28;
    while (used.contains(n)) {
      n++;
    }
    used.add(n);
    return n;
  }

  List<int> _attrsFor(int posid, int poder) {
    int r(int m) => (poder + rng.nextInt(17) - m).clamp(25, 99);
    final isGk = posid == 1;
    final isDef = posid >= 2 && posid <= 4;
    final isMid = posid >= 5 && posid <= 8;
    final isAtt = posid >= 9;
    final ritmo = isGk ? r(22) : r(isAtt ? 2 : isDef ? 8 : 4);
    final tiro = isGk ? r(45) : r(isAtt ? 2 : isMid ? 6 : 20);
    final pase = isGk ? r(30) : r(isMid ? 2 : isAtt ? 5 : 14);
    final regate = isGk ? r(45) : r(isAtt ? 2 : isMid ? 5 : 18);
    final defensa = isGk ? 30 : r(isDef ? 2 : isMid ? 6 : 30);
    final fisico = r(isDef ? 3 : 8);
    final kiper = isGk ? (poder + rng.nextInt(6)).clamp(20, 99) : (25 + rng.nextInt(12));
    final habA = isGk
        ? 1
        : isDef
            ? [6, 7, 3][rng.nextInt(3)]
            : isMid
                ? [16, 15, 23][rng.nextInt(3)]
                : [9, 19, 13][rng.nextInt(3)];
    final habB = isGk
        ? 2
        : isDef
            ? 11
            : isMid
                ? 17
                : 24;
    return [habA, habB, ritmo, tiro, pase, regate, defensa, fisico, kiper];
  }

  int _valorFor(int poder, int edad, int potencial, int star) {
    final edadF = edad <= 21
        ? 1.45
        : edad <= 25
            ? 1.30
            : edad <= 29
                ? 1.0
                : edad <= 32
                    ? 0.65
                    : 0.35;
    final podF = pow(poder / 50, 4.2).toDouble();
    final potF = 1 + (potencial - poder) / 55;
    final base = 90000 * podF * edadF * potF * (star == 1 ? 6.0 : 1.0);
    return max(50000, base.round());
  }

  String _abrev(String name) {
    final words =
        name.replaceAll('.', '').split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty).toList();
    if (words.length == 1) {
      return words.first.substring(0, min(3, words.first.length)).toUpperCase();
    }
    return words
        .take(3)
        .map((w) => w[0])
        .join()
        .toUpperCase();
  }

  Future<void> _paises() async {
    var id = 1;
    for (final entry in confederations.entries) {
      for (final c in entry.value) {
        final liga = leagues.firstWhere((l) => l.country == c);
        await ex.insert('paises', {
          'paid': id,
          'nombre': c,
          'iso2': liga.iso,
          'poder': liga.base,
          'pts': 0,
          'confederacion': entry.key,
        });
        id++;
      }
    }
  }

  String _randomName(int leagueSeed) {
    final iso = _isos[(leagueSeed - 1) % _isos.length];
    final cn = names[iso] ?? names['ES']!;
    // 80% nama khas negara liga, 20% nama asing (pemain impor)
    if (rng.nextDouble() < 0.2) {
      final other = names[_isos[rng.nextInt(_isos.length)]]!;
      return '${other.first[rng.nextInt(other.first.length)]} '
          '${cn.last[rng.nextInt(cn.last.length)]}';
    }
    return '${cn.first[rng.nextInt(cn.first.length)]} '
        '${cn.last[rng.nextInt(cn.last.length)]}';
  }
}

const List<String> _isos = [
  'ES', 'GB', 'IT', 'DE', 'FR', 'AR', 'BR', 'UY', 'MX', 'US', 'ID', 'JP', 'EG', 'MA'
];
