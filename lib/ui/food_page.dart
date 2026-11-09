import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'widgets.dart';

const _statusLabels = {'ok': 'Seguiu', 'troca': 'Trocou', 'pulou': 'Pulou'};

IconData statusIcon(String? status) {
  switch (status) {
    case 'ok':
      return Icons.check_rounded;
    case 'troca':
      return Icons.swap_horiz;
    case 'pulou':
      return Icons.close_rounded;
    default:
      return Icons.circle_outlined;
  }
}

/// Cartão da tela Hoje: check-in rápido das refeições (toque alterna seguiu → trocou → pulou → vazio).
class FoodTodayCard extends StatelessWidget {
  const FoodTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final store = Store.instance;
    final data = store.data;
    final now = DateTime.now();
    final sum = foodSummary(data, now);
    final targets = computeTargets(data);
    return MooCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            'Alimentação',
            icon: Icons.restaurant_outlined,
            trailing: PillButton(
              label: 'Diário',
              icon: Icons.menu_book_outlined,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDayPage(day: now))),
            ),
          ),
          const SizedBox(height: 12),
          if (data.meals.isEmpty)
            Text('Monte o cardápio na aba Plano.', style: t.body(14, color: t.muted))
          else
            Row(
              children: [
                for (final m in data.meals)
                  Expanded(child: _MealDot(meal: m, day: now)),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            [
              '${sum.followed} de ${sum.meals} seguidas',
              'proteína ~${fmtNum(sum.protein, 0)}${targets.protein == null ? '' : ' de ${fmtNum(targets.protein!, 0)}'} g',
              if (sum.extras > 0) '${sum.extras} extra${sum.extras > 1 ? 's' : ''}',
            ].join(' · '),
            style: t.body(13, color: t.muted),
          ),
        ],
      ),
    );
  }
}

class _MealDot extends StatelessWidget {
  final Meal meal;
  final DateTime day;
  const _MealDot({required this.meal, required this.day});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final store = Store.instance;
    final status = store.mealEntry(day, meal)?.status;
    final filled = status == 'ok' || status == 'troca';
    final bg = status == 'ok' ? t.acc : (status == 'troca' ? t.surf2 : Colors.transparent);
    final fg = status == 'ok' ? t.onAcc : (status == 'pulou' ? t.muted : t.text);
    const order = [null, 'ok', 'troca', 'pulou'];
    return Semantics(
      button: true,
      label: '${meal.title} ${meal.time}: ${_statusLabels[status] ?? 'sem registro'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final next = order[(order.indexOf(status) + 1) % order.length];
          store.setMealStatus(day, meal, next);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: filled && t.borderWidth < 2 ? bg : (status == null ? t.muted.withAlpha(120) : t.line),
                    width: 2,
                  ),
                ),
                child: status == null ? null : Icon(statusIcon(status), size: 20, color: fg),
              ),
              const SizedBox(height: 4),
              Text(meal.time, style: t.body(11, weight: FontWeight.w600, color: t.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diário alimentar de um dia: check-in de cada refeição do plano e extras.
class FoodDayPage extends StatefulWidget {
  final DateTime day;
  const FoodDayPage({super.key, required this.day});

  @override
  State<FoodDayPage> createState() => _FoodDayPageState();
}

class _FoodDayPageState extends State<FoodDayPage> {
  late DateTime _day = dayOnly(widget.day);

  void _shift(int days) => setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _editTroca(Meal m, FoodEntry? existing) async {
    final r = await _foodDialog(context,
        title: 'O que você comeu no lugar?',
        initial: existing?.text ?? '',
        kcal: existing?.kcal,
        protein: existing?.protein);
    if (r == null) return;
    final store = Store.instance;
    await store.setMealStatus(_day, m, 'troca', text: r.text);
    final e = store.mealEntry(_day, m);
    if (e != null) {
      e
        ..kcal = r.kcal
        ..protein = r.protein;
      await store.save();
    }
  }

  Future<void> _addExtra() async {
    final r = await _foodDialog(context, title: 'Extra fora do plano');
    if (r == null || r.text.isEmpty) return;
    await Store.instance.addFood(FoodEntry(
      date: _day,
      status: 'extra',
      text: r.text,
      kcal: r.kcal,
      protein: r.protein,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = mt(context);
        final data = store.data;
        final isToday = sameDay(_day, DateTime.now());
        final sum = foodSummary(data, _day);
        final targets = computeTargets(data);
        final extras = store.foodOn(_day).where((f) => f.status == 'extra').toList();
        return Scaffold(
          appBar: mooAppBar(
            context,
            'Alimentação',
            subtitle: isToday ? 'Hoje · ${fmtDate(_day)}' : '${weekdayNames[_day.weekday]} · ${fmtDate(_day)}',
            actions: [
              IconButton(tooltip: 'Dia anterior', icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
              IconButton(
                tooltip: 'Próximo dia',
                icon: const Icon(Icons.chevron_right),
                onPressed: isToday ? null : () => _shift(1),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              MooCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 22,
                      runSpacing: 12,
                      children: [
                        StatTile(
                          label: 'Calorias (estimativa)',
                          value: fmtNum(sum.kcal, 0),
                          unit: targets.kcal == null ? 'kcal' : 'de ${fmtNum(targets.kcal!, 0)}',
                        ),
                        StatTile(
                          label: 'Proteína (estimativa)',
                          value: fmtNum(sum.protein, 0),
                          unit: targets.protein == null ? 'g' : 'de ${fmtNum(targets.protein!, 0)} g',
                          highlight: true,
                        ),
                        StatTile(label: 'Refeições seguidas', value: '${sum.followed}', unit: 'de ${sum.meals}'),
                      ],
                    ),
                    if (targets.protein != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: (sum.protein / targets.protein!).clamp(0.0, 1.0).toDouble(),
                          color: t.acc,
                          backgroundColor: t.surf2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text('Valores do cardápio, aproximados. Ajuste os números de cada refeição em Plano.',
                        style: t.body(12, color: t.muted)),
                  ],
                ),
              ),
              const SectionTitle('Refeições do plano', icon: Icons.restaurant_menu),
              for (final m in data.meals) ...[
                _MealCheckCard(
                  meal: m,
                  entry: store.mealEntry(_day, m),
                  onStatus: (st) async {
                    if (st == 'troca') {
                      await _editTroca(m, store.mealEntry(_day, m));
                    } else {
                      await store.setMealStatus(_day, m, st);
                    }
                  },
                  onEditTroca: () => _editTroca(m, store.mealEntry(_day, m)),
                ),
                const SizedBox(height: 10),
              ],
              SectionTitle(
                'Extras',
                icon: Icons.add_circle_outline,
                trailing: PillButton(label: 'Adicionar', icon: Icons.add, onPressed: _addExtra),
              ),
              if (extras.isEmpty)
                Text('Nada fora do plano neste dia.', style: t.body(14, color: t.muted)),
              for (final f in extras)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MooCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.text, style: t.body(15, weight: FontWeight.w600)),
                              if (f.kcal != null || f.protein != null)
                                Text(
                                  [
                                    if (f.kcal != null) '${fmtNum(f.kcal!, 0)} kcal',
                                    if (f.protein != null) '${fmtNum(f.protein!, 0)} g proteína',
                                  ].join(' · '),
                                  style: t.body(13, color: t.muted),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Apagar extra',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => store.deleteFood(f),
                        ),
                      ],
                    ),
                  ),
                ),
              const SectionTitle('Últimos 7 dias', icon: Icons.calendar_month_outlined),
              _WeekAdherence(end: _day),
            ],
          ),
        );
      },
    );
  }
}

