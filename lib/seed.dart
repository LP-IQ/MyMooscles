import 'models.dart';

// Dados iniciais: divisão de 5 treinos (A–E), variações de cada exercício e um cardápio-base.
// Nenhum dado pessoal de saúde fica no código; peso e medidas são registrados no app.

/// Variações aceitas para cada exercício (aparecem em "Trocar exercício" durante o treino).
const defaultAlternatives = <String, List<String>>{
  'Leg press 45°': ['Leg press horizontal', 'Agachamento no smith', 'Agachamento livre'],
  'Agachamento no hack': ['Agachamento livre', 'Agachamento no smith', 'Agachamento pêndulo', 'Leg press 45°'],
  'Cadeira extensora': ['Extensora unilateral', 'Agachamento sissy'],
  'Cadeira flexora': ['Mesa flexora', 'Flexora unilateral', 'Flexora em pé'],
  'Adutor': ['Adução no cabo'],
  'Panturrilha em pé': ['Panturrilha no leg press', 'Panturrilha no smith', 'Panturrilha sentada'],
  'Abdominal na polia ou prancha': ['Abdominal na polia', 'Abdominal na máquina', 'Elevação de pernas', 'Prancha'],
  'Supino inclinado com halteres': ['Supino inclinado na máquina', 'Supino inclinado no smith', 'Supino inclinado com barra'],
  'Supino máquina (chest press)': ['Supino reto com halteres', 'Supino reto com barra', 'Supino no smith'],
  'Crucifixo na polia, unilateral': ['Crossover', 'Peck deck (voador)', 'Crucifixo com halteres'],
  'Desenvolvimento na máquina': ['Desenvolvimento com halteres', 'Desenvolvimento no smith'],
  'Elevação lateral': ['Elevação lateral na polia', 'Elevação lateral com halteres', 'Elevação lateral na máquina'],
  'Tríceps na polia com corda': ['Tríceps pulley barra V', 'Tríceps pulley barra reta', 'Tríceps unilateral na polia'],
  'Tríceps francês na polia': ['Tríceps francês com halter', 'Tríceps testa', 'Tríceps pulley barra V'],
  'Puxada frontal': ['Puxada pegada neutra', 'Puxada supinada', 'Barra fixa (graviton)', 'Puxada unilateral'],
  'Remada baixa unilateral na polia': ['Remada baixa (bilateral)', 'Remada serrote com halter'],
  'Remada máquina com apoio no peito': ['Remada cavalinho', 'Remada curvada com barra', 'Remada no smith'],
  'Pullover na polia': ['Pullover com halter'],
  'Crucifixo inverso': ['Crucifixo inverso na polia', 'Peck deck invertido', 'Face pull'],
  'Rosca bayesiana': ['Rosca direta na polia', 'Rosca direta com barra', 'Rosca alternada'],
  'Rosca martelo': ['Rosca martelo na polia (corda)', 'Rosca martelo cruzada'],
  'Rosca scott': ['Rosca scott na máquina', 'Rosca scott unilateral com halter'],
  'Antebraço (rosca de punho)': ['Rosca inversa', 'Rosca de punho na polia'],
  'Encolhimento': ['Encolhimento com halteres', 'Encolhimento no smith', 'Encolhimento na máquina'],
  'Stiff': ['Stiff com halteres', 'Levantamento terra romeno', 'Mesa flexora'],
  'Elevação pélvica': ['Elevação pélvica na máquina', 'Elevação pélvica no smith', 'Ponte de glúteo'],
  'Flexora unilateral': ['Cadeira flexora', 'Mesa flexora', 'Flexora em pé'],
  'Leg press unilateral': ['Afundo no smith', 'Búlgaro', 'Passada'],
  'Extensora unilateral': ['Cadeira extensora'],
  'Abdutor': ['Abdução no cabo'],
  'Panturrilha em pé ou no leg press': ['Panturrilha em pé', 'Panturrilha no leg press', 'Panturrilha no smith'],
  'Puxada frontal (pegada neutra)': ['Puxada frontal', 'Puxada supinada', 'Barra fixa (graviton)'],
  'Supino reto com halteres ou máquina': ['Supino reto com halteres', 'Supino máquina', 'Supino reto com barra'],
  'Remada baixa (bilateral)': ['Remada baixa unilateral', 'Remada cavalinho', 'Remada máquina'],
  'Desenvolvimento (máquina ou halteres)': ['Desenvolvimento na máquina', 'Desenvolvimento com halteres'],
  'Crossover (de cima para baixo)': ['Crossover de baixo para cima', 'Peck deck (voador)'],
  'Rosca bayesiana (bi-set)': ['Rosca direta na polia', 'Rosca alternada'],
  'Tríceps corda (bi-set)': ['Tríceps pulley barra V', 'Tríceps francês na polia'],
};

