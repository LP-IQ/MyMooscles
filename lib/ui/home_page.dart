import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'body_page.dart';
import 'plan_page.dart';
import 'widgets.dart';
import 'workout_pages.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = mt(context);
        final data = store.data;
        final now = DateTime.now();
        final today = store.templateForWeekday(now.weekday);
        final stats = weightStats(data.body, now);
        final targets = computeTargets(data);
        final advice = adjustmentAdvice(data, now);
        final name = data.profile.name.trim();
        final needsProfile = data.profile.heightCm == null || data.profile.age == null;
        final needsWeight = stats.last == null;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            _Greeting(name: name, now: now, today: today),
            const SizedBox(height: 14),
            if (needsProfile || needsWeight) ...[
              MooCard(
                color: t.surf2,
                onTap: () {
                  if (needsProfile) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage()));
                  } else {
                    openBodyEntry(context);
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: t.acc),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Complete o começo', style: t.body(15, weight: FontWeight.w700)),
                          Text(
                            [
                              if (needsProfile) 'altura e idade',
                              if (needsWeight) 'primeiro peso',
                            ].join(' · '),
                            style: t.body(13, color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.muted),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (data.draft != null) ...[
              DraftBanner(draft: data.draft!),
              const SizedBox(height: 14),
            ] else ...[
              _TodayCard(today: today, data: data, now: now),
              const SizedBox(height: 14),
            ],
            _WeekCard(data: data, now: now),
            const SizedBox(height: 14),
            MooCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardTitle('Peso',
                      icon: Icons.monitor_weight_outlined,
                      trailing: PillButton(label: 'Pesar hoje', icon: Icons.add, onPressed: () => _quickWeight(context))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 22,
                    runSpacing: 12,
                    children: [
                      StatTile(
                        label: stats.lastDate == null ? 'Último' : 'Último · ${fmtDateShort(stats.lastDate!)}',
                        value: stats.last == null ? '—' : fmtNum(stats.last!, 2),
                        unit: stats.last == null ? null : 'kg',
                      ),
                      StatTile(
                        label: 'Média 7 dias',
                        value: stats.avg7 == null ? '—' : fmtNum(stats.avg7!, 2),
                        unit: stats.avg7 == null ? null : 'kg',
                        dim: stats.avg7 == null,
                      ),
                      StatTile(
                        label: 'Na semana',
                        value: stats.weeklyChange == null
                            ? '—'
                            : '${stats.weeklyChange! > 0 ? '+' : ''}${fmtNum(stats.weeklyChange!, 2)}',
                        unit: stats.weeklyChange == null ? null : 'kg',
                        dim: stats.weeklyChange == null,
                      ),
                    ],
                  ),
                  if (advice != null) ...[
                    const SizedBox(height: 12),
                    Text(advice, style: t.body(14, weight: FontWeight.w600, color: t.acc)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            MooCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardTitle('Metas de hoje', icon: Icons.local_fire_department_outlined),
                  const SizedBox(height: 12),
                  if (targets.missing != null)
                    Text(targets.missing!, style: t.body(14, color: t.muted))
                  else
                    _MacroRow(items: [
                      ('Calorias', fmtNum(targets.kcal!, 0), 'kcal'),
                      ('Proteína', fmtNum(targets.protein!, 0), 'g'),
                      ('Carbo', fmtNum(targets.carbs!, 0), 'g'),
                      ('Gordura', fmtNum(targets.fat!, 0), 'g'),
                    ]),
                  const SizedBox(height: 10),
                  Text('Água: 2,5–3 L ao longo do dia, fora das refeições.', style: t.body(12, color: t.muted)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _quickWeight(BuildContext context) async {
    final c = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Peso de hoje'),
        content: NumberField(controller: c, label: 'Peso', suffix: 'kg', autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseNum(c.text)), child: const Text('Salvar')),
        ],
      ),
    );
    if (value == null) return;
    await Store.instance.addBody(BodyEntry(date: DateTime.now(), weight: value));
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  final DateTime now;
  final WorkoutTemplate? today;
  const _Greeting({required this.name, required this.now, required this.today});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final date = '${weekdayNames[now.weekday]}, ${fmtDateShort(now)}';
    if (!t.cowSpots) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date.toUpperCase(), style: t.label()),
          const SizedBox(height: 4),
          Text(name.isEmpty ? 'Olá!' : 'Olá, $name', style: t.head(32, weight: FontWeight.w800)),
        ],
      );
    }
    final line = today == null
        ? 'Dia de descanso. Recuperar também é treino.'
        : 'Hoje é dia de ${today!.name.toLowerCase()}.';
    return MooCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radius),
        child: Stack(
          children: [
            const Positioned(right: -10, top: -8, child: CowSpots()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: t.body(13, weight: FontWeight.w600, color: t.muted)),
                  const SizedBox(height: 4),
                  Text(name.isEmpty ? 'Bora!' : 'Bora, $name!', style: t.head(30, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 230,
                    child: Text(line, style: t.body(14, color: t.muted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final WorkoutTemplate? today;
  final AppData data;
  final DateTime now;
  const _TodayCard({required this.today, required this.data, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final tpl = today;
    final doneToday = data.sessions.where((s) => sameDay(s.start, now)).toList();
    final sets = tpl == null ? 0 : tpl.exercises.fold<int>(0, (a, e) => a + e.sets);
    final minutes = ((sets * 2.5) / 5).round() * 5;
    return MooCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TREINO DE HOJE', style: t.label()),
                    const SizedBox(height: 6),
                    Text(tpl == null ? 'Dia de descanso' : tpl.name, style: t.head(24, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      tpl == null
                          ? 'Sem treino marcado para hoje.'
                          : '${tpl.exercises.length} exercícios · ~$minutes min',
                      style: t.body(14, color: t.muted),
                    ),
                  ],
                ),
              ),
              if (tpl != null) ...[const SizedBox(width: 12), CodeBadge(tpl.code)],
            ],
          ),
          if (doneToday.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: t.good),
                const SizedBox(width: 6),
                Text('Feito hoje: ${doneToday.map((s) => s.templateCode).join(', ')}',
                    style: t.body(14, weight: FontWeight.w700, color: t.good)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (tpl != null) ...[
                Expanded(
                  child: MooButton(
                    label: 'Começar treino',
                    icon: Icons.play_arrow_rounded,
                    expand: true,
                    onPressed: () => startWorkout(context, tpl),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              tpl == null
                  ? Expanded(
                      child: MooButton(
                        label: 'Fazer um treino',
                        icon: Icons.swap_horiz,
                        expand: true,
                        onPressed: () => pickWorkout(context),
                      ),
                    )
                  : MooButton(
                      label: 'Outro',
                      icon: Icons.swap_horiz,
                      primary: false,
                      onPressed: () => pickWorkout(context),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final AppData data;
  final DateTime now;
  const _WeekCard({required this.data, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final monday = dayOnly(now).subtract(Duration(days: now.weekday - 1));
    final count = sessionsThisWeek(data, now);
    return MooCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle('Semana', trailing: Text('$count de 5 treinos', style: t.body(13, color: t.muted))),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 7; i++) Expanded(child: _dayCell(context, monday.add(Duration(days: i)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day) {
    final t = mt(context);
    String code = '';
    for (final tpl in data.templates) {
      if (tpl.weekday == day.weekday) code = tpl.code;
    }
    final done = data.sessions.any((s) => sameDay(s.start, day));
    final isToday = sameDay(day, now);
    Color bg = t.surf2;
    Color fg = code.isEmpty ? t.muted : t.text;
    Border? border = t.borderWidth >= 2 ? Border.all(color: code.isEmpty ? t.muted.withAlpha(80) : t.line, width: 2) : null;
    if (done) {
      bg = t.acc;
      fg = t.onAcc;
      if (t.borderWidth >= 2) border = Border.all(color: t.line, width: 2);
    } else if (isToday) {
      bg = t.surf;
      fg = t.acc;
      border = Border.all(color: t.acc, width: 2);
    }
    return Column(
      children: [
        Text(weekdayShort[day.weekday], style: t.body(11, weight: FontWeight.w600, color: t.muted)),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(t.key == 'claro' ? 12 : 19),
            border: border,
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 20, color: fg)
              : Text(code.isEmpty ? '·' : code, style: t.body(14, weight: FontWeight.w700, color: fg)),
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  final List<(String, String, String)> items;
  const _MacroRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    if (t.key == 'claro') {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
        children: [
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(items[i].$1, style: t.body(12, color: t.muted)),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: items[i].$2, style: t.head(18, weight: FontWeight.w800, color: i == 1 ? t.acc : t.text)),
                    TextSpan(text: ' ${items[i].$3}', style: t.body(12, weight: FontWeight.w600, color: t.muted)),
                  ])),
                ],
              ),
            ),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: Column(
              children: [
                Text(items[i].$2,
                    style: t.head(20, color: (i == 1 && t.key == 'noturno') ? t.acc : t.text)),
                const SizedBox(height: 2),
                Text('${items[i].$3} · ${items[i].$1}', style: t.body(11, color: t.muted), textAlign: TextAlign.center),
              ],
            ),
          ),
      ],
    );
  }
}
