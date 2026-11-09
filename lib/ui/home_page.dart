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
        final data = store.data;
        final now = DateTime.now();
        final today = store.templateForWeekday(now.weekday);
        final doneToday = data.sessions.where((s) => sameDay(s.start, now)).toList();
        final stats = weightStats(data.body, now);
        final targets = computeTargets(data);
        final advice = adjustmentAdvice(data, now);
        final weekCount = sessionsThisWeek(data, now);
        final name = data.profile.name.trim();
        final t = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(name.isEmpty ? 'GymApp' : 'Olá, $name'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('${weekdayNames[now.weekday]}, ${fmtDate(now)}', style: t.bodyMedium),
              const SizedBox(height: 12),
              if (data.profile.heightCm == null || data.profile.age == null || stats.last == null)
                Card(
                  color: cs.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Complete o começo'),
                    subtitle: Text([
                      if (data.profile.heightCm == null || data.profile.age == null) 'altura e idade (Plano)',
                      if (stats.last == null) 'primeiro peso (Corpo)',
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (data.profile.heightCm == null || data.profile.age == null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditPage()));
                      } else {
                        openBodyEntry(context);
                      }
                    },
                  ),
                ),

              // ---- Treino de hoje ----
              if (data.draft != null)
                DraftBanner(draft: data.draft!)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Treino de hoje', style: t.labelLarge),
                        const SizedBox(height: 4),
                        if (today != null) ...[
                          Text('${today.code} · ${today.name}',
                              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                          Text('${today.exercises.length} exercícios', style: t.bodySmall),
                        ] else
                          Text('Dia de descanso', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        if (doneToday.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Feito hoje: ${doneToday.map((s) => s.templateCode).join(', ')} ✓',
                              style: t.bodyMedium?.copyWith(color: Colors.green.shade700),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (today != null)
                              FilledButton.icon(
                                onPressed: () => startWorkout(context, today),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Começar'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _pickOther(context, data),
                              icon: const Icon(Icons.swap_horiz),
                              label: Text(today == null ? 'Fazer um treino' : 'Outro treino'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_view_week),
                  title: Text('$weekCount de 5 treinos nesta semana'),
                  subtitle: LinearProgressIndicator(value: (weekCount / 5).clamp(0.0, 1.0).toDouble()),
                ),
              ),

              // ---- Peso ----
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Peso', style: t.labelLarge)),
                          TextButton.icon(
                            onPressed: () => _quickWeight(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Pesar hoje'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          StatTile(
                            label: 'Último',
                            value: stats.last == null ? '—' : '${fmtNum(stats.last!, 2)} kg',
                            sub: stats.lastDate == null ? null : fmtDateShort(stats.lastDate!),
                          ),
                          StatTile(
                            label: 'Média 7 dias',
                            value: stats.avg7 == null ? '—' : '${fmtNum(stats.avg7!, 2)} kg',
                            sub: stats.weeklyChange == null
                                ? null
                                : '${stats.weeklyChange! > 0 ? '+' : ''}${fmtNum(stats.weeklyChange!, 2)} na semana',
                          ),
                        ],
                      ),
                      if (advice != null) ...[
                        const SizedBox(height: 12),
                        Text(advice, style: t.bodyMedium?.copyWith(color: cs.primary)),
                      ],
                    ],
                  ),
                ),
              ),

              // ---- Metas do dia ----
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Metas de hoje · ${goalFor(data.profile.goal).label}', style: t.labelLarge),
                      const SizedBox(height: 8),
                      if (targets.missing != null)
                        Text(targets.missing!)
                      else
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
                      const SizedBox(height: 8),
                      Text('Água: 2,5–3 L ao longo do dia.', style: t.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickOther(BuildContext context, AppData data) async {
    final t = await showModalBottomSheet<WorkoutTemplate>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Escolha o treino')),
            for (final x in data.templates)
              ListTile(
                leading: CircleAvatar(child: Text(x.code.isEmpty ? '?' : x.code)),
                title: Text(x.name),
                subtitle: Text(weekdayNames[x.weekday]),
                onTap: () => Navigator.pop(ctx, x),
              ),
          ],
        ),
      ),
    );
    if (t != null && context.mounted) await startWorkout(context, t);
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
