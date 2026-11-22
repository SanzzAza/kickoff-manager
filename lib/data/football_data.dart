// Data statis dunia: liga, klub, negara, nama pemain, sponsor, stadion.
// Struktur mengikuti pola DB asli (paises, eq_equipos, jug_jugadores, tor_torneos, eq_estadios).

class LeagueDef {
  final String name;
  final String country;
  final String iso;
  final String confederation; // UEFA, CONMEBOL, CONCACAF, AFC, CAF
  final int teams;
  final List<String> clubs;
  final int base; // kekuatan dasar liga (0-100)
  final int prize; // hadiah juara
  const LeagueDef(this.name, this.country, this.iso, this.confederation,
      this.teams, this.clubs, this.base, this.prize);
}

class CountryNames {
  final String iso;
  final List<String> first;
  final List<String> last;
  const CountryNames(this.iso, this.first, this.last);
}

const Map<String, List<String>> confederations = {
  'UEFA': ['España', 'Inglaterra', 'Italia', 'Alemania', 'Francia'],
  'CONMEBOL': ['Argentina', 'Brasil', 'Uruguay'],
  'CONCACAF': ['México', 'Estados Unidos'],
  'AFC': ['Indonesia', 'Japón'],
  'CAF': ['Egipto', 'Marruecos'],
};