/// Calorias e proteína aproximadas de cada refeição do cardápio-base (por horário).
const defaultMealMacros = <String, List<double>>{
  '05:30': [200, 25],
  '08:00': [440, 28],
  '12:00': [450, 41],
  '16:00': [330, 27],
  '18:30': [180, 10],
  '20:00': [400, 37],
};

ExerciseTemplate _ex(String name, int sets, int repMin, int repMax,
        {double? load, String note = '', int warmups = 1}) =>
    ExerciseTemplate(
      name: name,
      sets: sets,
      repMin: repMin,
      repMax: repMax,
      startLoad: load,
      note: note,
      warmups: warmups,
      alternatives: List<String>.from(defaultAlternatives[name] ?? const <String>[]),
    );

List<WorkoutTemplate> seedTemplates() => [
      WorkoutTemplate(code: 'A', name: 'Pernas (quadríceps)', weekday: 1, exercises: [
        _ex('Leg press 45°', 3, 8, 12, load: 50, note: 'carga por lado', warmups: 2),
        _ex('Agachamento no hack', 3, 8, 10, note: 'testar carga'),
        _ex('Cadeira extensora', 3, 10, 15, load: 36, note: 'dropset só na última série'),
        _ex('Cadeira flexora', 3, 10, 12, load: 59),
        _ex('Adutor', 2, 12, 15, load: 82),
        _ex('Panturrilha em pé', 4, 12, 20, load: 54, note: '1 s parado embaixo'),
        _ex('Abdominal na polia ou prancha', 3, 10, 15, warmups: 0),
      ]),
      WorkoutTemplate(code: 'B', name: 'Empurrar (peito, ombro, tríceps)', weekday: 2, exercises: [
        _ex('Supino inclinado com halteres', 3, 6, 10, note: 'pegada neutra se o punho reclamar', warmups: 2),
        _ex('Supino máquina (chest press)', 3, 8, 12),
        _ex('Crucifixo na polia, unilateral', 3, 10, 15, load: 14, note: 'alterne a altura da polia'),
        _ex('Desenvolvimento na máquina', 3, 8, 12, load: 14),
        _ex('Elevação lateral', 3, 12, 20, note: 'dropset só na última série'),
        _ex('Tríceps na polia com corda', 3, 10, 15, load: 14),
        _ex('Tríceps francês na polia', 2, 10, 15, load: 9, note: 'troque por barra V se o cotovelo doer'),
      ]),
      WorkoutTemplate(code: 'C', name: 'Puxar (costas, bíceps)', weekday: 3, exercises: [
        _ex('Puxada frontal', 3, 8, 12, load: 45, warmups: 2),
        _ex('Remada baixa unilateral na polia', 3, 8, 12, load: 50),
        _ex('Remada máquina com apoio no peito', 3, 8, 12),
        _ex('Pullover na polia', 2, 12, 15),
        _ex('Crucifixo inverso', 3, 12, 20),
        _ex('Rosca bayesiana', 3, 10, 12, load: 18),
        _ex('Rosca martelo', 2, 10, 12),
        _ex('Rosca scott', 2, 10, 12),
        _ex('Antebraço (rosca de punho)', 2, 12, 20, note: 'opcional', warmups: 0),
        _ex('Encolhimento', 3, 10, 15, load: 24, note: 'no fim do treino'),
      ]),
      WorkoutTemplate(code: 'D', name: 'Pernas (posterior e glúteo)', weekday: 4, exercises: [
        _ex('Stiff', 3, 8, 10, load: 27, warmups: 2),
        _ex('Elevação pélvica', 3, 8, 12, load: 50, note: 'carga por lado'),
        _ex('Flexora unilateral', 3, 10, 12, load: 27),
        _ex('Leg press unilateral', 2, 10, 12, note: 'cada perna'),
        _ex('Extensora unilateral', 2, 12, 15, load: 18),
        _ex('Abdutor', 3, 12, 20, load: 82),
        _ex('Panturrilha em pé ou no leg press', 3, 15, 20, load: 54),
        _ex('Abdominal na polia ou prancha', 3, 10, 15, warmups: 0),
      ]),
      WorkoutTemplate(code: 'E', name: 'Superiores completo', weekday: 5, exercises: [
        _ex('Puxada frontal (pegada neutra)', 3, 8, 12, load: 45, warmups: 2),
        _ex('Supino reto com halteres ou máquina', 3, 8, 12),
        _ex('Remada baixa (bilateral)', 3, 10, 12),
        _ex('Desenvolvimento (máquina ou halteres)', 3, 8, 12, load: 14),
        _ex('Crossover (de cima para baixo)', 2, 12, 15, load: 14),
        _ex('Elevação lateral', 3, 12, 20, note: 'dropset na última série'),
        _ex('Rosca bayesiana (bi-set)', 2, 10, 15, load: 18, note: 'emende com o tríceps'),
        _ex('Tríceps corda (bi-set)', 2, 10, 15, load: 14, warmups: 0),
      ]),
    ];

