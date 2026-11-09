import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
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
        final t = mt(context);
        final data = store.data;
        final p = data.profile;
        final targets = computeTargets(data);
        final goal = goalFor(p.goal);
        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const PageHeader('Plano', kicker: 'Perfil, metas e cardápio'),

            // ---- Perfil ----
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: MooCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage())),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.surf2,
                        shape: BoxShape.circle,
                        border: t.borderWidth >= 2 ? Border.all(color: t.line, width: 2) : null,
                      ),
                      child: Text(
                        p.name.trim().isEmpty ? '?' : p.name.trim()[0].toUpperCase(),
                        style: t.head(20, weight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name.isEmpty ? 'Seu perfil' : p.name, style: t.body(16, weight: FontWeight.w700)),
                          Text(
                            [
                              p.heightCm == null ? 'altura ?' : '${fmtNum(p.heightCm!, 0)} cm',
                              p.age == null ? 'idade ?' : '${p.age} anos',
                              activityLevels[p.activity]?.split(' (').first ?? 'atividade ${fmtNum(p.activity, 2)}',
                            ].join(' · '),
                            style: t.body(13, color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: t.muted),
                  ],
                ),
              ),
            ),

            // ---- Objetivo ----
            const SectionTitle('Objetivo', icon: Icons.flag_outlined),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Text(
                '${goal.description} Ritmo-alvo: ${fmtNum(goal.weeklyMin, 1)} a ${fmtNum(goal.weeklyMax, 1)} kg por semana.',
                style: t.body(14, color: t.muted),
              ),
            ),

            // ---- Metas ----
            const SectionTitle('Metas diárias', icon: Icons.local_fire_department_outlined),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: MooCard(
                child: targets.missing != null
                    ? Text(targets.missing!, style: t.body(14, color: t.muted))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 22,
                            runSpacing: 12,
                            children: [
                              StatTile(label: 'Calorias', value: fmtNum(targets.kcal!, 0), unit: 'kcal'),
                              StatTile(
                                  label: 'Proteína', value: fmtNum(targets.protein!, 0), unit: 'g', highlight: true),
                              StatTile(label: 'Carboidratos', value: fmtNum(targets.carbs!, 0), unit: 'g'),
                              StatTile(label: 'Gorduras', value: fmtNum(targets.fat!, 0), unit: 'g'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Metabolismo basal ~${fmtNum(targets.bmr!, 0)} kcal · gasto estimado ~${fmtNum(targets.tdee!, 0)} kcal'
                            '${p.kcalOverride != null || p.proteinOverride != null ? ' · metas ajustadas manualmente' : ''}',
                            style: t.body(12, color: t.muted),
                          ),
                        ],
                      ),
              ),
            ),

            // ---- Cardápio ----
            SectionTitle(
              'Cardápio',
              icon: Icons.restaurant_menu,
              trailing: PillButton(label: 'Refeição', icon: Icons.add, onPressed: () => _editMeal(context, null)),
            ),
            for (final m in data.meals)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: MooCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => _editMeal(context, m),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 56, child: Text(m.time, style: t.head(16, weight: FontWeight.w800, color: t.acc))),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title, style: t.body(15, weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(m.description, style: t.body(14, color: t.muted, height: 1.35)),
                            if (m.kcal != null || m.protein != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  [
                                    if (m.kcal != null) '~${fmtNum(m.kcal!, 0)} kcal',
                                    if (m.protein != null) '${fmtNum(m.protein!, 0)} g proteína',
                                  ].join(' · '),
                                  style: t.body(12, weight: FontWeight.w600, color: t.muted),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ---- Anotações ----
            SectionTitle(
              'Anotações',
              icon: Icons.sticky_note_2_outlined,
              trailing: PillButton(label: 'Editar', icon: Icons.edit_outlined, onPressed: () => _editNotes(context)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: MooCard(
                onTap: () => _editNotes(context),
                child: Text(
                  data.notes.isEmpty ? 'Regras, suplementos, lembretes do seu plano.' : data.notes,
                  style: data.notes.isEmpty ? t.body(14, color: t.muted) : t.body(14, height: 1.4),
                ),
              ),
            ),

            // ---- Tema ----
            const SectionTitle('Tema', icon: Icons.palette_outlined),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  for (final th in mooThemes)
                    _ThemeSwatch(
                      theme: th,
                      selected: p.theme == th.key,
                      onTap: () {
                        p.theme = th.key;
                        store.save();
                      },
                    ),
                ],
              ),
            ),

            // ---- Backup ----
            const SectionTitle('Backup', icon: Icons.save_outlined),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: MooButton(
                      label: 'Copiar',
                      icon: Icons.copy,
                      primary: false,
                      expand: true,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: store.exportJson()));
                        if (context.mounted) showSnack(context, 'Backup copiado. Cole num e-mail ou no Drive.');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MooButton(
                      label: 'Restaurar',
                      icon: Icons.restore,
                      primary: false,
                      expand: true,
                      onPressed: () => _restore(context),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Text('MyMooscles 0.3 · dados salvos só neste celular.', style: t.body(12, color: t.muted)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editMeal(BuildContext context, Meal? meal) async {
    final store = Store.instance;
    final time = TextEditingController(text: meal?.time ?? '');
    final title = TextEditingController(text: meal?.title ?? '');
    final desc = TextEditingController(text: meal?.description ?? '');
    final kcal = TextEditingController(text: meal?.kcal == null ? '' : fmtNum(meal!.kcal!, 0));
    final prot = TextEditingController(text: meal?.protein == null ? '' : fmtNum(meal!.protein!, 0));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meal == null ? 'Nova refeição' : 'Editar refeição'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MooTextField(controller: time, label: 'Horário (ex.: 12:00)'),
              const SizedBox(height: 12),
              MooTextField(controller: title, label: 'Nome'),
              const SizedBox(height: 12),
              MooTextField(controller: desc, label: 'O que comer', minLines: 2, maxLines: 5),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: NumberField(controller: kcal, label: 'kcal', decimal: false)),
                  const SizedBox(width: 8),
                  Expanded(child: NumberField(controller: prot, label: 'Proteína', suffix: 'g', decimal: false)),
                ],
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
        store.data.meals.add(Meal(
          time: time.text.trim(),
          title: title.text.trim(),
          description: desc.text.trim(),
          kcal: parseNum(kcal.text),
          protein: parseNum(prot.text),
        ));
      } else {
        meal
          ..time = time.text.trim()
          ..title = title.text.trim()
          ..description = desc.text.trim()
          ..kcal = parseNum(kcal.text)
          ..protein = parseNum(prot.text);
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
        content: MooTextField(controller: c, label: 'Anotações', minLines: 6, maxLines: 12),
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
        content: MooTextField(controller: c, label: 'Cole aqui o texto do backup', minLines: 4, maxLines: 8),
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
      if (context.mounted) showSnack(context, 'Texto inválido: não é um backup do MyMooscles.');
    }
  }
}

