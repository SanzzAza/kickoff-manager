// Model domain game (mirror struktur tabel DB asli Super Kickoff).

import 'dart:math';

class Country {
  int paid;
  String nombre;
  String iso2;
  int poder;
  String confederacion;
  Country(this.paid, this.nombre, this.iso2, this.poder, this.confederacion);
}

class Stadium {
  int estaid;
  String nombre;
  int general;
  int plateas;
  int tribunas;
  int palcos;
  int maxGeneral;
  int maxPlateas;
  int maxTribunas;
  int maxPalcos;
  int precio; // harga tiket rata-rata
  int paid;
  Stadium(this.estaid, this.nombre, this.general, this.plateas, this.tribunas,
      this.palcos, this.maxGeneral, this.maxPlateas, this.maxTribunas,
      this.maxPalcos, this.precio, this.paid);

  int get capacity => general + plateas + tribunas + palcos;
  int get maxCapacity => maxGeneral + maxPlateas + maxTribunas + maxPalcos;
}

class Team {
  int equid;
  String abrev;
  String nombre;
  int fundacion;
  int valor;
  int poder;
  int presupuesto;
  int pts;
  int estaid;
  int paid;
  int division;
  String colorA;
  String colorB;
  Team(this.equid, this.abrev, this.nombre, this.fundacion, this.valor,
      this.poder, this.presupuesto, this.pts, this.estaid, this.paid,
      this.division, {this.colorA = '#1B5E20', this.colorB = '#FFFFFF'});
}

class Player {
  int jugid;
  String nombre;
  int edad;
  int estatura;
  int star; // 1 = bintang (superstar)
  int valor;
  int salario;
  String perfil; // I / D
  int experiencia;
  int condicion; // 0-100 kebugaran
  int jstdid; // 1 aktif, 2 pensiun, 3 cedera
  int poder;
  int potencial;
  int mercado; // 1 = masuk daftar transfer
  int paid;
  int posid;
  int titular;
  int capitan;
  int numero;
  int campeonatos;
  int pts;
  int habA;
  int habB;
  // 8 atribut inti (0-100)
  int ritmo;
  int tembakan;
  int pases;
  int regate;
  int defensa;
  int fisik;
  int kiper;
  int lesionSemanas;
  int suspSemanas;

  Player({
    required this.jugid,
    required this.nombre,
    required this.edad,
    required this.estatura,
    required this.star,
    required this.valor,
    required this.salario,
    required this.perfil,
    required this.experiencia,
    required this.condicion,
    required this.jstdid,
    required this.poder,
    required this.potencial,
    required this.mercado,
    required this.paid,
    required this.posid,
    required this.titular,
    required this.capitan,
    required this.numero,
    required this.campeonatos,
    required this.pts,
    required this.habA,
    required this.habB,
    required this.ritmo,
    required this.tembakan,
    required this.pases,
    required this.regate,
    required this.defensa,
    required this.fisik,
    required this.kiper,
    this.lesionSemanas = 0,
    this.suspSemanas = 0,
  });

  bool get lesionado => lesionSemanas > 0;
  bool get suspendido => suspSemanas > 0;
  bool get disponible => !lesionado && !suspendido;

  int get ataque => ((tembakan * 2 + regate + ritmo + pases) / 5).round();
  int get creacion => ((pases * 2 + regate + tembakan) / 4).round();
  int get defensivo =>
      posid == 1 ? kiper : ((defensa * 2 + fisik + posicional) / 4).round();
  int get posicional => ((defensa + pases + fisik) / 3).round();