const List<LeagueDef> leagues = [
  // ================= UEFA =================
  LeagueDef('LaLiga', 'España', 'ES', 'UEFA', 20, [
    'Real Madrid', 'Barcelona', 'Atlético Madrid', 'Athletic Club', 'Real Sociedad',
    'Villarreal', 'Real Betis', 'Sevilla', 'Valencia', 'Girona',
    'Celta Vigo', 'Rayo Vallecano', 'Osasuna', 'Mallorca', 'Getafe',
    'Alavés', 'Las Palmas', 'Espanyol', 'Leganés', 'Valladolid'
  ], 86, 24000000),
  LeagueDef('Premier League', 'Inglaterra', 'GB', 'UEFA', 20, [
    'Manchester City', 'Arsenal', 'Liverpool', 'Chelsea', 'Tottenham',
    'Manchester United', 'Newcastle United', 'Aston Villa', 'Brighton', 'West Ham',
    'Crystal Palace', 'Fulham', 'Brentford', 'Everton', 'Nottingham Forest',
    'Bournemouth', 'Wolverhampton', 'Leicester City', 'Southampton', 'Ipswich Town'
  ], 87, 30000000),
  LeagueDef('Serie A', 'Italia', 'IT', 'UEFA', 20, [
    'Inter', 'Milan', 'Juventus', 'Napoli', 'Roma',
    'Lazio', 'Atalanta', 'Fiorentina', 'Bologna', 'Torino',
    'Genoa', 'Udinese', 'Cagliari', 'Empoli', 'Lecce',
    'Parma', 'Como', 'Verona', 'Monza', 'Venezia'
  ], 84, 20000000),
  LeagueDef('Bundesliga', 'Alemania', 'DE', 'UEFA', 18, [
    'Bayern München', 'Bayer Leverkusen', 'Borussia Dortmund', 'RB Leipzig', 'Eintracht Frankfurt',
    'Stuttgart', 'Freiburg', 'Wolfsburg', 'Union Berlin', 'Werder Bremen',
    'Hoffenheim', 'Augsburg', 'Mainz 05', 'Borussia Mönchengladbach', 'Heidenheim',
    'St. Pauli', 'Holstein Kiel', 'Bochum'
  ], 85, 22000000),
  LeagueDef('Ligue 1', 'Francia', 'FR', 'UEFA', 18, [
    'Paris Saint-Germain', 'Marseille', 'Monaco', 'Lille', 'Lyon',
    'Nice', 'Lens', 'Rennes', 'Strasbourg', 'Toulouse',
    'Brest', 'Nantes', 'Auxerre', 'Reims', 'Angers',
    'Le Havre', 'Saint-Étienne', 'Montpellier'
  ], 83, 18000000),

  // ================= CONMEBOL =================
  LeagueDef('Liga Profesional', 'Argentina', 'AR', 'CONMEBOL', 20, [
    'River Plate', 'Boca Juniors', 'Racing Club', 'Independiente', 'San Lorenzo',
    'Vélez Sarsfield', 'Estudiantes', 'Talleres', 'Newell\'s Old Boys', 'Rosario Central',
    'Lanús', 'Argentinos Juniors', 'Huracán', 'Defensa y Justicia', 'Godoy Cruz',
    'Banfield', 'Instituto', 'Belgrano', 'Platense', 'Central Córdoba'
  ], 79, 12000000),
  LeagueDef('Brasileirão', 'Brasil', 'BR', 'CONMEBOL', 20, [
    'Flamengo', 'Palmeiras', 'Botafogo', 'São Paulo', 'Corinthians',
    'Fluminense', 'Cruzeiro', 'Internacional', 'Atlético Mineiro', 'Grêmio',
    'Fortaleza', 'Bahia', 'Athletico Paranaense', 'Vasco da Gama', 'Santos',
    'Bragantino', 'Cuiabá', 'Juventude', 'Criciúma', 'Vitória'
  ], 80, 13000000),
  LeagueDef('Primera División', 'Uruguay', 'UY', 'CONMEBOL', 16, [
    'Peñarol', 'Nacional', 'Defensor Sporting', 'Liverpool FC', 'Danubio',
    'Montevideo City Torque', 'Boston River', 'Cerro Largo', 'Plaza Colonia', 'Progreso',
    'River Plate', 'Wanderers', 'Racing', 'Rampla Juniors', 'Miramar Misiones', 'Fénix'
  ], 73, 8000000),

  // ================= CONCACAF =================
  LeagueDef('Liga MX', 'México', 'MX', 'CONCACAF', 18, [
    'América', 'Monterrey', 'Tigres', 'Cruz Azul', 'Guadalajara',
    'Pumas', 'Toluca', 'León', 'Pachuca', 'Santos Laguna',
    'Atlas', 'Tijuana', 'Necaxa', 'Puebla', 'Querétaro',
    'Mazatlán', 'Atlético San Luis', 'Juárez'
  ], 77, 14000000),
  LeagueDef('MLS', 'Estados Unidos', 'US', 'CONCACAF', 18, [
    'Inter Miami', 'LAFC', 'LA Galaxy', 'Seattle Sounders', 'Atlanta United',
    'Portland Timbers', 'Austin FC', 'New York City FC', 'New York Red Bulls', 'Philadelphia Union',
    'Columbus Crew', 'FC Cincinnati', 'Orlando City', 'Nashville SC', 'Minnesota United',
    'Real Salt Lake', 'Houston Dynamo', 'Colorado Rapids'
  ], 74, 11000000),

  // ================= AFC =================
  LeagueDef('Super League', 'Indonesia', 'ID', 'AFC', 18, [
    'Persija Jakarta', 'Persib Bandung', 'Arema FC', 'Bali United', 'Persebaya Surabaya',
    'PSM Makassar', 'Borneo FC', 'Madura United', 'Persis Solo', 'PSS Sleman',
    'Dewa United', 'Persik Kediri', 'Bhayangkara FC', 'Barito Putera', 'Semen Padang',
    'PSBS Biak', 'Malut United', 'Persita Tangerang'
  ], 66, 4000000),
  LeagueDef('J1 League', 'Japón', 'JP', 'AFC', 18, [
    'Kashima Antlers', 'Vissel Kobe', 'Yokohama F. Marinos', 'Urawa Reds', 'Kawasaki Frontale',
    'Sanfrecce Hiroshima', 'Cerezo Osaka', 'Gamba Osaka', 'FC Tokyo', 'Nagoya Grampus',
    'Avispa Fukuoka', 'Kashiwa Reysol', 'Kyoto Sanga', 'Shimizu S-Pulse', 'Albirex Niigata',
    'Shonan Bellmare', 'Consadole Sapporo', 'Jubilo Iwata'
  ], 72, 6000000),

  // ================= CAF =================
  LeagueDef('Premier League', 'Egipto', 'EG', 'CAF', 18, [
    'Al Ahly', 'Zamalek', 'Pyramids FC', 'Ismaily', 'Ceramica Cleopatra',
    'Al Masry', 'Future FC', 'ENPPI', 'Smouha', 'El Gouna',
    'National Bank', 'Ceramica', 'Pharco', 'Zed', 'Modern Future',
    'Baladeyet Mahalla', 'Ittihad Alexandria', 'Petrojet'
  ], 71, 5000000),
  LeagueDef('Botola Pro', 'Marruecos', 'MA', 'CAF', 16, [
    'Wydad AC', 'Raja Casablanca', 'AS FAR', 'FUS Rabat', 'Berkane',
    'Maghreb Fès', 'Hassania Agadir', 'Ittihad Tanger', 'Chabab Mohammédia', 'Olympic Safi',
    'Difaa El Jadida', 'Mouloudia Oujda', 'Youssoufia Berrechid', 'Riadi Salmi', 'Union Touarga', 'CR Khemis Zemamra'
  ], 70, 4500000),
];

