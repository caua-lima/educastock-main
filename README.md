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
- 🔔 **Notificações push** de vencimento e baixo estoque (Firebase Messaging)
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

## Pendências em Desenvolvimento 🔧

| # | Funcionalidade | Prioridade |
|---|---|---|
| 1 | Geração automática de alertas de validade no Firestore | 🔴 Alta |
| 2 | Persistência das configurações de alertas e categorias | 🔴 Alta |
| 3 | OCR de data de validade no cadastro de lote | 🟠 Média-Alta |
| 4 | Relatório completo de movimentações por período | 🟠 Média-Alta |
| 5 | Filtros avançados na página de auditoria | 🟡 Média |
| 6 | Exportação da HistoryPage (CSV) + totalizadores | 🟡 Média |
| 7 | Push notifications via Cloud Functions | 🟡 Média |
| 8 | Fila offline com sincronização automática (Hive) | 🟢 Baixa |

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
