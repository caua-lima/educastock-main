# Entrega — correções da auditoria de 04/11/2026

Branch: `codex/correcoes-auditoria` (a partir de `main` em `3265da7`). Nada desta entrega foi publicado: Hosting, regras e funções em produção continuam como estavam.

## 1. Base verificável

| Item | Situação |
|---|---|
| Versão publicada | `main.dart.js` do site tem o mesmo SHA-256 (`f04a7db1…`) do build local gerado a partir de `f1c354e`. O commit seguinte (`3265da7`) mudou só cabeçalhos de cache do Hosting. Portanto o site = código de `f1c354e`. |
| Análise Flutter antes | `flutter analyze`: sem problemas (registro da auditoria). |
| Testes antes | 99 testes Flutter aprovados; TypeScript das funções compilava. |
| Ambiente isolado | Todos os testes que gravam usam **projeto `demo-educastock` no emulador** (projetos `demo-` não existem na nuvem) ou Firestore falso em memória. Nenhuma escrita na base real. O app ganhou `--dart-define=USE_EMULATORS=true` para testes manuais isolados. |
| SDK | Local Flutter 3.47.6 / Dart 3.13.5. CI alinhado a 3.47.6 (antes 3.24.5, incompatível com o lockfile). |

## 2. Achados: causa, solução e prova

Legenda: ✅ corrigido e testado · 🟡 parcial · ⛔ bloqueado (motivo indicado).