const Map<String, CountryNames> names = {
  'ES': CountryNames('ES', [
    'Sergio', 'Álvaro', 'Iker', 'Pablo', 'Javier', 'Marcos', 'Adrián', 'Rubén',
    'Diego', 'Hugo', 'Mario', 'Carlos', 'Fernando', 'Andrés', 'Iván', 'Nacho',
    'Raúl', 'Mikel', 'Aitor', 'Unai', 'Brais', 'Jon'
  ], [
    'García', 'Martínez', 'López', 'Sánchez', 'Pérez', 'Gómez', 'Fernández', 'Ruiz',
    'Torres', 'Navarro', 'Moreno', 'Domínguez', 'Vázquez', 'Serrano', 'Blanco', 'Molina',
    'Castillo', 'Ortega', 'Delgado', 'Ramos', 'Iglesias', 'Cano'
  ]),
  'GB': CountryNames('GB', [
    'James', 'Harry', 'Jack', 'Oliver', 'George', 'Callum', 'Mason', 'Lewis',
    'Ryan', 'Ben', 'Tom', 'Charlie', 'Ethan', 'Sam', 'Jude', 'Declan',
    'Marcus', 'Jordan', 'Luke', 'Reece'
  ], [
    'Smith', 'Jones', 'Taylor', 'Brown', 'Wilson', 'Davies', 'Evans', 'Thomas',
    'Roberts', 'Walker', 'Wright', 'Robinson', 'Thompson', 'Hughes', 'Edwards', 'Clarke',
    'Hall', 'Baker', 'Turner', 'Bailey'
  ]),
  'IT': CountryNames('IT', [
    'Lorenzo', 'Matteo', 'Alessandro', 'Francesco', 'Davide', 'Federico', 'Marco', 'Andrea',
    'Simone', 'Giacomo', 'Nicolò', 'Riccardo', 'Tommaso', 'Luca', 'Gabriele', 'Antonio'
  ], [
    'Rossi', 'Russo', 'Ferrari', 'Esposito', 'Bianchi', 'Romano', 'Colombo', 'Ricci',
    'Marino', 'Greco', 'Bruno', 'Gallo', 'Conti', 'De Luca', 'Costa', 'Giordano',
    'Mancini', 'Rizzo', 'Lombardi', 'Moretti'
  ]),
  'DE': CountryNames('DE', [
    'Lukas', 'Jonas', 'Leon', 'Finn', 'Maximilian', 'Tim', 'Nico', 'Julian',
    'Florian', 'Philipp', 'Marvin', 'Kevin', 'Tobias', 'Sebastian', 'Fabian', 'Moritz'
  ], [
    'Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker',
    'Hoffmann', 'Schäfer', 'Koch', 'Bauer', 'Richter', 'Klein', 'Wolf', 'Neumann',
    'Schwarz', 'Zimmermann', 'Braun', 'Krüger'
  ]),
  'FR': CountryNames('FR', [
    'Lucas', 'Hugo', 'Théo', 'Nathan', 'Enzo', 'Louis', 'Gabriel', 'Arthur',
    'Kylian', 'Antoine', 'Mathis', 'Yanis', 'Maxime', 'Romain', 'Clément', 'Bilal'
  ], [
    'Martin', 'Bernard', 'Dubois', 'Thomas', 'Robert', 'Richard', 'Petit', 'Durand',
    'Leroy', 'Moreau', 'Simon', 'Laurent', 'Lefebvre', 'Michel', 'Garnier', 'Faure',
    'Rousseau', 'Blanc', 'Guérin', 'Chevalier'
  ]),
  'AR': CountryNames('AR', [
    'Lucas', 'Matías', 'Santiago', 'Nicolás', 'Federico', 'Julián', 'Agustín', 'Franco',
    'Gonzalo', 'Facundo', 'Tomás', 'Emiliano', 'Joaquín', 'Ramiro', 'Bruno', 'Thiago'
  ], [
    'González', 'Rodríguez', 'Fernández', 'López', 'Martínez', 'Pérez', 'Gómez', 'Díaz',
    'Álvarez', 'Romero', 'Sosa', 'Torres', 'Benítez', 'Acosta', 'Medina', 'Herrera',
    'Aguirre', 'Peralta', 'Cabrera', 'Vargas'
  ]),
  'BR': CountryNames('BR', [
    'Gabriel', 'Lucas', 'Matheus', 'Rafael', 'Thiago', 'Bruno', 'Vinícius', 'João',
    'Pedro', 'Rodrigo', 'Felipe', 'Caio', 'Douglas', 'Igor', 'Murilo', 'Éder'
  ], [
    'Silva', 'Santos', 'Oliveira', 'Souza', 'Lima', 'Pereira', 'Costa', 'Ferreira',
    'Almeida', 'Rodrigues', 'Barbosa', 'Gomes', 'Ribeiro', 'Araújo', 'Carvalho', 'Nascimento',
    'Moreira', 'Cardoso', 'Teixeira', 'Correia'
  ]),
  'UY': CountryNames('UY', [
    'Facundo', 'Nicolás', 'Federico', 'Rodrigo', 'Diego', 'Maximiliano', 'Agustín', 'Matías',
    'Juan', 'Sebastián', 'Brian', 'Emiliano', 'Gastón', 'Ignacio'
  ], [
    'Núñez', 'Suárez', 'Cavani', 'Bentancur', 'Valverde', 'Araújo', 'Giménez', 'Olivera',
    'Vecino', 'Torreira', 'Pereira', 'De Arrascaeta', 'Rodríguez', 'Silva'
  ]),
  'MX': CountryNames('MX', [
    'Luis', 'Alejandro', 'Carlos', 'Jesús', 'Diego', 'Fernando', 'Hirving', 'Raúl',
    'Edson', 'César', 'Jorge', 'Santiago', 'Emilio', 'Ricardo', 'Ángel', 'Jonathan'
  ], [
    'Hernández', 'García', 'Martínez', 'López', 'González', 'Rodríguez', 'Pérez', 'Sánchez',
    'Ramírez', 'Cruz', 'Flores', 'Gómez', 'Morales', 'Vázquez', 'Reyes', 'Jiménez'
  ]),
  'US': CountryNames('US', [
    'Michael', 'Christian', 'Tyler', 'Brandon', 'Cameron', 'Jordan', 'Ethan', 'Austin',
    'Cody', 'Dylan', 'Nathan', 'Cole', 'Brenden', 'Jonathan', 'Antonee', 'Weston'
  ], [
    'Johnson', 'Williams', 'Miller', 'Davis', 'Wilson', 'Anderson', 'Taylor', 'Moore',
    'Jackson', 'White', 'Harris', 'Clark', 'Lewis', 'Young', 'Walker', 'Adams'
  ]),
  'ID': CountryNames('ID', [
    'Rizky', 'Bagus', 'Arif', 'Dimas', 'Ricky', 'Egy', 'Marselino', 'Fajar',
    'Ilham', 'Bayu', 'Andri', 'Saddil', 'Witan', 'Hokky', 'Rendy', 'Yakob',
    'Muhammad', 'Dedi', 'Rachmat', 'Febri', 'Alfeandra', 'Asnawi', 'Ragnar', 'Justin',
    'Rafael', 'Beckham', 'Arkhan', 'Komang', 'Ivar', 'Hugo'
  ], [
    'Pratama', 'Saputra', 'Wijaya', 'Nugroho', 'Setiawan', 'Hidayat', 'Santoso', 'Kurniawan',
    'Firmansyah', 'Ramadhan', 'Syahbana', 'Hartono', 'Suryana', 'Pamungkas', 'Wibowo',
    'Prasetyo', 'Gunawan', 'Susanto', 'Halim', 'Rahmawati', 'Anggara', 'Fadillah',
    'Maulana', 'Ridwan', 'Sumantri', 'Sudarmono', 'Prakoso', 'Hakim', 'Siregar', 'Simanjuntak',
    'Situmorang', 'Nainggolan', 'Banjarnahor', 'Tualaka', 'Sulaeman', 'Wahyu', 'Ardiansyah',
    'Mustofa', 'Zulkarnain', 'Nurdin', 'Wardana', 'Yunus', 'Bagus'
  ]),
  'JP': CountryNames('JP', [
    'Takumi', 'Yuto', 'Riku', 'Kaoru', 'Daiki', 'Kaito', 'Sota', 'Hiroki',
    'Ryo', 'Kenta', 'Shota', 'Yuki', 'Naoki', 'Haruto'
  ], [
    'Tanaka', 'Suzuki', 'Takahashi', 'Watanabe', 'Ito', 'Yamamoto', 'Nakamura', 'Kobayashi',
    'Kato', 'Yoshida', 'Sato', 'Sasaki', 'Endo', 'Morita'
  ]),
  'EG': CountryNames('EG', [
    'Mohamed', 'Ahmed', 'Mahmoud', 'Omar', 'Youssef', 'Karim', 'Mostafa', 'Hassan',
    'Amr', 'Tarek', 'Ziad', 'Hossam', 'Ramy', 'Bilal'
  ], [
    'Salah', 'Hassan', 'Ibrahim', 'Mostafa', 'Mahmoud', 'Fathi', 'Gaber', 'El Sayed',
    'Abdallah', 'Kamal', 'Zaki', 'Nabil', 'Rashad', 'Ashraf'
  ]),
  'MA': CountryNames('MA', [
    'Youssef', 'Achraf', 'Hakim', 'Sofiane', 'Amine', 'Ilias', 'Bilal', 'Oussama',
    'Nabil', 'Zakaria', 'Hamza', 'Yahya', 'Anas', 'Reda'
  ], [
    'El Amrani', 'Benali', 'Ziyech', 'Hakimi', 'Boufal', 'El Kaabi', 'Ounahi', 'Amrabat',
    'Sabiri', 'Attiat', 'El Khannouss', 'Rahmani', 'Bounou', 'Mendyl'
  ]),
};

