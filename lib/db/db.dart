// Skema DB & akses data. Penamaan tabel/kolom mengikuti DB asli
// (paises, eq_equipos, jug_jugadores, tor_partidos, dst).

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class Db {
  static Database? _db;

  /// Dipakai oleh unit test (sqflite_common_ffi).
  static DatabaseFactory? factoryOverride;
  static String? pathOverride;

  static Future<String> get _path async {
    if (pathOverride != null) return pathOverride!;
    final dir = await getDatabasesPath();
    await Directory(dir).create(recursive: true);
    return p.join(dir, 'kickoff_manager.db');
  }

  static Future<Database> openAt(String path) async {
    final factory = factoryOverride;
    if (factory != null) {
      return factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1, onCreate: (db, v) => _createSchema(db)));
    }
    return openDatabase(path, version: 1,
        onCreate: (db, v) async => _createSchema(db));
  }

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await openAt(await _path);
    return _db!;
  }

  static Future<void> closeAndDelete() async {
    final path = await _path;
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> _createSchema(Database db) async {
    const tables = [
      '''CREATE TABLE paises(paid INTEGER PRIMARY KEY, nombre TEXT, iso2 TEXT,
         poder INTEGER, pts INTEGER, confederacion TEXT)''',
      '''CREATE TABLE eq_estadios(estaid INTEGER PRIMARY KEY, es_nombre TEXT,
         es_tot_general INTEGER, es_tot_plateas INTEGER, es_tot_tribunas INTEGER,
         es_tot_palcos INTEGER, es_max_general INTEGER, es_max_plateas INTEGER,
         es_max_tribunas INTEGER, es_max_palcos INTEGER, es_precio INTEGER,
         es_paid INTEGER)''',
      '''CREATE TABLE eq_equipos(equid INTEGER PRIMARY KEY, equi_abrev TEXT,
         equi_nombre TEXT, equi_funda INTEGER, equi_valor INTEGER,
         equi_poder INTEGER, equi_presupuesto INTEGER, equi_pts INTEGER,
         equi_estaid INTEGER, equi_paid INTEGER, equi_division INTEGER,
         equi_color_a TEXT, equi_color_b TEXT, equi_is_user INTEGER DEFAULT 0,
         equi_rep INTEGER DEFAULT 60)''',
      '''CREATE TABLE jug_jugadores(jugid INTEGER PRIMARY KEY, jug_nombre TEXT,
         jug_edad INTEGER, jug_estatura INTEGER, jug_star INTEGER,
         jug_valor INTEGER, jug_salario INTEGER, jug_perfil TEXT,
         jug_experiencia INTEGER, jug_condicion INTEGER, jug_jstdid INTEGER,
         jug_poder INTEGER, jug_potencial INTEGER, jug_mercado INTEGER,
         jug_paid INTEGER, jug_posid INTEGER, jug_titular INTEGER,
         jug_capitan INTEGER, jug_numero INTEGER, jug_campeonatos INTEGER,
         jug_pts INTEGER, jug_habilidad_A INTEGER, jug_habilidad_B INTEGER,
         jug_ritmo INTEGER, jug_tiro INTEGER, jug_pase INTEGER,
         jug_regate INTEGER, jug_defensa INTEGER, jug_fisico INTEGER,
         jug_kiper INTEGER, jug_lesion INTEGER DEFAULT 0,
         jug_susp INTEGER DEFAULT 0)''',
      '''CREATE TABLE eq_equipos_jugadores(eqju_equid INTEGER,
         eqju_jugid INTEGER, PRIMARY KEY(eqju_equid, eqju_jugid))''',
      '''CREATE TABLE jug_contratos(jc_id INTEGER PRIMARY KEY AUTOINCREMENT,
         jc_jugid INTEGER, jc_equid INTEGER, jc_inicio INTEGER, jc_fin INTEGER,
         jc_status INTEGER, jc_salario INTEGER, jc_bono_gol INTEGER,
         jc_bono_asis INTEGER, jc_bono_mvp INTEGER, jc_bono_campe INTEGER,
         jc_bono_pj INTEGER)''',
      '''CREATE TABLE tor_torneos(torid INTEGER PRIMARY KEY, tor_nombre TEXT,
         tor_idiv INTEGER, tor_status INTEGER, tor_organizacion INTEGER,
         tor_vueltas INTEGER, tor_fecha_1 TEXT, tor_cupos INTEGER,
         tor_pts REAL, tor_premio_equipos INTEGER, tor_premio_goleador INTEGER,
         tor_premio_mvps INTEGER, tor_pais INTEGER)''',
      '''CREATE TABLE tor_temporadas(tempid INTEGER PRIMARY KEY, tem_nombre TEXT,
         tem_anioinicio INTEGER, tem_aniofin INTEGER)''',
      '''CREATE TABLE tor_temporadas_equipos(te_id INTEGER PRIMARY KEY AUTOINCREMENT,
         te_equid INTEGER, te_tempid INTEGER, te_pos INTEGER, te_pj INTEGER,
         te_pg INTEGER, te_pe INTEGER, te_pp INTEGER, te_gf INTEGER,
         te_gc INTEGER, te_pts INTEGER, te_forma TEXT)''',
      '''CREATE TABLE tor_partidos(partid INTEGER PRIMARY KEY AUTOINCREMENT,
         par_torid INTEGER, par_tempid INTEGER, par_estaid INTEGER,
         par_equid_local INTEGER, par_equid_visita INTEGER,
         par_goles_local INTEGER, par_goles_visita INTEGER, par_gana INTEGER,
         par_esp_general INTEGER, par_esp_plateas INTEGER,
         par_esp_tribunas INTEGER, par_esp_palcos INTEGER,
         par_ent_ingresos INTEGER, par_fase INTEGER, par_jornada INTEGER,
         par_status INTEGER, par_fecha TEXT, par_vuelta INTEGER, par_penal_goles_local INTEGER,
         par_penal_goles_visita INTEGER)''',
      '''CREATE TABLE tor_partidos_jugadores(tpj_id INTEGER PRIMARY KEY AUTOINCREMENT,
         tpj_partid INTEGER, tpj_jugid INTEGER, tpj_equid INTEGER,
         tpj_titular INTEGER, tpj_min INTEGER, tpj_goles INTEGER,
         tpj_asis INTEGER, tpj_amarilla INTEGER, tpj_roja INTEGER,
         tpj_rating REAL, tpj_mvp INTEGER, tpj_atajadas INTEGER,
         tpj_tiros INTEGER)''',
      '''CREATE TABLE jus_stats(js_jugid INTEGER, js_equid INTEGER,
         js_tempid INTEGER, js_pj INTEGER, js_min INTEGER, js_titular INTEGER,
         js_amarillas INTEGER, js_rojas INTEGER, js_mvps INTEGER,
         js_goles INTEGER, js_asistencias INTEGER,
         PRIMARY KEY(js_jugid, js_tempid))''',
      '''CREATE TABLE tor_transferencias_jugadores(tra_id INTEGER PRIMARY KEY AUTOINCREMENT,
         tra_jugid INTEGER, tra_equid_origen INTEGER, tra_equid_destino INTEGER,
         tra_tipo_transferencia TEXT, tra_valor INTEGER, tra_fecha TEXT,
         tra_semana INTEGER, tra_nombre TEXT DEFAULT '')''',
      '''CREATE TABLE jug_premios(premid INTEGER PRIMARY KEY AUTOINCREMENT,
         jugid INTEGER, equid INTEGER, tipo TEXT, anio INTEGER, tempid INTEGER,
         goles INTEGER)''',
      '''CREATE TABLE mensajes(msg_id INTEGER PRIMARY KEY AUTOINCREMENT,
         msg_titulo TEXT, msg_texto TEXT, msg_tipo TEXT, msg_semana INTEGER,
         msg_leido INTEGER DEFAULT 0)''',
      '''CREATE TABLE historial_temporadas(hist_id INTEGER PRIMARY KEY AUTOINCREMENT,
         hist_tempid INTEGER, hist_anio INTEGER, hist_campeon_equid INTEGER,
         hist_campeon_nombre TEXT, hist_user_pos INTEGER, hist_user_pts INTEGER,
         hist_user_equid INTEGER, hist_goleador TEXT, hist_goles INTEGER,
         hist_mvp TEXT)''',
      '''CREATE TABLE save_state(sk TEXT PRIMARY KEY, sv TEXT)''',
    ];
    for (final t in tables) {
      await db.execute(t);
    }
  }
}

