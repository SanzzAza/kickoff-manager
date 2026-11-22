# Skema database Super Kickoff (hasil bongkar APK 4.3.4, untuk referensi arsitektur)

## eq_entrenadores  (2136 baris)
```sql
CREATE TABLE "eq_entrenadores" (
  "entid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "en_nombre" VARCHAR(160) NOT NULL,
  "en_edad" TINYINT DEFAULT 35,
  "en_paid" INTEGER DEFAULT 141,
  "en_pts" MEDIUMINT DEFAULT 0
)
```

## eq_equipos  (2136 baris)
```sql
CREATE TABLE "eq_equipos" (
  "equid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "equi_abrev" VARCHAR(4),
  "equi_nombre" VARCHAR(60) NOT NULL,
  "equi_funda" integer DEFAULT 0,
  "equi_valor" INTEGER DEFAULT 0,
  "equi_poder" TINYINT DEFAULT 0,
  "equi_presupuesto" INTEGER DEFAULT 0,
  "equi_pts" SMALLINT DEFAULT 0,
  "equi_estaid" INTEGER NOT NULL,
  "equi_paid" INTEGER NOT NULL,
  "equi_entid" INTEGER NOT NULL,
  "equi_division" TINYINT DEFAULT 1
)
```

## eq_equipos_cesiones  (0 baris)
```sql
CREATE TABLE "eq_equipos_cesiones" (
  "ceid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "ces_jugid" INTEGER NOT NULL,
  "ces_equid_origen" INTEGER NOT NULL,
  "ces_equid_destino" INTEGER NOT NULL,
  "ces_fecha_desde" DATE NOT NULL,
  "ces_fecha_hasta" DATE NOT NULL,
  "ces_meses" integer(1) NOT NULL DEFAULT 0,
  "ces_mensaje" integer(1) NOT NULL DEFAULT 0
)
```

## eq_equipos_jugadores  (62938 baris)
```sql
CREATE TABLE "eq_equipos_jugadores" (
  "eqju_equid" INTEGER NOT NULL,
  "eqju_jugid" INTEGER NOT NULL
)
```

## eq_estadios  (2136 baris)
```sql
CREATE TABLE "eq_estadios" (
  "estaid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "es_nombre" VARCHAR(160) NOT NULL,
  "es_tot_general" SMALLINT DEFAULT 0,
  "es_tot_plateas" SMALLINT DEFAULT 0,
  "es_tot_tribunas" SMALLINT DEFAULT 0,
  "es_tot_palcos" SMALLINT DEFAULT 0,
  "es_max_general" SMALLINT DEFAULT 0,
  "es_max_plateas" SMALLINT DEFAULT 0,
  "es_max_tribunas" SMALLINT DEFAULT 0,
  "es_max_palcos" SMALLINT DEFAULT 0,
  "es_paid" INTEGER NOT NULL,
  "es_ciudad" VARCHAR(120) DEFAULT NULL
)
```

## historial_ranking_mundial  (0 baris)
```sql
CREATE TABLE "historial_ranking_mundial" (
  "rank_equipoid" INTEGER,
  "rank_anio" INTEGER,
  "rank_posicion" INTEGER
)
```

## historial_user  (0 baris)
```sql
CREATE TABLE "historial_user" (
  "h_tempid" INTEGER,
  "h_entid" INTEGER,
  "h_equid" INTEGER,
  "h_paid" INTEGER,
  "h_pj" INTEGER DEFAULT 0,
  "h_pg" INTEGER DEFAULT 0,
  "h_pe" INTEGER DEFAULT 0,
  "h_pp" INTEGER DEFAULT 0,
  "h_gf" INTEGER DEFAULT 0,
  "h_gc" INTEGER DEFAULT 0,
  "h_anioInicio" INTEGER,
  "h_anioFin" INTEGER,
  "h_campeonatos" TEXT
)
```

## jug_habilidades  (25 baris)
```sql
CREATE TABLE "jug_habilidades" (
  "habid" TINYINT NOT NULL,
  "hab_nombre" VARCHAR(30) NOT NULL,
  "hab_descripcion" VARCHAR(160),
  PRIMARY KEY ("habid")
)
```