const List<String> defendersFirst = [
  'Erik', 'Marco', 'Ivan', 'Pavel', 'Andreas', 'Sven', 'Milan', 'Dragan',
  'Victor', 'Julien', 'Diego', 'Rui', 'Kosta', 'Nemanja', 'Lars', 'Fabio'
];
const List<String> defendersLast = [
  'Petrović', 'Kovač', 'Novak', 'Horvat', 'Lindqvist', 'Van Dijk', 'De Vries', 'Bakker',
  'Silva', 'Costa', 'Marchetti', 'Ferreira', 'Sørensen', 'Larsen', 'Popović', 'Ionescu'
];

const List<String> sponsorsLow = [
  'Nasi Goreng FC', 'Kopi Kenangan', 'Toko Bangunan Jaya', 'Bengkel Motor 88',
  'Warung Sate Pak Kumis', 'Es Teh Manis', 'Geprek Bensu', 'Martabak Bangka'
];

const List<String> stadiumNames = [
  'Gelora Bung Karno', 'Stadion Jalak Harupat', 'Stadion Manahan', 'Stadion Si Jalak',
  'Estadio Azteca', 'Santiago Bernabéu', 'Camp Nou', 'San Siro', 'Signal Iduna Park',
  'Allianz Arena', 'Parc des Princes', 'Anfield', 'Etihad Stadium', 'Old Trafford',
  'Stamford Bridge', 'Emirates Stadium', 'Maracanã', 'La Bombonera', 'Monumental',
  'Estadio Nacional', 'Stadion Kanjuruhan', 'Jakarta International Stadium'
];

