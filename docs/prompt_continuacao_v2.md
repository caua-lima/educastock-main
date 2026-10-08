# Prompt de Continuação — EducaStock v2

> Baseado na varredura completa do app em maio/2026.
> Completude atual estimada: **~75%**

---
## Contexto

O EducaStock é um app Flutter de controle de estoque para a ONG Casa da Criança. Já possui:
- Arquitetura Clean Architecture com Riverpod + GoRouter
- Firebase completo (Auth, Firestore, Storage, FCM, Crashlytics, Analytics, App Check)
- Design System próprio com componentes `Casa*` e tema claro/escuro (Material 3)
- Multi-ambiente (dev, hml, prod)
- 13 features implementadas entre 70–85% de completude

O código está em `lib/` organizado por `features/` e `core/`.

---

## O que fazer agora — por prioridade

### 🔴 Alta Prioridade (impacto direto na operação da ONG)

#### 1. Dashboard — Adicionar gráficos (feature: dashboard, 70% → 90%)
- Adicionar gráficos com `fl_chart` na `dashboard_page.dart`
- Gráfico de pizza: distribuição por categoria de produto
- Gráfico de linha: movimentações dos últimos 30 dias
- Gráfico de barras: lotes por urgência (verde/amarelo/vermelho)
- O pacote `fl_chart: ^0.69.0` já está no `pubspec.yaml`

#### 2. Receitas — Validação antes de executar (feature: recipes, 70% → 80%)
- Na `recipe_create_page.dart` / provider, antes de executar uma receita, verificar se há estoque suficiente de cada ingrediente
- Mostrar quais ingredientes estão indisponíveis com quantidade atual vs necessária
- Bloquear execução se estoque insuficiente (com opção de forçar para admin)

#### 3. Scanner — Reativar OCR de validade (feature: scanner, 75% → 90%)
- Existe `expiry_ocr_button.dart` mas está comentado/desativado
- Reativar usando `google_mlkit_text_recognition: ^0.13.0` (já no pubspec)
- Ao escanear, tentar ler data de validade por OCR do rótulo
- Preencher automaticamente o campo de data de validade no formulário de lote

#### 4. Auditoria — Filtro por usuário (feature: audit, 75% → 85%)
- Na `audit_page.dart`, adicionar filtro por nome/email do usuário que realizou a ação
- Reutilizar padrão de filtro já usado em outras páginas (CasaSearchBar + chips)

### 🟡 Média Prioridade (completude e qualidade)

#### 5. Alertas — Alertas customizáveis (feature: alerts, 75% → 85%)
- Permitir que o admin crie alertas manuais para qualquer produto/lote
- Na `alerts_page.dart`, adicionar botão FAB para criar alerta manual
- Campos: produto/lote, tipo (warning/critical/info), mensagem, data de expiração do alerta

#### 6. Relatórios — Agendamento e envio automático (feature: reports, 70% → 80%)
- Na `reports_page.dart`, adicionar opção "Agendar relatório semanal"
- Salvar preferência no Firestore via `settings_provider`
- Integrar com Firebase Cloud Functions (criar `functions/src/scheduledReport.ts`)
- Cloud Function roda semanalmente e envia relatório PDF por e-mail via SendGrid/Nodemailer

#### 7. Localizações — Capacidade e QR Code (feature: locations, 70% → 80%)
- Adicionar campo `capacity` (int) na entidade `StorageLocation`
- Mostrar `ocupação atual / capacidade` na `locations_page.dart`
- Gerar QR code da localização (para colar na prateleira física)
- Usar `qr_flutter` ou `mobile_scanner` para gerar/ler

#### 8. Produtos — Importação em massa (feature: products, 80% → 90%)
- Adicionar opção "Importar CSV" na `product_list_page.dart`
- Usar `file_picker` para selecionar arquivo CSV
- Parsear CSV: nome, categoria, código_barras, perecível (sim/não)
- Criar produtos em batch no Firestore com feedback de progresso

### 🟢 Baixa Prioridade (refinamentos e diferenciais)

#### 9. ML — Ativar modelo TFLite
- Descomentar `tflite_flutter: ^0.11.0` no `pubspec.yaml` (apenas builds Android/iOS)
- Implementar `tflite_risk_classifier.dart` usando o exemplo em `scripts/ml/`
- Testar com o modelo `assets/models/expiry_risk.tflite`
- Mostrar badge "TFLite ativo" na `ml_insights_page.dart`


#### 11. Auth — 2FA básico
- Adicionar autenticação de dois fatores via e-mail (OTP simples)
- Firebase Auth já suporta — apenas habilitar na console e implementar a tela

#### 12. Notificações — Modo silencioso
- Na `alerts_settings_page.dart`, adicionar configuração "Horário de silêncio"
- Salvar no Firestore: `silentFrom` e `silentUntil` (hora do dia)
- Respeitar na hora de exibir notificações locais

---

## Regras técnicas a manter

- Usar exclusivamente componentes do Design System (`Casa*` prefix)
- State management: Riverpod (sem setState em regras de negócio)
- Navegação: GoRouter (sem Navigator.push direto)
- Firebase Firestore: sempre usar transações atômicas para movimentações
- Feedback ao usuário: sempre ScaffoldMessenger (snackbar) + estados de loading
- Empty states: sempre `CasaEmptyState` com mensagem orientada à ação
- Não quebre rotas existentes em `app_router.dart`
- Manter multi-ambiente: dev/hml/prod via `firebase_options_*.dart`

---

## Arquivos-chave de referência

```
lib/core/design_system/design_system.dart       — barrel de componentes
lib/core/router/app_router.dart                 — todas as rotas
lib/core/theme/app_theme.dart                   — tema global
lib/features/auth/presentation/controllers/auth_provider.dart
lib/features/stock/presentation/controllers/stock_provider.dart
lib/features/dashboard/presentation/pages/dashboard_page.dart
lib/features/reports/presentation/pages/reports_page.dart
```

---

## Qualidade esperada

- Zero erros de compilação
- Nenhum `TODO` deixado sem implementar
- Toda nova tela com empty state, loading skeleton e tratamento de erro
- Responsivo: funcionar em mobile (360px) e web (1280px)
- Consistência visual com o Design System existente