## jug_jugadores  (62928 baris)
```sql
CREATE TABLE "jug_jugadores" (
  "jugid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "jug_nombre" VARCHAR(60) NOT NULL,
  "jug_edad" TINYINT DEFAULT 17,
  "jug_estatura" SMALLINT DEFAULT 175,
  "jug_star" TINYINT DEFAULT 0,
  "jug_valor" INTEGER DEFAULT 0,
  "jug_salario" INTEGER DEFAULT 0,
  "jug_perfil" VARCHAR(1) DEFAULT D,
  "jug_experiencia" TINYINT DEFAULT 0,
  "jug_condicion" TINYINT DEFAULT 100,
  "jug_jstdid" TINYINT DEFAULT 1,
  "jug_poder" TINYINT DEFAULT 0,
  "jug_potencial" TINYINT DEFAULT 0,
  "jug_mercado" TINYINT DEFAULT 1,
  "jug_paid" INTEGER NOT NULL DEFAULT 141,
  "jug_posid" TINYINT NOT NULL,
  "jug_titular" TINYINT DEFAULT 1,
  "jug_capitan" TINYINT DEFAULT 0,
  "jug_numero" TINYINT DEFAULT 0,
  "jug_campeonatos" VARCHAR(250),
  "jug_pts" INTEGER DEFAULT 0,
  "jug_habilidad_A" INTEGER DEFAULT NULL,
  "jug_habilidad_B" INTEGER DEFAULT NULL
)
```

## jug_jugadores_habilidades  (0 baris)
```sql
CREATE TABLE "jug_jugadores_habilidades" (
  "jh_jugid" INTEGER NOT NULL,
  "jh_habid" TINYINT NOT NULL,
  "jh_poder" TINYINT
)
```

## jug_posiciones  (11 baris)
```sql
CREATE TABLE "jug_posiciones" (
  "posid" TINYINT NOT NULL,
  "pos_abrev" VARCHAR(4) NOT NULL,
  "pos_nombre" VARCHAR(30) NOT NULL,
  "pos_tipo" TINYINT NOT NULL,
  PRIMARY KEY ("posid")
)
```

## jug_posiciones_habilidades  (164 baris)
```sql
CREATE TABLE "jug_posiciones_habilidades" (
  "ph_posid" TINYINT NOT NULL,
  "ph_habid" TINYINT NOT NULL
)
```

## jug_status  (3 baris)
```sql
CREATE TABLE "jug_status" (
  "jstdid" TINYINT NOT NULL,
  "jstd_nombre" VARCHAR(20) NOT NULL,
  PRIMARY KEY ("jstdid")
)
```

## jus_stats  (0 baris)
```sql
CREATE TABLE "jus_stats" (
  "js_jugid" INTEGER NOT NULL,
  "js_equid" INTEGER NOT NULL,
  "js_tempid" INTEGER NOT NULL,
  "js_pj" SMALLINT DEFAULT 0,
  "js_min" SMALLINT DEFAULT 0,
  "js_cal" TINYINT DEFAULT 0,
  "js_titular" SMALLINT DEFAULT 0,
  "js_amarillas" SMALLINT DEFAULT 0,
  "js_rojas" TINYINT DEFAULT 0,
  "js_mvps" SMALLINT DEFAULT 0,
  "js_goles" SMALLINT DEFAULT 0,
  "js_asistencias" TINYINT DEFAULT 0
)
```

## jus_stats_paises  (0 baris)
```sql
CREATE TABLE "jus_stats_paises" (
  "js_jugid" INTEGER NOT NULL,
  "js_paid" INTEGER NOT NULL,
  "js_tempid" INTEGER NOT NULL,
  "js_pj" INTEGER,
  "js_min" INTEGER,
  "js_cal" INTEGER,
  "js_titular" INTEGER,
  "js_amarillas" INTEGER,
  "js_rojas" INTEGER,
  "js_mvps" INTEGER,
  "js_goles" INTEGER,
  "js_asistencias" INTEGER
)
```

## mensajes  (0 baris)
```sql
CREATE TABLE "mensajes" (
  "menid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "titulo" TEXT,
  "mensaje" TEXT,
  "fecha" TEXT,
  "remitente" TEXT,
  "visto" INTEGER,
  "tipo" INTEGER,
  "jugid" INTEGER,
  "equid" INTEGER,
  "costo" INTEGER,
  "acciones" INTEGER,
  "respuesta" INTEGER
)
```

## pais_entrenador  (0 baris)
```sql
CREATE TABLE "pais_entrenador" (
  "temporadaID" INTEGER,
  "entrenadorID" INTEGER,
  "paisID" INTEGER,
  PRIMARY KEY ("temporadaID", "entrenadorID", "paisID")
)
```