  Player copyWith({
    int? condicion,
    int? lesionSemanas,
    int? suspSemanas,
    int? titular,
    int? poder,
    int? valor,
    int? salario,
  }) =>
      Player(
        jugid: jugid,
        nombre: nombre,
        edad: edad,
        estatura: estatura,
        star: star,
        valor: valor ?? this.valor,
        salario: salario ?? this.salario,
        perfil: perfil,
        experiencia: experiencia,
        condicion: condicion ?? this.condicion,
        jstdid: jstdid,
        poder: poder ?? this.poder,
        potencial: potencial,
        mercado: mercado,
        paid: paid,
        posid: posid,
        titular: titular ?? this.titular,
        capitan: capitan,
        numero: numero,
        campeonatos: campeonatos,
        pts: pts,
        habA: habA,
        habB: habB,
        ritmo: ritmo,
        tembakan: tembakan,
        pases: pases,
        regate: regate,
        defensa: defensa,
        fisik: fisik,
        kiper: kiper,
        lesionSemanas: lesionSemanas ?? this.lesionSemanas,
        suspSemanas: suspSemanas ?? this.suspSemanas,
      );
}

// ============ Taktik ============

enum Formation {
  f442('4-4-2'),
  f433('4-3-3'),
  f4231('4-2-3-1'),
  f352('3-5-2'),
  f343('3-4-3'),
  f451('4-5-1'),
  f532('5-3-2');

  final String label;
  const Formation(this.label);

  /// Baris per posisi: [kiper, def, med, del] + koordinat slot (x,y) 0..1.
  List<List<double>> get slots {
    switch (this) {
      case Formation.f442:
        return [
          [0.5, 0.93],
          [0.15, 0.74], [0.38, 0.78], [0.62, 0.78], [0.85, 0.74],
          [0.15, 0.52], [0.38, 0.56], [0.62, 0.56], [0.85, 0.52],
          [0.38, 0.24], [0.62, 0.24],
        ];
      case Formation.f433:
        return [
          [0.5, 0.93],
          [0.13, 0.75], [0.37, 0.79], [0.63, 0.79], [0.87, 0.75],
          [0.28, 0.55], [0.5, 0.60], [0.72, 0.55],
          [0.16, 0.28], [0.5, 0.18], [0.84, 0.28],
        ];
      case Formation.f4231:
        return [
          [0.5, 0.93],
          [0.13, 0.75], [0.37, 0.79], [0.63, 0.79], [0.87, 0.75],
          [0.36, 0.60], [0.64, 0.60],
          [0.16, 0.40], [0.5, 0.42], [0.84, 0.40],
          [0.5, 0.18],
        ];
      case Formation.f352:
        return [
          [0.5, 0.93],
          [0.28, 0.78], [0.5, 0.80], [0.72, 0.78],
          [0.1, 0.55], [0.3, 0.58], [0.5, 0.60], [0.7, 0.58], [0.9, 0.55],
          [0.38, 0.22], [0.62, 0.22],
        ];
      case Formation.f343:
        return [
          [0.5, 0.93],
          [0.28, 0.78], [0.5, 0.80], [0.72, 0.78],
          [0.12, 0.52], [0.38, 0.56], [0.62, 0.56], [0.88, 0.52],
          [0.18, 0.26], [0.5, 0.18], [0.82, 0.26],
        ];
      case Formation.f451:
        return [
          [0.5, 0.93],
          [0.13, 0.75], [0.37, 0.79], [0.63, 0.79], [0.87, 0.75],
          [0.1, 0.52], [0.32, 0.56], [0.5, 0.60], [0.68, 0.56], [0.9, 0.52],
          [0.5, 0.20],
        ];
      case Formation.f532:
        return [
          [0.5, 0.93],
          [0.1, 0.74], [0.3, 0.79], [0.5, 0.81], [0.7, 0.79], [0.9, 0.74],
          [0.25, 0.55], [0.5, 0.60], [0.75, 0.55],
          [0.38, 0.22], [0.62, 0.22],
        ];
    }
  }

  /// Peran ideal per slot: 1=POR, 2=DEF, 3=MED, 4=DEL
  List<int> get roles {
    switch (this) {
      case Formation.f442:
        return [1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4];
      case Formation.f433:
        return [1, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4];
      case Formation.f4231:
        return [1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4];
      case Formation.f352:
        return [1, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4];
      case Formation.f343:
        return [1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4];
      case Formation.f451:
        return [1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4];
      case Formation.f532:
        return [1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4];
    }
  }
}