| # | Status | Causa | Solução | Prova |
|---|---|---|---|---|
| Relatórios `permission-denied` / contadores em "…" | 🟡 diagnosticado | Os dois sintomas vêm da mesma consulta: o stream de **lotes** (`batches`). As regras do repositório **permitem** essa e todas as leituras da aba Gráficos para administrador, estoquista, voluntário e consulta **ativos** (provado no emulador). Restam três hipóteses para produção, não verificáveis daqui sem credenciais: (1) regras publicadas diferentes das do repositório; (2) **App Check com imposição ligada** — o build web é gerado sem `APP_CHECK_WEB_RECAPTCHA_KEY`, então o App Check nunca é ativado na web e o Firestore responde exatamente "Missing or insufficient permissions"; os produtos apareceriam pelo cache local; (3) o documento `users/{uid}` da conta usada com `isActive` diferente de `true` ou papel fora da lista. | A falha agora aparece como aviso em português com "Tentar de novo" (em vez do erro técnico), os contadores mostram "—" e o erro técnico vai para o console. Regras **não** foram abertas. | `tests/rules` — 6 testes de leitura por papel. Para fechar: Console → App Check → APIs → Cloud Firestore (status "Imposto"?); Console → Firestore → Regras (comparar com `firestore.rules`); `users/{uid}` da conta. |
| A01 saídas/acréscimos concorrentes | ✅ | Leitura → cálculo → `WriteBatch` com valores absolutos. | Transação que relê cada lote, recalcula FEFO com o saldo atual e grava lote+movimentação+auditoria+registro da saída; ID de operação torna reenvio idempotente. Acréscimo ao lote em transação com entrada e auditoria. | `test/stock_concurrency_test.dart` (7): outro operador muda o lote no meio, saldo insuficiente não grava nada, dois operadores no mesmo lote, reenvio. Observação: Firestore falso não reproduz a contenção real do servidor; a garantia vem da semântica de transação do Firestore (repete com valores novos). |
| A02 2FA no cliente | ⛔ | Código gerado e conferido no cliente. | Não alterado. Exige verificação no servidor (Cloud Functions, plano **Blaze**) ou MFA do Identity Platform. Proposta em §5. | — |
| A03 Storage aberto | ✅ | `write/delete` para qualquer logado. | Só administrador/estoquista **ativos** enviam/apagam; só imagem até 5 MB; leitura para logados. O app hoje grava fotos em base64 no Firestore, então nada quebra. | `tests/rules` — 5 testes Storage. |
| A04 desativado com poder de admin | ✅ | `hasRole` não olhava `isActive`. | Papel só vale para conta ativa: admin desativado não administra nem se reativa. | `tests/rules` — 5 testes. |
| A05 gatilhos de doação repetidos/fora de ordem | ✅ (código) | Protocolo checado no snapshot do evento; IDs automáticos; reversão sem conferir o estado atual. | Releitura do documento dentro da transação; IDs fixos por evento (`event.id`) para linha do tempo, auditoria e aviso; reserva devolvida uma vez; reversão só se o status atual ainda é o do evento. | `functions/test/donations.emulator.test.js` (4) chama os gatilhos reais duas vezes no emulador. **Efeito em produção só após publicar as funções (Blaze).** |
| A06 campos internos de doação | 🟡 | Create sem lista de campos; equipe altera qualquer campo. | Create aceita só os 9 campos do formulário; equipe não troca `donorId` nem reescreve protocolo já emitido. Pendente: validar transição **antes** do commit (exige função chamável); `clientProcessedStatus` continua gravável pela equipe (usuários internos confiáveis). | `tests/rules` — 9 testes de doação. |
| A07 fila offline entre contas | ✅ | Caixa única; envia a fila inteira. | Pendências com dono e projeto; só envia as da conta/projeto atuais, confere o dono antes de cada envio, para ao sair; falhas viram conflito guardado até a pessoa descartar. Registros antigos usam `performedBy`. | `test/offline_isolation_test.dart` (5) com o controlador real e troca de conta. |
| A08 erro virando "sem estoque" | ✅ | `valueOrNull ?? []`. | Mapa de estoque com carregando/erro; lista de produtos não marca "Sem estoque" sem resposta; avisos com "Tentar de novo" no painel, Relatórios e lista; mensagens amigáveis em 10 telas. | Teste de layout + revisão. Pendente: algumas seções internas do Relatórios ainda escondem erro com `SizedBox.shrink`. |
| A09 gráfico `d += 5` | ✅ | Lia só os dias 0, 5, 10… | Série diária completa por dia civil; legenda mostra os totais. | `test/dates_and_series_test.dart`. |
| A10 lote sem histórico | ✅ | Segunda etapa com erro ignorado. | Lote + entrada + auditoria num único commit. | `test/stock_concurrency_test.dart`. |
| A11 ambientes iguais | 🟡 | dev/hml/prod apontam ao mesmo projeto. | Emuladores configurados (`firebase.json`) e `USE_EMULATORS`. Criar projetos separados é decisão do responsável pelo Firebase. | — |
| A12 CI | ✅ (arquivos) | Flutter 3.24.5; `npm ci || npm install`; deploy sem Hosting. | Flutter 3.47.6, `--enforce-lockfile`, `npm ci` puro, job de emuladores; deploy só após análise/testes e Hosting por opção explícita. | Roda ao enviar a branch (`codex/**`). |
| A13 chave Gemini no cliente | ⛔ | SDK cliente com `GEMINI_API_KEY`. | Não alterado: mover para backend exige Functions (Blaze). O site publicado foi gerado **sem** a chave (assistente desligado), então não há segredo exposto nele. | — |
| A14 rotas Express sem autenticação | ✅ | Admin SDK sem verificação. | Token do Firebase + papel admin/estoquista ativo; validação de entrada; corpo ≤ 16 KB; erros sem detalhes internos; lista fechada de campos. A exposição real (Cloud Run/IAM) não foi verificada. | `functions/test/http_auth.test.js` (9). |
| A15 fotos em base64 | ⛔/pendente | — | Não migrado (exige migração opcional e testes com dados reais). As regras do Storage já estão prontas para o upload. | — |
| A16 consultas inteiras | 🟡 | Um listener do Firestore **por cartão** de produto. | Cartões derivam os lotes do stream geral já carregado (≈55 listeners a menos na lista de produtos). Paginação de produtos não feita. | Revisão de código. |
| A17 carga inicial | 🟡 | — | Mantidos os imports diferidos; ZXing segue assíncrono (não bloqueia). Carregamento do ZXing só no scanner não feito. | Medições em §3. |
| A18 cache de relatórios | ✅ | keepAlive fechado não atualiza tela aberta; `lowStockProducts` fixo em 0. | Invalidação após gravações + botão "Atualizar"; campo fictício removido. | Revisão de código. |
| A19 validade por instante | ✅ | `isBefore(now)` e diferença em horas. | Dia civil: vale até o fim do dia impresso; listas mudam na virada do dia com o app aberto; função de alertas com a mesma regra no fuso de São Paulo. | `test/dates_and_series_test.dart` (5) e `functions/test/alerts.test.js` (3). |
| A20 acessibilidade | 🟡 | Escala limitada a 1,3×. | Limite elevado a **2,0×**; cabeçalhos com altura mínima; KPIs e cartões crescem com a fonte; teste de layout em 200% (celular e notebook) para todas as rotas. 7 pontos ainda estouram em 200% e estão **listados no teste** (qualquer novo reprova). Contraste, leitor de tela e teclado não foram auditados por completo. | `test/responsive_layout_test.dart` grupo "Fonte 200%". |
| A21 observabilidade/push | 🟡 | Crashlytics na web; push navegava sozinho; roteador antigo nos listeners. | Crashlytics só fora da web; push com app aberto mostra aviso com "Ver alertas"; listeners usam o roteador atual; tela "Tentar de novo" se a inicialização falhar. Pendente: service worker de push na web e momento do pedido de permissão. | Revisão de código. |

### Interface (observações do site)