## pais_jugador_convocatoria  (0 baris)
```sql
CREATE TABLE "pais_jugador_convocatoria" (
  "paisID" INTEGER,
  "jugadorID" INTEGER,
  "temporadaID" INTEGER,
  PRIMARY KEY ("temporadaID", "jugadorID", "paisID")
)
```

## paises  (254 baris)
```sql
CREATE TABLE "paises" (
  "paid" INTEGER,
  "nombre" TEXT,
  "iso2" TEXT,
  "poder" INTEGER,
  "pts" INTEGER,
  "confederacion" INTEGER DEFAULT 0,
  PRIMARY KEY ("paid")
)
```

## tor_arbitros  (0 baris)
```sql
CREATE TABLE "tor_arbitros" (
  "arbid" SMALLINT NOT NULL,
  "abi_nombre" VARCHAR(60) NOT NULL,
  "arb_paid" INTEGER NOT NULL,
  "arb_tcaid" TINYINT NOT NULL,
  "arb_edad" TINYINT NOT NULL,
  PRIMARY KEY ("arbid")
)
```

## tor_arbitros_tipos  (5 baris)
```sql
CREATE TABLE "tor_arbitros_tipos" (
  "tcaid" TINYINT NOT NULL,
  "tca_nombre" VARCHAR(20),
  PRIMARY KEY ("tcaid")
)
```

## tor_divisiones  (5 baris)
```sql
CREATE TABLE "tor_divisiones" (
  "idiv" TINYINT NOT NULL,
  "div_nombre" VARCHAR(30) NOT NULL,
  PRIMARY KEY ("idiv")
)
```

## tor_grupos  (35 baris)
```sql
CREATE TABLE "tor_grupos" (
  "gruid" TINYINT NOT NULL,
  "gru_nombre" VARCHAR(30) NOT NULL,
  PRIMARY KEY ("gruid")
)
```

## tor_inabilitados  (0 baris)
```sql
CREATE TABLE "tor_inabilitados" (
  "inaid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "ina_jugid" INTEGER,
  "ina_tipo" TINYINT NOT NULL,
  "ina_jorinhabilitadas" TINYINT DEFAULT 0,
  "ina_tempid" INTEGER
)
```

## tor_partidos  (0 baris)
```sql
CREATE TABLE "tor_partidos" (
  "partid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "par_torid" INTEGER,
  "par_tempid" INTEGER,
  "par_arbid" SMALLINT,
  "par_estaid" INTEGER,
  "par_equid_local" INTEGER DEFAULT 0,
  "par_equid_visita" INTEGER DEFAULT 0,
  "par_goles_local" TINYINT DEFAULT 0,
  "par_goles_visita" TINYINT DEFAULT 0,
  "par_gana" INTEGER DEFAULT 0,
  "par_esp_general" SMALLINT DEFAULT 0,
  "par_esp_plateas" SMALLINT DEFAULT 0,
  "par_esp_tribunas" SMALLINT DEFAULT 0,
  "par_esp_palcos" SMALLINT DEFAULT 0,
  "par_ent_ingresos" MEDIUMINT DEFAULT 0,
  "par_fase" TINYINT DEFAULT 0,
  "par_gruid" TINYINT,
  "par_jornada" TINYINT DEFAULT 0,
  "par_status" TINYINT DEFAULT 1,
  "par_vuelta" TINYINT DEFAULT 1,
  "par_fecha" DATE,
  "par_penal_goles_local" INTEGER DEFAULT 0,
  "par_penal_goles_visita" INTEGER DEFAULT 0
)
```

## tor_partidos_incidencias  (0 baris)
```sql
CREATE TABLE "tor_partidos_incidencias" (
  "incid" INTEGER NOT NULL,
  "tpi_partid" INTEGER NOT NULL,
  "tpi_json" TEXT,
  PRIMARY KEY ("incid")
)
```

## tor_partidos_jugadores  (0 baris)
```sql
CREATE TABLE "tor_partidos_jugadores" (
  "tpj_jugid" INTEGER NOT NULL,
  "tpj_partid" INTEGER NOT NULL,
  "tpj_equid" INTEGER NOT NULL,
  "tpj_titular" TINYINT,
  "tpj_minutos" TINYINT,
  "tpj_pts" TINYINT,
  "tpj_calificacion" TINYINT,
  "tpj_mvp" TINYINT,
  "tpj_goles" TINYINT,
  "tpj_amarillas" TINYINT,
  "tpj_rojas" TINYINT,
  "tpj_asistencias" TINYINT
)
```

