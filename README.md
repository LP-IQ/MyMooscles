# MyMooscles

App Android pessoal para acompanhar treino de musculação, peso, medidas e metas de dieta. Gratuito, sem anúncios e sem conta: todos os dados ficam salvos no próprio celular.

## O que faz

- **Hoje:** mostra o treino do dia, o peso (último registro e média de 7 dias) e as metas de calorias e macros.
- **Treinos:** traz a divisão A–E editável (exercícios, séries, faixa de reps e carga inicial). Durante o treino você registra carga e reps de cada série e usa o cronômetro de descanso. O app sugere a próxima carga por **dupla progressão**: quando todas as séries chegam ao topo da faixa, a carga sobe cerca de 5%.
- **Corpo:** registra peso, cintura e bioimpedância (gordura, massa magra e visceral), com gráfico e média móvel de 7 dias. Depois de 2 semanas de pesagens, dá uma orientação de ajuste.
- **Plano:** guarda o perfil, o objetivo (emagrecer, recomposição, definir, ganhar massa, manter), as metas calculadas (Mifflin-St Jeor × atividade), o cardápio editável, anotações e o backup em texto.

## Instalar no celular

1. Abra a página [Releases](../../releases/latest) no navegador do celular.
2. Baixe **MyMooscles.apk**.
3. Abra o arquivo e permita "instalar apps desconhecidos" para o navegador.

Para atualizar, basta instalar o APK novo por cima. Todos os builds usam a mesma chave (`android-signing/debug.keystore`), então os dados são mantidos.

## Como o APK é gerado

Cada push na branch `main` dispara o workflow `.github/workflows/build-apk.yml`, que:

1. instala o Flutter estável;
2. gera a pasta `android/` com `flutter create`;
3. compila o APK de release;
4. publica o APK em uma Release.

## Desenvolvimento local

```bash
flutter create . --platforms=android --project-name mymooscles --org io.github.lpiq
flutter run
```

Estrutura:

- `lib/models.dart`: dados (perfil, treinos, sessões, medidas, cardápio)
- `lib/store.dart`: persistência em JSON local
- `lib/logic.dart`: metas de nutrição, progressão de carga e estatísticas de peso
- `lib/seed.dart`: treinos e cardápio iniciais
- `lib/ui/`: telas

## Aviso

As metas são estimativas e não substituem o acompanhamento de um nutricionista ou médico.
