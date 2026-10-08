# Arquitetura ML — Classificação de Risco de Vencimento

## Visão Geral

O EducastStock possui um sistema de inteligência artificial embarcado que analisa os lotes do estoque e classifica o **risco de vencimento** de cada produto em três níveis:

| Nível | Cor | Significado |
|-------|-----|-------------|
| `verde` | 🟢 | Seguro — situação normal |
| `amarelo` | 🟡 | Atenção — vencimento se aproximando ou estoque parado |
| `vermelho` | 🔴 | Crítico — risco iminente de perda, distribuição urgente |

---

## Fluxo de Classificação

```
Lote (Batch)
    │
    ▼
BatchFeatures.fromBatch()      ← extrai e normaliza as 4 features
    │
    ▼
ClassifierFactory               ← conditional import por plataforma
    ├── Web      → RuleBasedRiskClassifier
    └── Native   → TFLiteRiskClassifier (+ fallback rule-based)
          │
          ▼
      RiskPrediction
        • batchId
        • level (verde / amarelo / vermelho)
        • probabilities [p_verde, p_amarelo, p_vermelho]
        • confidence (probabilidade do nível vencedor)
        • source ("tflite" | "rule_based")
```

---

## Features de Entrada

Quatro variáveis numéricas, todas normalizadas para `[0, 1]`:

| Índice | Nome | Cálculo |
|--------|------|---------|
| 0 | `days_to_expiry_norm` | `dias_até_vencimento / 365` (1.0 se sem validade) |
| 1 | `quantity_ratio` | `qtd_atual / qtd_inicial` |
| 2 | `days_since_entry_norm` | `dias_em_estoque / 365` |
| 3 | `is_no_expiry` | `1.0` se sem validade, `0.0` se perecível |

A extração é feita pela classe `BatchFeatures.fromBatch(Batch b)` em
`lib/features/ml/domain/entities/risk_prediction.dart`.

---

## Dois Classificadores

### 1. `TFLiteRiskClassifier` (nativo — Android/iOS)

Carrega o modelo `assets/models/expiry_risk.tflite` em tempo de execução via `tflite_flutter`.

- Entrada: tensor `[1, 4]` (float32)
- Saída: tensor `[1, 3]` (softmax — probabilidades por classe)
- Inferência local **on-device**, sem chamada de rede
- Se o modelo não carregar, cai automaticamente no classificador de regras

### 2. `RuleBasedRiskClassifier` (todas as plataformas)

Classificador determinístico baseado em limiares. Serve como:

- **Backend do Web** (onde `tflite_flutter` não compila)
- **Fallback** para o TFLite em caso de erro de carregamento
- **Baseline** para comparação de acurácia

Regras aplicadas:

```
sem validade      → verde  (0.90, 0.08, 0.02)
vencido           → vermelho (0.02, 0.08, 0.90)
≤ 7 dias          → vermelho (urgência crescente)
8–30 dias         → amarelo  (vermelho se qty_ratio > 0.8 e days ≤ 20)
> 30 dias parado  → amarelo  (se > 60d em estoque e qty_ratio > 0.8 e days ≤ 90)
demais            → verde
```

---

## Seleção de Plataforma — Conditional Imports

O arquivo `lib/features/ml/data/repositories/classifier_factory.dart` usa
exports condicionais do Dart para garantir que `tflite_flutter` **nunca** seja
compilado no target Web:

```dart
export 'classifier_factory_stub.dart'
    if (dart.library.io)   'classifier_factory_native.dart'  // Android/iOS/desktop
    if (dart.library.html) 'classifier_factory_web.dart';    // Web
```

| Plataforma | Factory usada | Classificador |
|---|---|---|
| Android / iOS | `classifier_factory_native.dart` | `TFLiteRiskClassifier` → fallback `RuleBasedRiskClassifier` |
| Web | `classifier_factory_web.dart` | `RuleBasedRiskClassifier` direto |

---

## Providers Riverpod

Definidos em `lib/features/ml/presentation/controllers/risk_classifier_provider.dart`:

| Provider | Tipo | Descrição |
|---|---|---|
| `riskClassifierProvider` | `FutureProvider<RiskClassifierRepository>` | Singleton do classificador (inicializado uma vez) |
| `batchRiskPredictionsProvider` | `FutureProvider<List<RiskPrediction>>` | Predições de todos os lotes disponíveis |
| `batchRiskProvider(id)` | `FutureProvider.family<RiskPrediction?, String>` | Predição de um único lote por ID |
| `riskCountsProvider` | `FutureProvider<Map<RiskLevel, int>>` | Contagem por nível (para dashboard) |
| `criticalBatchPredictionsProvider` | `FutureProvider<List<RiskPrediction>>` | Só os vermelhos, ordenados por confidence |
| `classifierSourceProvider` | — | Fonte ativa: `"tflite"` ou `"rule_based"` |

---

## Como o Modelo TFLite Foi Gerado

Script: `scripts/ml/train_risk_model.py`

### Etapa 1 — Geração de dados sintéticos

São gerados **5.000 exemplos** com valores aleatórios para as 4 features, rotulados
pelas mesmas regras determinísticas do `RuleBasedRiskClassifier` (+ ~5% de ruído
para simular variabilidade real).

### Etapa 2 — Treino do Random Forest

Um `RandomForestClassifier` (scikit-learn) com 100 árvores e profundidade máxima 8
é treinado sobre os dados sintéticos. Relatório de classificação é impresso ao final.

### Etapa 3 — Destilação para rede densa (Knowledge Distillation)

Como `tflite_flutter` não aceita diretamente modelos sklearn, o RF é **destilado**
em uma rede neural Keras pequena:

```
4 → Dense(32, relu) → Dense(16, relu) → Dense(3, softmax)
```

A rede aprende as **probabilidades suaves** do RF em 10.000 amostras de destilação
por 60 épocas. Isso preserva o comportamento do RF num formato compatível com TFLite.

### Etapa 4 — Exportação TFLite

O modelo Keras é convertido com `tf.lite.TFLiteConverter` usando otimização padrão
(`DEFAULT`) e salvo em `assets/models/expiry_risk.tflite`.

---

## Tela de Insights (`MlInsightsPage`)

Localizada em `lib/features/ml/presentation/pages/ml_insights_page.dart`.

Exibe:
- Badge indicando se o classificador ativo é TFLite ou regras
- Contadores de lotes por nível de risco
- Lista de lotes críticos (vermelho) priorizados por confidence
- Tutorial interativo explicando os critérios de classificação

---

## Como Retreinar o Modelo

```bash
cd educastock/scripts/ml
pip install -r requirements.txt
python train_risk_model.py
```

O arquivo `assets/models/expiry_risk.tflite` será sobrescrito automaticamente.