- Painel no celular: sino + menu do avatar (Configurações, Dicas de uso, Tema) → saudação e data cabem em 390 px.
- Botão flutuante não cobre mais o fim da lista de produtos nem do painel (folga de rolagem).
- Legendas com nome de categoria em português ("Higiene pessoal").
- PC: navegação lateral, largura máxima e grades adaptativas já estavam no código local e **não estavam publicadas** (o site é `f1c354e`, anterior a elas). Capturas: `tool/capturas/`.

## 3. Medições

Mesma máquina, mesmo navegador, servidor local para os dois builds, 3 execuções alternadas.

| Medida | Publicado (`f1c354e`) | Branch | Observação |
|---|---|---|---|
| `main.dart.js` (bytes) | 5.374.175 | 5.417.218 | +43 KB (+0,8%): validações, avisos de erro, menus e regras novas |
| `main.dart.js` gzip -9 (bytes) | 1.524.791 | 1.536.897 | +12 KB |
| Partes diferidas | 16 arquivos / 982 KB | 16 / 983 KB | Relatórios, IA, scanner e exportação seguem fora da carga inicial |
| Evento `load` (ms) — 3 execuções | 1479 · 644 · 867 → **mediana 867** | 607 · 729 · 647 → **mediana 647** | localhost, Chrome do app, cache aquecido após a 1ª execução do publicado |
| Login montado na tela (ms, limite superior) | 1644 · 1264 · 1257 → **mediana 1264** | 987 · 861 · 990 → **mediana 987** | detecção por polling de 20 ms após a navegação |

Leitura honesta: o código novo aumentou o pacote em 0,8%; os tempos ficaram iguais ou menores, mas com rede local e só 3 execuções a diferença está dentro da variação — **não declaro ganho de velocidade**. O ganho de desempenho comprovável desta entrega é de leituras: a lista de produtos deixou de abrir um listener do Firestore por cartão.

Limites: medições só da tela de login (não há sessão autorizada para medir painel com dados nem leituras do Firestore). A redução de leituras da lista de produtos é por construção (listeners removidos), não medida em produção.

## 4. Testes executados

| Conjunto | Resultado |
|---|---|
| `flutter analyze` | sem problemas |
| `flutter test` (inclui 37 rotas × 5 tamanhos e 35 rotas em fonte 200%) | 153 aprovados |
| Regras no emulador (`tests/rules`) | 25 aprovados |
| Gatilhos de doação no emulador | 4 aprovados |
| Funções: middleware HTTP + regra de validade | 12 aprovados |
| TypeScript (`tsc`) | sem erros |

Comandos:

```bash
flutter analyze
flutter test
firebase emulators:exec --only firestore,storage --project demo-educastock "npm --prefix tests/rules test"
cd functions && npm run build && node --test test/http_auth.test.js test/alerts.test.js
firebase emulators:exec --only firestore --project demo-educastock "node --test functions/test/donations.emulator.test.js"
```

## 5. Plano de publicação e reversão

Antes de tudo: confira em `users` que toda a equipe tem `isActive: true` — com A04 o papel só vale para conta ativa (as leituras de estoque já exigiam isso, então quem já usa o app não deve perder acesso).

1. **Regras** (`firebase deploy --only firestore:rules,storage`). Validar logo depois: login de admin, saída, cadastro de lote, doação de teste por um doador.
   Reversão: `git show 3265da7:firestore.rules > firestore.rules && git show 3265da7:storage.rules > storage.rules && firebase deploy --only firestore:rules,storage`.
2. **Site** (`flutter build web --release --no-web-resources-cdn` + `firebase deploy --only hosting`). Opcional antes: canal de prévia `firebase hosting:channel:deploy auditoria --expires 7d` (usa os dados de produção — testar só leitura).
   Reversão: Console → Hosting → histórico de versões → "Reverter" para a versão atual (`f1c354e`).
3. **Funções** (A05, A14, alertas): só com plano Blaze. `firebase deploy --only functions`. Reversão: redeploy a partir de `3265da7`.
4. **App Check**: se a imposição estiver ligada, gerar o build web com `--dart-define=APP_CHECK_WEB_RECAPTCHA_KEY=...` (chave do site reCAPTCHA v3, que é pública) ou desligar a imposição até configurar.

Proposta A02 (2FA): função chamável `requestOtp`/`verifyOtp` com código guardado com hash, expiração (5 min), 5 tentativas e uso único, gravando uma *custom claim* `mfa: true` com validade; as regras passam a exigir `request.auth.token.mfa == true` para a equipe. Alternativa: MFA por SMS/TOTP do Identity Platform.

## 6. Pendências comprovadas

- Confirmar a causa do `permission-denied` em produção (§2, primeira linha).
- A02, A13, A15 (dependem de plano Blaze/decisão de produto).
- 7 pontos de layout em fonte 200% (listados no teste).
- Paginação do catálogo (A16), ZXing só no scanner (A17), service worker de push (A21).
- Testes em aparelho Android/iOS, scanner real e instalação PWA: não havia aparelho disponível.
