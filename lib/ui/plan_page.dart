import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'widgets.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final data = store.data;
        final p = data.profile;
        final targets = computeTargets(data);
        final goal = goalFor(p.goal);
        final t = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Plano')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ---- Perfil ----
              const SectionTitle('Perfil'),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(p.name.isEmpty ? 'Sem nome' : p.name),
                subtitle: Text([
                  p.heightCm == null ? 'altura ?' : '${fmtNum(p.heightCm!, 0)} cm',
                  p.age == null ? 'idade ?' : '${p.age} anos',
                  p.sex == 'F' ? 'feminino' : 'masculino',
                  activityLevels[p.activity] ?? 'atividade ${fmtNum(p.activity, 2)}',
                ].join(' · ')),
                trailing: const Icon(Icons.edit),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage())),
              ),

              // ---- Objetivo ----
              const SectionTitle('Objetivo'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in goals)
                      ChoiceChip(
                        label: Text(g.label),
                        selected: p.goal == g.key,
                        onSelected: (_) {
                          p.goal = g.key;
                          store.save();
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '${goal.description} Ritmo-alvo: ${fmtNum(goal.weeklyMin, 1)} a ${fmtNum(goal.weeklyMax, 1)} kg por semana.',
                  style: t.bodyMedium,
                ),
              ),

              // ---- Metas ----
              const SectionTitle('Metas diárias'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: targets.missing != null
                    ? Text(targets.missing!)
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 24,
                                runSpacing: 12,
                                children: [
                                  StatTile(label: 'Calorias', value: '${fmtNum(targets.kcal!, 0)} kcal'),
                                  StatTile(label: 'Proteína', value: '${fmtNum(targets.protein!, 0)} g'),
                                  StatTile(label: 'Carboidratos', value: '${fmtNum(targets.carbs!, 0)} g'),
                                  StatTile(label: 'Gorduras', value: '${fmtNum(targets.fat!, 0)} g'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Metabolismo basal ~${fmtNum(targets.bmr!, 0)} kcal · gasto estimado ~${fmtNum(targets.tdee!, 0)} kcal'
                                '${p.kcalOverride != null || p.proteinOverride != null ? ' · metas ajustadas manualmente' : ''}',
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // ---- Cardápio ----
              SectionTitle(
                'Cardápio',
                trailing: IconButton(
                  tooltip: 'Adicionar refeição',
                  icon: const Icon(Icons.add),
                  onPressed: () => _editMeal(context, null),
                ),
              ),
              for (final m in data.meals)
                ListTile(
                  leading: Text(m.time, style: t.titleSmall),
                  title: Text(m.title),
                  subtitle: Text(m.description),
                  onTap: () => _editMeal(context, m),
                ),

              // ---- Anotações ----
              SectionTitle(
                'Anotações',
                trailing: IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editNotes(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  data.notes.isEmpty ? 'Regras, suplementos, lembretes do seu plano.' : data.notes,
                  style: data.notes.isEmpty ? t.bodySmall : t.bodyMedium,
                ),
              ),

              // ---- Backup ----
              const SectionTitle('Backup'),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copiar backup'),
                subtitle: const Text('Copia todos os dados (texto). Cole em um e-mail ou no Drive.'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: store.exportJson()));
                  if (context.mounted) showSnack(context, 'Backup copiado.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restaurar backup'),
                subtitle: const Text('Substitui todos os dados pelos do texto colado.'),
                onTap: () => _restore(context),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('GymApp 0.1 · dados salvos só neste celular.'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editMeal(BuildContext context, Meal? meal) async {
    final store = Store.instance;
    final time = TextEditingController(text: meal?.time ?? '');
    final title = TextEditingController(text: meal?.title ?? '');
    final desc = TextEditingController(text: meal?.description ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meal == null ? 'Nova refeição' : 'Editar refeição'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: time,
                  decoration: const InputDecoration(labelText: 'Horário (ex.: 12:00)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(labelText: 'O que comer', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          if (meal != null) TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Apagar')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('Salvar')),
        ],
      ),
    );
    if (result == 'delete' && meal != null) {
      store.data.meals.remove(meal);
    } else if (result == 'ok') {
      if (meal == null) {
        store.data.meals.add(Meal(time: time.text.trim(), title: title.text.trim(), description: desc.text.trim()));
      } else {
        meal
          ..time = time.text.trim()
          ..title = title.text.trim()
          ..description = desc.text.trim();
      }
      store.data.meals.sort((a, b) => a.time.compareTo(b.time));
    } else {
      return;
    }
    await store.save();
  }

  Future<void> _editNotes(BuildContext context) async {
    final store = Store.instance;
    final c = TextEditingController(text: store.data.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anotações'),
        content: TextField(
          controller: c,
          maxLines: 12,
          minLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true) {
      store.data.notes = c.text.trim();
      await store.save();
    }
  }

  Future<void> _restore(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: TextField(
          controller: c,
          maxLines: 8,
          minLines: 4,
          decoration: const InputDecoration(hintText: 'Cole aqui o texto do backup', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final sure = await confirmDialog(context, 'Substituir todos os dados?',
        'Os dados atuais deste celular serão trocados pelos do backup.', ok: 'Substituir');
    if (!sure) return;
    try {
      await Store.instance.importJson(c.text);
      if (context.mounted) showSnack(context, 'Backup restaurado.');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Texto inválido: não é um backup do GymApp.');
    }
  }
}

// ---------------------------------------------------------------------------
// Edição do perfil
// ---------------------------------------------------------------------------

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final p = Store.instance.data.profile;
  late final _name = TextEditingController(text: p.name);
  late final _height = TextEditingController(text: p.heightCm == null ? '' : fmtNum(p.heightCm!, 1));
  late final _age = TextEditingController(text: p.age == null ? '' : '${p.age}');
  late final _kcal = TextEditingController(text: p.kcalOverride == null ? '' : fmtNum(p.kcalOverride!, 0));
  late final _protein = TextEditingController(text: p.proteinOverride == null ? '' : fmtNum(p.proteinOverride!, 0));
  late String _sex = p.sex;
  late double _activity = activityLevels.containsKey(p.activity) ? p.activity : 1.4;

  @override
  void dispose() {
    for (final c in [_name, _height, _age, _kcal, _protein]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    p
      ..name = _name.text.trim()
      ..heightCm = parseNum(_height.text)
      ..age = parseInt(_age.text)
      ..sex = _sex
      ..activity = _activity
      ..kcalOverride = parseNum(_kcal.text)
      ..proteinOverride = parseNum(_protein.text);
    await Store.instance.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [TextButton(onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: NumberField(controller: _height, label: 'Altura', suffix: 'cm')),
              const SizedBox(width: 12),
              Expanded(child: NumberField(controller: _age, label: 'Idade', suffix: 'anos', decimal: false)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Sexo: '),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Masculino'),
                selected: _sex == 'M',
                onSelected: (_) => setState(() => _sex = 'M'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Feminino'),
                selected: _sex == 'F',
                onSelected: (_) => setState(() => _sex = 'F'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Nível de atividade', style: t.titleSmall),
          const SizedBox(height: 4),
          for (final entry in activityLevels.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_activity == entry.key ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(entry.value),
              onTap: () => setState(() => _activity = entry.key),
            ),
          const SizedBox(height: 16),
          Text('Ajuste manual (opcional)', style: t.titleSmall),
          const SizedBox(height: 4),
          Text('Deixe em branco para usar o cálculo automático. Use quando o acompanhamento pedir ajuste.',
              style: t.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: NumberField(controller: _kcal, label: 'Calorias', suffix: 'kcal', decimal: false)),
              const SizedBox(width: 12),
              Expanded(child: NumberField(controller: _protein, label: 'Proteína', suffix: 'g', decimal: false)),
            ],
          ),
        ],
      ),
    );
  }
}
