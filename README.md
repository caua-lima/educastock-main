# EducaStock 📦

> Site de teste (temporario): https://web-929079196105.southamerica-east1.run.app

Sistema de Gestão de Estoque para a ONG **Casa da Criança** — desenvolvido como Projeto Integrador do curso de **Desenvolvimento de Software Multiplataforma** da Fatec Itapira.

> **Status do projeto:** ~78% concluído — V1.0 em desenvolvimento ativo

## Equipe

| Nome | Função |
|---|---|
| Marco Aurelio Bubola | Dev Full-Stack / Arquitetura Firebase |
| Cauã Lima | Dev Mobile Flutter / Scanner & OCR |
| Letícia | Dev Mobile Flutter / Relatórios & Aprovações |
| Guilherme | Dev Full-Stack / Cloud Functions & ML |

## Sobre o Projeto

O **EducaStock** digitaliza e automatiza o controle de doações e suprimentos da ONG, substituindo planilhas manuais por um aplicativo multiplataforma com:

- 📷 **Leitura de código de barras** e **OCR de validade** (Google ML Kit)
- 🔄 **Política FEFO** obrigatória nas saídas (First Expired, First Out)
- 🔔 **Alertas de vencimento** automáticos e **notificações push** (Cloud Functions, plano Blaze)
- 🤖 **Machine Learning** — classificação de risco de vencimento (Verde/Amarelo/Vermelho)
- 📊 **Relatórios exportáveis** em PDF e CSV
- ✅ **Fluxo de aprovação** para ajustes negativos acima de limite
- 🌐 **Modo offline** com sincronização automática

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.x (Dart) — Android, iOS, Web |
| Estado | Riverpod 2 + riverpod_generator |
| Navegação | GoRouter |
| Backend | Firebase (Firestore, Auth, Storage, Functions) |
| Push | Firebase Cloud Messaging (FCM) |
| Scanner | mobile_scanner + Google ML Kit (OCR) |
| ML | Random Forest → TFLite (`tflite_flutter`) |
| Gráficos | fl_chart |
| Relatórios | `pdf` + `printing` (Dart) |
| Offline | Hive + connectivity_plus |
| CI/CD | GitHub Actions |

## Funcionalidades Implementadas ✅

- **Autenticação** com 4 perfis de acesso: `admin`, `estoquista`, `voluntario`, `visualizador`
- **Cadastro de produtos** com scanner de código de barras e integração Open Food Facts
- **Gestão de lotes** (batches) com data de validade e rastreabilidade
- **Movimentações de estoque**: entrada, saída, ajuste positivo/negativo e descarte
- **FEFO** — First Expired, First Out — aplicado automaticamente nas saídas
- **Dashboard** com indicadores em tempo real
- **Alertas de validade** — leitura da coleção `alerts` do Firestore
- **Localizações** de armazenamento no estoque
- **Receitas** de uso dos itens
- **Auditoria** de logs das últimas 100 ações
- **Classificação ML de risco** de lotes (Verde / Amarelo / Vermelho)
- **Design System** completo (`CasaButton`, `CasaTextField`, `CasaStatusChip`, etc.)
- **Configurações de UI** (tema, preferências do app)

## Dados de demonstração (fictícios)

`scripts/seed_realistic.mjs` gera uma operação de 5 meses da Casa da Criança (Itapira/SP) e grava no Firestore: 55 produtos, ~650 lotes, ~4.300 movimentações, auditoria, alertas, receitas e cestas, localizações, 16 doadores, ~120 doações com linha do tempo e relatório de impacto, necessidades do portal, previsões de consumo e classificações de risco. Lotes, movimentações e doações saem da mesma simulação, então os números fecham entre si. Pessoas, empresas, telefones e quantidades são **fictícios**; só a instituição, a cidade e o endereço da sede vêm de reportagem pública (Itapira News, 2016), e devem ser conferidos antes de divulgar.

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\caminho\da\chave.json"   # nunca versionar a chave
node scripts/seed_realistic.mjs            # simulação: mostra o que faria, sem gravar
node scripts/seed_realistic.mjs --apply    # apaga os dados de demonstração antigos e grava os novos
```

Preserva as contas de login, as configurações e o perfil de doador das contas reais. O `seed_database.mjs` antigo continua no repositório, mas grava dados mais simples: prefira o novo.

## Módulos entregues no PI (novembro/2026)

### Equipe: gestão das doações (telas S01 a S03)
Para administrador e estoquista (aba **Doações** na barra inferior, com selo de pendentes):

| Tela | O que faz |
|---|---|
| **S01 Fila de triagem** | Abas *Triagem* (intenções pendentes) e *Para destinar* (aprovadas aguardando entrega e recebidas sem destino). |
| **S02 Avaliar doação** | Doador, itens, validade informada e entrega prevista; mensagem opcional ao doador; **Aprovar** ou **Recusar** (com motivo). |
| **S03 Recebimento e impacto** | Conferência item a item (divergência exige nota, perecível exige validade), entrada automática no estoque (lote + movimento + auditoria), setor de destino e **mensagem de impacto** enviada ao doador. |

Tudo roda em transação no próprio app (protocolo `DOA-AAAA-NNNNNN`, reserva de quantidade, linha do tempo, auditoria e aviso ao doador), então funciona **sem** Cloud Functions publicadas. O doador vê o relatório de impacto e baixa o **recibo em PDF** na tela de acompanhamento (D09).

### Assistente virtual (Gemini)
Tela `ChatScreen` no portal do doador (botão *Tirar dúvidas com o assistente*), com `google_generative_ai`, balões azuis (doador) e cinza (assistente) e instruções de sistema sobre itens aceitos, validade e logística. A chave **não fica no código**:

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=SUA_CHAVE
flutter build web --release --dart-define=GEMINI_API_KEY=SUA_CHAVE
```

