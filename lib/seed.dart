import 'models.dart';

// Dados iniciais: divisão de 5 treinos (A–E) e um cardápio-base.
// Nenhum dado pessoal de saúde fica no código; peso e medidas são registrados no app.

ExerciseTemplate _ex(String name, int sets, int repMin, int repMax,
        {double? load, String note = ''}) =>
    ExerciseTemplate(
        name: name, sets: sets, repMin: repMin, repMax: repMax, startLoad: load, note: note);

List<WorkoutTemplate> seedTemplates() => [
      WorkoutTemplate(code: 'A', name: 'Pernas (quadríceps)', weekday: 1, exercises: [
        _ex('Leg press 45°', 3, 8, 12, load: 50, note: 'carga por lado'),
        _ex('Agachamento no hack', 3, 8, 10, note: 'testar carga'),
        _ex('Cadeira extensora', 3, 10, 15, load: 36, note: 'dropset só na última série'),
        _ex('Cadeira flexora', 3, 10, 12, load: 59),
        _ex('Adutor', 2, 12, 15, load: 82),
        _ex('Panturrilha em pé', 4, 12, 20, load: 54, note: '1 s parado embaixo'),
        _ex('Abdominal na polia ou prancha', 3, 10, 15),
      ]),
      WorkoutTemplate(code: 'B', name: 'Empurrar (peito, ombro, tríceps)', weekday: 2, exercises: [
        _ex('Supino inclinado com halteres', 3, 6, 10, note: 'pegada neutra se o punho reclamar'),
        _ex('Supino máquina (chest press)', 3, 8, 12),
        _ex('Crucifixo na polia, unilateral', 3, 10, 15, load: 14, note: 'alterne a altura da polia'),
        _ex('Desenvolvimento na máquina', 3, 8, 12, load: 14),
        _ex('Elevação lateral', 3, 12, 20, note: 'dropset só na última série'),
        _ex('Tríceps na polia com corda', 3, 10, 15, load: 14),
        _ex('Tríceps francês na polia', 2, 10, 15, load: 9, note: 'troque por barra V se o cotovelo doer'),
      ]),
      WorkoutTemplate(code: 'C', name: 'Puxar (costas, bíceps)', weekday: 3, exercises: [
        _ex('Puxada frontal', 3, 8, 12, load: 45),
        _ex('Remada baixa unilateral na polia', 3, 8, 12, load: 50),
        _ex('Remada máquina com apoio no peito', 3, 8, 12),
        _ex('Pullover na polia', 2, 12, 15),
        _ex('Crucifixo inverso', 3, 12, 20),
        _ex('Rosca bayesiana', 3, 10, 12, load: 18),
        _ex('Rosca martelo', 2, 10, 12),
        _ex('Rosca scott', 2, 10, 12),
        _ex('Antebraço (rosca de punho)', 2, 12, 20, note: 'opcional'),
        _ex('Encolhimento', 3, 10, 15, load: 24, note: 'no fim do treino'),
      ]),
      WorkoutTemplate(code: 'D', name: 'Pernas (posterior e glúteo)', weekday: 4, exercises: [
        _ex('Stiff', 3, 8, 10, load: 27),
        _ex('Elevação pélvica', 3, 8, 12, load: 50, note: 'carga por lado'),
        _ex('Flexora unilateral', 3, 10, 12, load: 27),
        _ex('Leg press unilateral', 2, 10, 12, note: 'cada perna'),
        _ex('Extensora unilateral', 2, 12, 15, load: 18),
        _ex('Abdutor', 3, 12, 20, load: 82),
        _ex('Panturrilha em pé ou no leg press', 3, 15, 20, load: 54),
        _ex('Abdominal na polia ou prancha', 3, 10, 15),
      ]),
      WorkoutTemplate(code: 'E', name: 'Superiores completo', weekday: 5, exercises: [
        _ex('Puxada frontal (pegada neutra)', 3, 8, 12, load: 45),
        _ex('Supino reto com halteres ou máquina', 3, 8, 12),
        _ex('Remada baixa (bilateral)', 3, 10, 12),
        _ex('Desenvolvimento (máquina ou halteres)', 3, 8, 12, load: 14),
        _ex('Crossover (de cima para baixo)', 2, 12, 15, load: 14),
        _ex('Elevação lateral', 3, 12, 20, note: 'dropset na última série'),
        _ex('Rosca bayesiana (bi-set)', 2, 10, 15, load: 18, note: 'emende com o tríceps'),
        _ex('Tríceps corda (bi-set)', 2, 10, 15, load: 14),
      ]),
    ];

List<Meal> seedMeals() => [
      Meal(time: '05:30', title: 'Pré-treino', description: '1 banana + 1 dose de whey (30 g) com água'),
      Meal(
          time: '08:00',
          title: 'Café pós-treino',
          description: 'Omelete de 3 ovos + 1 pão francês (ou 2 col. de tapioca) + 1 fatia de queijo minas'),
      Meal(
          time: '12:00',
          title: 'Almoço',
          description:
              'Proteína do bandejão + reforço de casa (2 ovos, 1/2 lata de atum ou sardinha, ou 80 g de frango) + 4 col. de arroz + 1 concha de feijão + salada'),
      Meal(
          time: '16:00',
          title: 'Lanche',
          description: '2 fatias de pão integral + 60 g de frango desfiado + requeijão light + 1 fruta'),
      Meal(time: '18:30', title: 'Lanche', description: '1 iogurte natural + 2 col. de aveia'),
      Meal(
          time: '20:00',
          title: 'Jantar',
          description: '100 g de frango, carne magra ou peixe + 5 col. de arroz ou massa + legumes + 1 col. chá de azeite'),
    ];

AppData seedData() => AppData(
      profile: Profile(),
      templates: seedTemplates(),
      sessions: [],
      body: [],
      meals: seedMeals(),
      notes: '',
    );