## tor_partidos_jugadores_paises  (0 baris)
```sql
CREATE TABLE "tor_partidos_jugadores_paises" (
  "tpj_jugid" INTEGER NOT NULL,
  "tpj_partid" INTEGER NOT NULL,
  "tpj_paid" INTEGER NOT NULL,
  "tpj_titular" INTEGER,
  "tpj_minutos" INTEGER,
  "tpj_pts" INTEGER,
  "tpj_calificacion" INTEGER,
  "tpj_mvp" INTEGER,
  "tpj_goles" INTEGER,
  "tpj_amarillas" INTEGER,
  "tpj_rojas" INTEGER,
  "tpj_asistencias" INTEGER
)
```

## tor_partidos_paises  (0 baris)
```sql
CREATE TABLE "tor_partidos_paises" (
  "partid" INTEGER,
  "par_torid" INTEGER,
  "par_tempid" INTEGER,
  "par_arbid" INTEGER,
  "par_estaid" INTEGER,
  "par_pais_local" INTEGER DEFAULT 0,
  "par_pais_visita" INTEGER DEFAULT 0,
  "par_goles_local" INTEGER DEFAULT 0,
  "par_goles_visita" INTEGER DEFAULT 0,
  "par_gana" INTEGER DEFAULT 0,
  "par_esp_general" INTEGER DEFAULT 0,
  "par_esp_plateas" INTEGER DEFAULT 0,
  "par_esp_tribunas" INTEGER DEFAULT 0,
  "par_esp_palcos" INTEGER DEFAULT 0,
  "par_ent_ingresos" INTEGER DEFAULT 0,
  "par_fase" INTEGER DEFAULT 0,
  "par_jornada" INTEGER DEFAULT 0,
  "par_status" INTEGER DEFAULT 1,
  "par_vuelta" INTEGER DEFAULT 1,
  "par_fecha" TEXT,
  "par_penal_goles_local" INTEGER,
  "par_penal_goles_visita" INTEGER,
  PRIMARY KEY ("partid")
)
```

## tor_temporada_paises  (0 baris)
```sql
CREATE TABLE "tor_temporada_paises" (
  "tem_paid" INTEGER,
  "tem_tempid" INTEGER,
  "tem_entid" INTEGER,
  "tem_pos" INTEGER DEFAULT 0,
  PRIMARY KEY ("tem_paid", "tem_tempid")
)
```

## tor_temporadas  (0 baris)
```sql
CREATE TABLE "tor_temporadas" (
  "tempid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "tem_nombre" VARCHAR(60) NOT NULL,
  "tem_anioinicio" SMALLINT NOT NULL,
  "tem_aniofin" SMALLINT NOT NULL
, "tem_isNuevoFormato"	INTEGER DEFAULT NULL)
```

## tor_temporadas_equipos  (0 baris)
```sql
CREATE TABLE "tor_temporadas_equipos" (
  "te_equid" INTEGER NOT NULL,
  "te_tempid" INTEGER NOT NULL,
  "te_entid" INTEGER,
  "te_pos" TINYINT
)
```

## tor_temporadas_torneos  (0 baris)
```sql
CREATE TABLE "tor_temporadas_torneos" (
  "tto_tempid" INTEGER NOT NULL,
  "tto_torid" INTEGER NOT NULL,
  "tto_status" TINYINT
)
```

## tor_torneos_paises  (280 baris)
```sql
CREATE TABLE "tor_torneos_paises" (
  "tp_paid" INTEGER NOT NULL,
  "tp_torid" INTEGER,
  "tp_cupos" TINYINT
)
```

## tor_transferencias_entrenadores  (0 baris)
```sql
CREATE TABLE "tor_transferencias_entrenadores" (
  "teid" INTEGER NOT NULL,
  "te_entid_despedido" INTEGER NOT NULL,
  "te_entid_contratado" INTEGER NOT NULL,
  "te_equid" INTEGER NOT NULL,
  "te_tempid" INTEGER NOT NULL,
  "te_fecha" DATE,
  PRIMARY KEY ("teid", "te_equid", "te_tempid")
)
```