Meal _meal(String time, String title, String description) => Meal(
      time: time,
      title: title,
      description: description,
      kcal: defaultMealMacros[time]?[0],
      protein: defaultMealMacros[time]?[1],
    );

List<Meal> seedMeals() => [
      _meal('05:30', 'Pré-treino', '1 banana + 1 dose de whey (30 g) com água'),
      _meal('08:00', 'Café pós-treino',
          'Omelete de 3 ovos + 1 pão francês (ou 2 col. de tapioca) + 1 fatia de queijo minas'),
      _meal('12:00', 'Almoço',
          'Proteína do bandejão + reforço de casa (2 ovos, 1/2 lata de atum ou sardinha, ou 80 g de frango) + 4 col. de arroz + 1 concha de feijão + salada'),
      _meal('16:00', 'Lanche', '2 fatias de pão integral + 60 g de frango desfiado + requeijão light + 1 fruta'),
      _meal('18:30', 'Lanche', '1 iogurte natural + 2 col. de aveia'),
      _meal('20:00', 'Jantar',
          '100 g de frango, carne magra ou peixe + 5 col. de arroz ou massa + legumes + 1 col. chá de azeite'),
    ];

AppData seedData() => AppData(
      profile: Profile(),
      templates: seedTemplates(),
      sessions: [],
      body: [],
      meals: seedMeals(),
      notes: '',
    );

/// Completa dados salvos por versões anteriores (variações, aquecimento, macros do cardápio).
void migrate(AppData data) {
  if (data.version < 2) {
    for (final t in data.templates) {
      for (var i = 0; i < t.exercises.length; i++) {
        final e = t.exercises[i];
        if (e.alternatives.isEmpty) {
          e.alternatives = List<String>.from(defaultAlternatives[e.name] ?? const <String>[]);
        }
        if (i == 0) e.warmups = 2;
        if (e.name.startsWith('Abdominal') || e.name.startsWith('Antebraço') || e.name.startsWith('Tríceps corda')) {
          e.warmups = 0;
        }
      }
    }
    for (final m in data.meals) {
      final macros = defaultMealMacros[m.time];
      if (macros != null) {
        m.kcal ??= macros[0];
        m.protein ??= macros[1];
      }
    }
    data.version = 2;
  }
}