class _MealCheckCard extends StatelessWidget {
  final Meal meal;
  final FoodEntry? entry;
  final ValueChanged<String?> onStatus;
  final VoidCallback onEditTroca;
  const _MealCheckCard({required this.meal, required this.entry, required this.onStatus, required this.onEditTroca});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final status = entry?.status;
    final macros = [
      if (meal.kcal != null) '${fmtNum(meal.kcal!, 0)} kcal',
      if (meal.protein != null) '${fmtNum(meal.protein!, 0)} g prot.',
    ].join(' · ');
    return MooCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meal.time, style: t.head(16, weight: FontWeight.w800, color: t.acc)),
              const SizedBox(width: 10),
              Expanded(child: Text(meal.title, style: t.body(15, weight: FontWeight.w700))),
              if (macros.isNotEmpty) Text(macros, style: t.body(12, color: t.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(meal.description, style: t.body(13, color: t.muted, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final st in const ['ok', 'troca', 'pulou'])
                ChoiceChip(
                  avatar: Icon(statusIcon(st), size: 18),
                  label: Text(_statusLabels[st]!),
                  selected: status == st,
                  onSelected: (sel) => onStatus(sel ? st : null),
                ),
            ],
          ),
          if (status == 'troca') ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onEditTroca,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: t.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          entry!.text.isEmpty ? 'Toque para dizer o que comeu' : entry!.text,
                          if (entry!.kcal != null) '${fmtNum(entry!.kcal!, 0)} kcal',
                          if (entry!.protein != null) '${fmtNum(entry!.protein!, 0)} g prot.',
                        ].join(' · '),
                        style: t.body(13, color: t.muted).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekAdherence extends StatelessWidget {
  final DateTime end;
  const _WeekAdherence({required this.end});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final data = Store.instance.data;
    final days = [for (var i = 6; i >= 0; i--) end.subtract(Duration(days: i))];
    return MooCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Builder(builder: (context) {
                final s = foodSummary(data, d);
                final frac = s.meals == 0 ? 0.0 : s.followed / s.meals;
                return Column(
                  children: [
                    Text('${s.followed}', style: t.body(12, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: 8 + 52 * frac,
                      decoration: BoxDecoration(
                        color: s.checked == 0 ? t.surf2 : t.acc,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(weekdayShort[d.weekday], style: t.body(11, color: t.muted)),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _FoodInput {
  final String text;
  final double? kcal;
  final double? protein;
  const _FoodInput(this.text, this.kcal, this.protein);
}

Future<_FoodInput?> _foodDialog(BuildContext context,
    {required String title, String initial = '', double? kcal, double? protein}) {
  final text = TextEditingController(text: initial);
  final k = TextEditingController(text: kcal == null ? '' : fmtNum(kcal, 0));
  final p = TextEditingController(text: protein == null ? '' : fmtNum(protein, 0));
  return showDialog<_FoodInput>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MooTextField(controller: text, label: 'O que comeu', autofocus: true, minLines: 1, maxLines: 3),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: NumberField(controller: k, label: 'kcal', decimal: false)),
                const SizedBox(width: 8),
                Expanded(child: NumberField(controller: p, label: 'Proteína', suffix: 'g', decimal: false)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Números opcionais. Sem eles, a troca conta como a refeição do plano.',
                style: mt(ctx).body(12, color: mt(ctx).muted)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _FoodInput(text.text.trim(), parseNum(k.text), parseNum(p.text))),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}