class Mentality {
  static const defensivo = 'Defensivo';
  static const equilibrado = 'Equilibrado';
  static const ofensivo = 'Ofensivo';
  static const all = [defensivo, equilibrado, ofensivo];
}

class Pressure {
  static const baja = 'Baja';
  static const media = 'Media';
  static const alta = 'Alta';
  static const all = [baja, media, alta];
}

class Style {
  static const posesion = 'Posesión';
  static const contraataque = 'Contraataque';
  static const directo = 'Juego Directo';
  static const all = [posesion, contraataque, directo];
}

class Tactics {
  Formation formacion;
  String mentalidad;
  String presion;
  String estilo;
  int amplitud; // 1..5
  int linea; // 1..5 defensiva..adelantada
  Tactics({
    this.formacion = Formation.f433,
    this.mentalidad = Mentality.equilibrado,
    this.presion = Pressure.media,
    this.estilo = Style.posesion,
    this.amplitud = 3,
    this.linea = 3,
  });

  Tactics copy() => Tactics(
      formacion: formacion,
      mentalidad: mentalidad,
      presion: presion,
      estilo: estilo,
      amplitud: amplitud,
      linea: linea);

  Map<String, dynamic> toJson() => {
        'formacion': formacion.label,
        'mentalidad': mentalidad,
        'presion': presion,
        'estilo': estilo,
        'amplitud': amplitud,
        'linea': linea,
      };

  static Tactics fromJson(Map<String, dynamic> j) => Tactics(
        formacion: Formation.values.firstWhere((f) => f.label == j['formacion'],
            orElse: () => Formation.f433),
        mentalidad: (j['mentalidad'] ?? Mentality.equilibrado) as String,
        presion: (j['presion'] ?? Pressure.media) as String,
        estilo: (j['estilo'] ?? Style.posesion) as String,
        amplitud: (j['amplitud'] ?? 3) as int,
        linea: (j['linea'] ?? 3) as int,
      );
}

// ============ Pertandingan ============

class MatchEvent {
  final int minute;
  final String type;
  // gol, autogol, penalti_gol, penalti_fallado, amarilla, roja, lesion,
  // ocasion, atajada, palo, fuera_juego, falta, corner, cambio, inicio, final
  final int? team; // 0 local, 1 visitante
  final int? playerId;
  final String text;
  MatchEvent(this.minute, this.type, this.team, this.playerId, this.text);
}

class PlayerMatchStat {
  final int playerId;
  final int team;
  int goles = 0;
  int asistencias = 0;
  int tiros = 0;
  int atajadas = 0;
  int amarillas = 0;
  int rojas = 0;
  int minutos = 0;
  int faltas = 0;
  double rating = 6.0;
  PlayerMatchStat(this.playerId, this.team);
}

class MatchResult {
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;
  final Map<int, PlayerMatchStat> stats;
  final int homeShots;
  final int awayShots;
  final int homeOnTarget;
  final int awayOnTarget;
  final int homePossession;
  final int awayPossession;
  final List<int> homeInjured; // playerId -> minggu cedera di-set di service
  final List<int> awayInjured;
  final List<int> homeSuspended;
  final List<int> awaySuspended;
  final int? mvpId;
  final List<List<int>> penalties; // [home, away] seri penalti jika ada
  final int? penHome;
  final int? penAway;

  MatchResult({
    required this.homeGoals,
    required this.awayGoals,
    required this.events,
    required this.stats,
    required this.homeShots,
    required this.awayShots,
    required this.homeOnTarget,
    required this.awayOnTarget,
    required this.homePossession,
    required this.awayPossession,
    required this.homeInjured,
    required this.awayInjured,
    required this.homeSuspended,
    required this.awaySuspended,
    this.mvpId,
    this.penalties = const [],
    this.penHome,
    this.penAway,
  });
}