/// Miniatura clicável de um tema, desenhada com as cores dele.
class _ThemeSwatch extends StatelessWidget {
  final MooTheme theme;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeSwatch({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cur = mt(context);
    final th = theme;
    final radius = BorderRadius.circular(cur.radius);
    return Semantics(
      selected: selected,
      button: true,
      label: 'Tema ${th.label}',
      child: Container(
        decoration: BoxDecoration(
          color: th.bg,
          borderRadius: radius,
          border: Border.all(color: selected ? cur.acc : (cur.isDark ? const Color(0xFF3A3F48) : cur.line), width: selected ? 3 : 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: th.surf,
                            borderRadius: BorderRadius.circular(8),
                            border: th.borderWidth > 0 ? Border.all(color: th.line, width: th.borderWidth) : null,
                            boxShadow: th.shadowOffset > 0 ? [BoxShadow(color: th.shadow, offset: const Offset(2, 2))] : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: th.acc,
                          borderRadius: BorderRadius.circular(8),
                          border: th.borderWidth >= 2 ? Border.all(color: th.line, width: 2) : null,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(th.label, style: th.head(16, weight: FontWeight.w800)),
                      ),
                      if (selected) Icon(Icons.check_circle, size: 20, color: th.acc),
                    ],
                  ),
                  Text(th.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: th.body(11, color: th.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final t = mt(context);
    return Scaffold(
      appBar: mooAppBar(context, 'Perfil'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: MooButton(label: 'Salvar', icon: Icons.check, expand: true, onPressed: _save),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          MooTextField(controller: _name, label: 'Nome', capitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: NumberField(controller: _height, label: 'Altura', suffix: 'cm')),
              const SizedBox(width: 12),
              Expanded(child: NumberField(controller: _age, label: 'Idade', suffix: 'anos', decimal: false)),
            ],
          ),
          const SizedBox(height: 16),
          Text('SEXO', style: t.kicker()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Masculino'),
                selected: _sex == 'M',
                onSelected: (_) => setState(() => _sex = 'M'),
              ),
              ChoiceChip(
                label: const Text('Feminino'),
                selected: _sex == 'F',
                onSelected: (_) => setState(() => _sex = 'F'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('NÍVEL DE ATIVIDADE', style: t.kicker()),
          const SizedBox(height: 8),
          for (final entry in activityLevels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MooCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                color: _activity == entry.key ? t.surf2 : null,
                onTap: () => setState(() => _activity = entry.key),
                child: Row(
                  children: [
                    Icon(_activity == entry.key ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _activity == entry.key ? t.acc : t.muted),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value, style: t.body(14, weight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text('AJUSTE MANUAL (OPCIONAL)', style: t.kicker()),
          const SizedBox(height: 4),
          Text('Deixe em branco para usar o cálculo automático. Use quando o acompanhamento pedir ajuste.',
              style: t.body(13, color: t.muted)),
          const SizedBox(height: 10),
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