// Posisi mengikuti jug_posiciones di DB asli (posid, abrev, tipo).
class PositionDef {
  final int id;
  final String abrev;
  final String name;
  final int tipo; // 1 POR, 2 DEF, 3 MED, 4 DEL
  const PositionDef(this.id, this.abrev, this.name, this.tipo);
}

const List<PositionDef> positions = [
  PositionDef(1, 'GK', 'Kiper', 1),
  PositionDef(2, 'CB', 'Bek Tengah', 2),
  PositionDef(3, 'SW', 'Libero', 2),
  PositionDef(4, 'FB', 'Bek Sayap', 2),
  PositionDef(5, 'DM', 'Gelandang Bertahan', 3),
  PositionDef(6, 'AM', 'Gelandang Serang', 3),
  PositionDef(7, 'CM', 'Gelandang Tengah', 3),
  PositionDef(8, 'WM', 'Sayap', 3),
  PositionDef(9, 'WF', 'Penyerang Sayap', 4),
  PositionDef(10, 'ST', 'Penyerang Tengah', 4),
  PositionDef(11, 'SS', 'Penyerang Bayangan', 4),
];

String countryLabel(String country) {
  const m = {
    'España': 'Spanyol',
    'Inglaterra': 'Inggris',
    'Italia': 'Italia',
    'Alemania': 'Jerman',
    'Francia': 'Prancis',
    'Argentina': 'Argentina',
    'Brasil': 'Brasil',
    'Uruguay': 'Uruguay',
    'México': 'Meksiko',
    'Estados Unidos': 'Amerika Serikat',
    'Indonesia': 'Indonesia',
    'Japón': 'Jepang',
    'Egipto': 'Mesir',
    'Marruecos': 'Maroko',
  };
  return m[country] ?? country;
}

const List<String> habilidades = [
  'Atajadas', 'Reflejos', 'Anticipación', 'Juego Aéreo', 'Posicionamiento',
  'Entradas', 'Marcación', 'Recuperación', 'Remate', 'Cabeceo',
  'Fuerza', 'Corpulencia', 'Velocidad', 'Agilidad', 'Creatividad',
  'Pases', 'Resistencia', 'Tiros Libres', 'Regate', 'Técnica',
  'Liderazgo', 'Agresividad', 'Inteligencia', 'Control', 'Movilidad'
];