## tor_transferencias_jugadores  (0 baris)
```sql
CREATE TABLE "tor_transferencias_jugadores" (
  "traid" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "tra_jugid" INTEGER NOT NULL,
  "tra_equid_origen" INTEGER,
  "tra_equid_destino" INTEGER,
  "tra_tipo_transferencia" TINYINT,
  "tra_valor" INTEGER,
  "tra_fecha" DATE
)
```

## Patrocinadores  (19 baris)
```sql
CREATE TABLE "Patrocinadores" (
	"Pa_ID"	INTEGER,
	"Pa_nombre"	TEXT,
	"Pa_nivel"	INTEGER,
	PRIMARY KEY("Pa_ID" AUTOINCREMENT)
)
```

## Patrocinios  (0 baris)
```sql
CREATE TABLE "Patrocinios" (
	"P_ID"	INTEGER NOT NULL,
	"P_tipo"	INTEGER,
	"P_equipoID"	INTEGER,
	"P_patrocinadorID"	INTEGER,
	"P_torneoID"	INTEGER,
	"P_temporadaID"	INTEGER,
	"P_isPrioridad"	INTEGER,
	"P_isPremioUnico"	INTEGER,
	"P_recompensaBase"	INTEGER,
	"P_objetivo"	INTEGER,
	"P_cantidadLograda"	INTEGER,
	"P_exito"	INTEGER,
	"P_status"	INTEGER DEFAULT 1,
	"P_dataExtra"	TEXT,
	PRIMARY KEY("P_ID" AUTOINCREMENT)
)
```

## jug_premios  (0 baris)
```sql
CREATE TABLE "jug_premios" (
	"premid"	INTEGER,
	"jugid"	INTEGER DEFAULT NULL,
	"equid"	INTEGER DEFAULT NULL,
	"tipo"	INTEGER DEFAULT NULL,
	"anio"	INTEGER DEFAULT NULL,
	"tempid"	INTEGER DEFAULT NULL,
	"goles"	INTEGER DEFAULT NULL,
	PRIMARY KEY("premid" AUTOINCREMENT)
)
```

## tor_cupos_internacionales  (162 baris)
```sql
CREATE TABLE "tor_cupos_internacionales" (
	"torneoID"	INTEGER,
	"paisID"	INTEGER,
	"cupos"	INTEGER
)
```

## jug_contratos  (62936 baris)
```sql
CREATE TABLE "jug_contratos" (
	"jc_id"	INTEGER,
	"jc_jugid"	INTEGER,
	"jc_equid"	INTEGER,
	"jc_inicio"	TEXT,
	"jc_fin"	TEXT,
	"jc_status"	INTEGER DEFAULT 1,
	"jc_salario"	INTEGER,
	"jc_bonoGol"	INTEGER DEFAULT NULL,
	"jc_bonoAsis"	INTEGER DEFAULT NULL,
	"jc_bonoMVP"	INTEGER DEFAULT NULL,
	"jc_bonoCampe"	INTEGER DEFAULT NULL,
	"jc_bonoPJ"	INTEGER DEFAULT NULL,
	PRIMARY KEY("jc_id" AUTOINCREMENT)
)
```

## tor_torneos  (245 baris)
```sql
CREATE TABLE "tor_torneos" (
	"torid"	INTEGER NOT NULL,
	"tor_nombre"	VARCHAR(60) NOT NULL,
	"tor_idiv"	TINYINT DEFAULT 1,
	"tor_status"	TINYINT DEFAULT 1,
	"tor_organizacion"	TINYINT DEFAULT 1,
	"tor_vueltas"	TINYINT DEFAULT 1,
	"tor_inverso"	TINYINT,
	"tor_fecha_1"	VARCHAR(5),
	"tor_fecha_2"	VARCHAR(5),
	"tor_label_1"	VARCHAR(20),
	"tor_label_2"	VARCHAR(20),
	"tor_dias"	VARCHAR(15) NOT NULL,
	"tor_cupos"	VARCHAR(4) NOT NULL,
	"tor_pts"	TINYINT NOT NULL DEFAULT 0,
	"tor_asciende"	TINYINT DEFAULT 0,
	"tor_desciende"	TINYINT DEFAULT 0,
	"tor_premio_equipos"	INTEGER DEFAULT 0,
	"tor_premio_goleador"	INTEGER DEFAULT 0,
	"tor_premio_mvps"	INTEGER DEFAULT 0,
	PRIMARY KEY("torid" AUTOINCREMENT)
)
```