O app pede o `gemini-2.5-flash` e, se o Google o recusar (foi desativado para contas novas), troca sozinho para `gemini-flash-lite-latest` ou `gemini-flash-latest`. Atenção: uma chave passada por `--dart-define` fica dentro do app compilado; restrinja-a por domínio no Google AI Studio.

### Relatórios e desempenho
* **Exportação** de posição do estoque, movimentações, risco (ML) e reposição em **PDF**, **Excel (.xlsx)** e **CSV** (gerados em paralelo; funciona no celular e na web). O CSV usa `;` e BOM UTF-8 para abrir direto no Excel em português.
* **Consultas**: lotes a vencer calculados em memória a partir do fluxo em tempo real (zero leituras extras), resumo e categorias por `count()` agregado em paralelo, verificador de alertas sem consulta por lote (sem N+1), **paginação por cursor** no histórico e **cache de 5 minutos** nos relatórios.
* **Telas largas**: o conteúdo dos relatórios é centralizado com largura máxima em monitores ultrawide.

### Responsividade e uso no computador
* **Celular** (< 720 px): barra de abas inferior. **Tablet** (720–1199 px): navegação lateral recolhida. **Computador** (≥ 1200 px): navegação lateral com nomes, conteúdo centralizado e formulários numa coluna de leitura confortável.
* Grades de produtos calculam as colunas pela largura (2 no celular, até 6 no computador) e a altura pelo conteúdo, sem cartões gigantes nem estouros em celulares de 360 px. A fonte maior do sistema (acessibilidade) é respeitada até 1,3×.
* **Busca global** com **Ctrl+K** (⌘K no Mac): produtos por nome, marca ou código de barras e todas as telas do sistema, filtradas pelo papel do usuário. **Alt+1…6** troca de aba.
* **Carregamento sob demanda** (web): Relatórios, IA de risco, previsão, scanner, assistente e o módulo de exportação (PDF/Excel) só são baixados quando usados, deixando a abertura do app mais leve.
* **Teste de layout** (`test/responsive_layout_test.dart`): abre as 37 telas em 5 tamanhos (360 px a 1920 px) com dados falsos, rola cada uma até o fim, passa por todas as abas e falha em qualquer estouro de layout. Rode com `flutter test`.

### Alertas, OCR e modo offline
* Alertas de validade **gerados automaticamente** quando a equipe abre o app e a cada 6 horas; encerram sozinhos quando o lote sai da janela.
* **Leitura da validade pela câmera** (Android/iOS) reconhece `DD/MM/AAAA`, `DD/MM/AA`, `MM/AAAA`, meses abreviados (MAR, DEZ…) e corrige confusões O/0.
* **Offline**: saídas e ajustes de estoque ficam guardados no aparelho (Hive) e são enviados sozinhos quando a internet volta (sem duplicar e sem sobrescrever o que outra pessoa mexeu). Cadastro de lote e saída FEFO em massa exigem internet e avisam.
* **Push com o app fechado** (`onAlertCreated` e verificação diária `dailyExpiryCheck`): código pronto em `functions/`, mas a publicação exige o plano **Blaze** do Firebase: `firebase deploy --only functions`.

### Pendências
| # | Item | Observação |
|---|---|---|
| 1 | Publicar as Cloud Functions | Requer plano Blaze (decisão e cartão do titular do projeto) |
| 2 | Testar no aparelho Android/iOS real | Scanner, OCR e notificações dependem do hardware |
| 3 | Incluir as fontes Poppins e Nunito Sans nos assets | O tema já as referencia, mas os arquivos `.ttf` não estão em `assets/fonts/` (hoje o texto cai na Roboto) |

## Portal do Doador (Sprint 5)

Módulo externo para doadores (papel `doador`), com shell e rotas próprias em `/doador/*`
(`lib/features/donations`, `lib/core/router/donor_navigation_shell.dart`):

- **D02** cadastro autônomo (PF/PJ, consentimento LGPD) · **D11** perfil e privacidade
- **D03** início · **D04/D05** necessidades priorizadas (Crítica, Alta, Normal)
- **D06–D07** formulário de doação em 4 passos (rascunho local, validade mínima RN-D03)
- **D08/D09** histórico por status e acompanhamento (linha do tempo, cancelamento)
- Backend: `firestore.rules` (isStaffUser, autocadastro só cria `doador`), índices e as
  Cloud Functions `onDonationCreated` / `onDonationStatusChanged` em `functions/src/donations.ts`