// ================= Helpers =================

class SaveState {
  final Map<String, String> _m;
  SaveState(this._m);
  String? operator [](String k) => _m[k];
  int i(String k, [int d = 0]) => int.tryParse(_m[k] ?? '') ?? d;
  bool b(String k, [bool d = false]) =>
      _m[k] == null ? d : _m[k] == '1';
  Tactics tactics() {
    final raw = _m['tactics'];
    if (raw == null) return Tactics();
    return Tactics.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  ManagerProfile managerProfile() {
    final raw = _m['manager_profile'];
    if (raw == null || raw.isEmpty) {
      return ManagerProfile(name: _m['manager'] ?? 'Pelatih');
    }
    try {
      return ManagerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ManagerProfile(name: _m['manager'] ?? 'Pelatih');
    }
  }
}

class World {
  final Database db;
  World(this.db);

  Future<SaveState> state() async {
    final rows = await db.query('save_state');
    return SaveState({
      for (final r in rows) r['sk'] as String: (r['sv'] ?? '') as String
    });
  }

  Future<void> setState(String key, String value) async {
    await db.insert('save_state', {'sk': key, 'sv': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setInt(String key, int v) => setState(key, '$v');
  Future<void> setBool(String key, bool v) => setState(key, v ? '1' : '0');

  // ---------- Team / Player mapping ----------

  Team teamFromRow(Map<String, dynamic> r) => Team(
        r['equid'] as int,
        (r['equi_abrev'] ?? '') as String,
        r['equi_nombre'] as String,
        (r['equi_funda'] ?? 1900) as int,
        (r['equi_valor'] ?? 0) as int,
        (r['equi_poder'] ?? 50) as int,
        (r['equi_presupuesto'] ?? 0) as int,
        (r['equi_pts'] ?? 0) as int,
        (r['equi_estaid'] ?? 0) as int,
        (r['equi_paid'] ?? 0) as int,
        (r['equi_division'] ?? 1) as int,
        colorA: (r['equi_color_a'] ?? '#1B5E20') as String,
        colorB: (r['equi_color_b'] ?? '#FFFFFF') as String,
      );

  Player playerFromRow(Map<String, dynamic> r) => Player(
        jugid: r['jugid'] as int,
        nombre: r['jug_nombre'] as String,
        edad: (r['jug_edad'] ?? 20) as int,
        estatura: (r['jug_estatura'] ?? 175) as int,
        star: (r['jug_star'] ?? 0) as int,
        valor: (r['jug_valor'] ?? 0) as int,
        salario: (r['jug_salario'] ?? 0) as int,
        perfil: (r['jug_perfil'] ?? 'D') as String,
        experiencia: (r['jug_experiencia'] ?? 0) as int,
        condicion: (r['jug_condicion'] ?? 100) as int,
        jstdid: (r['jug_jstdid'] ?? 1) as int,
        poder: (r['jug_poder'] ?? 50) as int,
        potencial: (r['jug_potencial'] ?? 60) as int,
        mercado: (r['jug_mercado'] ?? 0) as int,
        paid: (r['jug_paid'] ?? 0) as int,
        posid: (r['jug_posid'] ?? 7) as int,
        titular: (r['jug_titular'] ?? 0) as int,
        capitan: (r['jug_capitan'] ?? 0) as int,
        numero: (r['jug_numero'] ?? 0) as int,
        campeonatos: (r['jug_campeonatos'] ?? 0) as int,
        pts: (r['jug_pts'] ?? 0) as int,
        habA: (r['jug_habilidad_A'] ?? 16) as int,
        habB: (r['jug_habilidad_B'] ?? 13) as int,
        ritmo: (r['jug_ritmo'] ?? 50) as int,
        tembakan: (r['jug_tiro'] ?? 50) as int,
        pases: (r['jug_pase'] ?? 50) as int,
        regate: (r['jug_regate'] ?? 50) as int,
        defensa: (r['jug_defensa'] ?? 50) as int,
        fisik: (r['jug_fisico'] ?? 50) as int,
        kiper: (r['jug_kiper'] ?? 30) as int,
        lesionSemanas: (r['jug_lesion'] ?? 0) as int,
        suspSemanas: (r['jug_susp'] ?? 0) as int,
      );

  // ---------- Queries ----------

  Future<List<Team>> allTeams() async {
    final rows = await db.query('eq_equipos', orderBy: 'equid');
    return rows.map(teamFromRow).toList();
  }

  Future<Team?> team(int equid) async {
    final rows =
        await db.query('eq_equipos', where: 'equid = ?', whereArgs: [equid]);
    if (rows.isEmpty) return null;
    return teamFromRow(rows.first);
  }

  Future<Stadium> stadium(int estaid) async {
    final rows =
        await db.query('eq_estadios', where: 'estaid = ?', whereArgs: [estaid]);
    final r = rows.first;
    return Stadium(
      r['estaid'] as int,
      r['es_nombre'] as String,
      (r['es_tot_general'] ?? 0) as int,
      (r['es_tot_plateas'] ?? 0) as int,
      (r['es_tot_tribunas'] ?? 0) as int,
      (r['es_tot_palcos'] ?? 0) as int,
      (r['es_max_general'] ?? 0) as int,
      (r['es_max_plateas'] ?? 0) as int,
      (r['es_max_tribunas'] ?? 0) as int,
      (r['es_max_palcos'] ?? 0) as int,
      (r['es_precio'] ?? 25) as int,
      (r['es_paid'] ?? 0) as int,
    );
  }

  Future<List<Player>> squad(int equid) async {
    final rows = await db.rawQuery('''
      SELECT j.* FROM jug_jugadores j
      JOIN eq_equipos_jugadores ej ON ej.eqju_jugid = j.jugid
      WHERE ej.eqju_equid = ? AND j.jug_jstdid = 1
      ORDER BY j.jug_posid, j.jug_poder DESC
    ''', [equid]);
    return rows.map(playerFromRow).toList();
  }

  Future<Player?> player(int jugid) async {
    final rows =
        await db.query('jug_jugadores', where: 'jugid = ?', whereArgs: [jugid]);
    if (rows.isEmpty) return null;
    return playerFromRow(rows.first);
  }

  Future<int> teamOfPlayer(int jugid) async {
    final rows = await db.query('eq_equipos_jugadores',
        where: 'eqju_jugid = ?', whereArgs: [jugid]);
    if (rows.isEmpty) return 0;
    return rows.first['eqju_equid'] as int;
  }

  Future<List<Team>> tableFor(int tempid) async {
    final rows = await db.rawQuery('''
      SELECT e.* FROM eq_equipos e
      JOIN tor_temporadas_equipos te ON te.te_equid = e.equid
      WHERE te.te_tempid = ?
      ORDER BY te.te_pts DESC, (te.te_gf - te.te_gc) DESC, te.te_gf DESC
    ''', [tempid]);
    return rows.map(teamFromRow).toList();
  }

  Future<Map<int, Map<String, dynamic>>> seasonRows(int tempid) async {
    final rows = await db.query('tor_temporadas_equipos',
        where: 'te_tempid = ?', whereArgs: [tempid]);
    return {for (final r in rows) r['te_equid'] as int: r};
  }

  Future<List<Map<String, dynamic>>> fixturesFor(int tempid) async {
    return db.query('tor_partidos',
        where: 'par_tempid = ?', whereArgs: [tempid], orderBy: 'par_jornada, partid');
  }

  Future<List<Player>> topScorers(int tempid, {int limit = 10}) async {
    final rows = await db.rawQuery('''
      SELECT j.*, s.js_goles as g FROM jus_stats s
      JOIN jug_jugadores j ON j.jugid = s.js_jugid
      WHERE s.js_tempid = ? AND s.js_goles > 0
      ORDER BY s.js_goles DESC LIMIT ?
    ''', [tempid, limit]);
    return rows.map(playerFromRow).toList();
  }

  Future<Map<int, int>> scorerGoals(int tempid) async {
    final rows = await db.query('jus_stats',
        where: 'js_tempid = ?', whereArgs: [tempid]);
    return {
      for (final r in rows) r['js_jugid'] as int: (r['js_goles'] ?? 0) as int
    };
  }

  Future<List<Player>> topAssisters(int tempid, {int limit = 15}) async {
    final rows = await db.rawQuery('''
      SELECT j.*, s.js_asistencias as a FROM jus_stats s
      JOIN jug_jugadores j ON j.jugid = s.js_jugid
      WHERE s.js_tempid = ? AND s.js_asistencias > 0
      ORDER BY s.js_asistencias DESC LIMIT ?
    ''', [tempid, limit]);
    return rows.map(playerFromRow).toList();
  }

  Future<Map<int, int>> assisterCounts(int tempid) async {
    final rows = await db.query('jus_stats',
        where: 'js_tempid = ?', whereArgs: [tempid]);
    return {
      for (final r in rows)
        r['js_jugid'] as int: (r['js_asistencias'] ?? 0) as int
    };
  }

  Future<List<Map<String, dynamic>>> cupFixtures(int tempid,
      {int vuelta = 1}) async {
    return db.query('tor_partidos',
        where: 'par_tempid = ? AND par_vuelta = ?',
        whereArgs: [tempid, vuelta],
        orderBy: 'par_fase DESC, partid ASC');
  }

  Future<List<String>> recentForm(int equid, int tempid, {int limit = 5}) async {
    final rows = await db.query(
      'tor_partidos',
      where:
          'par_tempid = ? AND par_status = 1 AND (par_equid_local = ? OR par_equid_visita = ?)',
      whereArgs: [tempid, equid, equid],
      orderBy: 'par_jornada DESC, partid DESC',
      limit: limit,
    );
    final out = <String>[];
    for (final r in rows.reversed) {
      final isHome = r['par_equid_local'] == equid;
      final gf = (isHome ? r['par_goles_local'] : r['par_goles_visita']) as int;
      final ga = (isHome ? r['par_goles_visita'] : r['par_goles_local']) as int;
      out.add(gf > ga ? 'M' : (gf == ga ? 'S' : 'K'));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> messages({int limit = 50}) async {
    return db.query('mensajes', orderBy: 'msg_id DESC', limit: limit);
  }

  Future<void> addMessage(String title, String text, String type, int week) async {
    await db.insert('mensajes', {
      'msg_titulo': title,
      'msg_texto': text,
      'msg_tipo': type,
      'msg_semana': week,
      'msg_leido': 0,
    });
  }

  Future<int> unreadMessages() async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) c FROM mensajes WHERE msg_leido = 0');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> transfers({int limit = 100}) async {
    return db.query('tor_transferencias_jugadores',
        orderBy: 'tra_id DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> history() async {
    return db.query('historial_temporadas', orderBy: 'hist_anio DESC');
  }
}