Ordem de publicação: regras e índices → funções → app. Contas da equipe deixam de ser criadas
pelo cadastro público: crie-as no Firebase Console e promova com `scripts/set_admin.mjs`.
Dados de demonstração (necessidades, ponto e regras): `node scripts/seed_database.mjs`.

## Projeto Firebase

Todas as plataformas usam o mesmo projeto Firebase, `educastock-69936`:

| Plataforma | App ID | Arquivo de configuração |
|---|---|---|
| Web | `1:250042290294:web:edf271cf681e98d8318f57` | `lib/firebase_options.dart` |
| Android | `1:250042290294:android:6a8d159af9ec6a75318f57` | `android/app/google-services.json` |
| iOS | `1:250042290294:ios:447ff5ab9f294e36318f57` | `ios/Runner/GoogleService-Info.plist` |

Esses arquivos contêm apenas identificadores públicos do app (não são segredos); a proteção dos dados vem das
regras do Firestore (`firestore.rules`). **Nunca** versione chaves de service account (`serviceAccountKey.json`).
Para reconfigurar: `firebase apps:sdkconfig <ANDROID|IOS> <APP_ID> --project educastock-69936`.

## Módulo de Machine Learning

O modelo de **Random Forest** classifica cada lote em:

- 🟢 **Verde** — seguro (dias até vencimento OK, saída regular)
- 🟡 **Amarelo** — atenção (vencimento se aproximando ou estoque baixo)
- 🔴 **Vermelho** — crítico (vencimento iminente, risco de perda)

Treinamento em Python/scikit-learn → conversão para TFLite → inferência local no dispositivo (funciona offline).

## Documentação Acadêmica

Os documentos abaixo estão em [`docs/`](docs/) no padrão ABNT:

| Arquivo | Conteúdo |
|---|---|
| [Relatorio_PI_EducaStock.docx](docs/Relatorio_PI_EducaStock.docx) | Relatório principal: objetivos, requisitos, histórias de usuário, arquitetura e cronograma |
| [Relatorio_ML_EducaStock.docx](docs/Relatorio_ML_EducaStock.docx) | Estudo de viabilidade, bibliotecas Flutter/ML, modelo de IA e diagrama de fluxo |
| [Roteiro_Pitch_EducaStock.docx](docs/Roteiro_Pitch_EducaStock.docx) | Roteiro do pitch de 2 min 30 s para apresentação do PI |

## Como Executar

```bash
# Instalar dependências
flutter pub get

# Executar no Android/iOS (DEV)
flutter run --dart-define=APP_ENV=dev

# Executar no Android/iOS (HML)
flutter run --dart-define=APP_ENV=hml

# Executar no Android/iOS (PROD)
flutter run --dart-define=APP_ENV=prod

# Executar na Web (DEV)
flutter run -d chrome --dart-define=APP_ENV=dev

# Executar na Web (PROD + App Check)
flutter run -d chrome \
  --dart-define=APP_ENV=prod \
  --dart-define=APP_CHECK_WEB_RECAPTCHA_KEY=SEU_SITE_KEY

# Gerar APK de release por ambiente
flutter build apk --release --dart-define=APP_ENV=dev
flutter build apk --release --dart-define=APP_ENV=hml
flutter build apk --release --dart-define=APP_ENV=prod
```

## Estrutura Principal

```
lib/
  core/          # Design system, tema, roteamento, utilitários, notificações
  features/      # Módulos: auth, products, batches, stock, alerts,
                 #          reports, scanner, audit, dashboard, settings, ML
  infra/         # Repositórios Firebase, providers Riverpod, offline queue
functions/       # Cloud Functions TypeScript (alertas, push notifications)
docs/            # Documentação acadêmica (Word ABNT)
scripts/         # Scripts auxiliares (ML, seed de dados)
```

## Cronograma

| Sprint | Período | Entrega |
|---|---|---|
| S1 | Mar/2026 Sem 1-2 | ✅ Setup, autenticação, design system |
| S2 | Mar/2026 Sem 3-4 | ✅ CRUD produtos/lotes, scanner, integração Open Food Facts |
| S3 | Abr/2026 Sem 1-2 | ✅ FEFO, movimentações, fluxo de aprovação de ajuste |
| S4 | Abr/2026 Sem 3-4 | ✅ Dashboard, auditoria, ML de risco de lote |
| S5 | Mai/2026 Sem 1-2 | 🔧 Alertas automáticos, configurações, OCR de validade |
| S6 | Mai/2026 Sem 3-4 | 🔧 Relatórios completos, filtros, offline/sync |
| S7 | Jun/2026 Sem 1-2 | Cloud Functions, push notifications, testes, CI/CD |
| S8 | Jun/2026 Sem 3-4 | **Deploy PROD + Pitch (30/06/2026)** |

---

> Projeto Integrador — Fatec Itapira — Curso DSM — 2026
