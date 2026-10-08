# 🤖 EducaStock — Guia de Integração dos Modelos de ML

> **Para quem?** Desenvolvedor do projeto que quer popular o banco de dados,
> treinar os modelos e integrar os resultados no app Flutter.

---

## Visão Geral dos 2 Modelos

| Modelo | Caso de Uso | Tecnologia | Como funciona |
|--------|------------|------------|---------------|
| **CU2 — Risco de Vencimento** | Classifica cada lote como Verde / Amarelo / Vermelho | Random Forest → TFLite (on-device) | Colab gera `.tflite` → você coloca em `assets/` → rebuild do app |
| **CU1 — Previsão de Consumo** | Prevê quanto vai ser consumido na próxima semana/mês | Prophet (séries temporais) | Colab escreve no Firestore → app lê automaticamente via StreamProvider |

---

## Pré-requisito: Chave de Serviço Firebase

Ambos os notebooks precisam do arquivo `serviceAccountKey.json`:

1. Acesse [Firebase Console](https://console.firebase.google.com)
2. Selecione o projeto **EducaStock**
3. Engrenagem ⚙️ → **Configurações do Projeto**
4. Aba **Contas de serviço**
5. Clique em **Gerar nova chave privada** → salva como `serviceAccountKey.json`

> ⚠️ **NUNCA suba este arquivo para o GitHub.** Ele dá acesso total ao seu Firestore.  
> Ele já está no `.gitignore`. Guarde-o em local seguro.

---

## Parte 1 — Popular o Banco de Dados

Quanto mais dados reais você tiver, melhor os modelos funcionam. Siga esta ordem:

### 1.1 — Cadastrar Produtos

No app, acesse **Produtos → + Novo Produto** e cadastre os itens do estoque da ONG.

Campos importantes:
- **Nome** (ex: "Fraldas P", "Leite em pó", "Caderno")
- **Categoria** (ex: "Higiene", "Alimentação", "Escolar")
- **Tem validade?** — marque corretamente, pois é a feature mais importante do CU2

### 1.2 — Cadastrar Lotes (`batches`)

Cada lote representa uma entrada de itens no estoque. Para treinar o CU2 você precisa de lotes com:

| Campo | Tipo | Exemplo |
|-------|------|---------|
| `productId` | string | ID do produto criado acima |
| `productName` | string | "Fraldas P" |
| `quantity` | int | 50 ← quantidade atual |
| `initialQuantity` | int | 80 ← quantidade quando entrou |
| `expiryDate` | ISO string | "2025-09-15T00:00:00.000Z" |
| `noExpiry` | bool | false |
| `entryDate` | ISO string | "2025-03-01T00:00:00.000Z" |
| `status` | string | "disponivel" |

**Dica:** Para o CU2 ficar bom, tente ter ao menos **30–50 lotes** com diferentes datas de validade.  
Se quiser começar com poucos, tudo bem — o notebook usa dados sintéticos como complemento.

### 1.3 — Registrar Movimentações de Saída (`stock_movements`)

O **CU1 (Prophet)** depende do histórico de saídas. Cada movimentação registrada no app
(aba Movimentação → Saída) cria um documento nesta coleção.

Campos criados automaticamente pelo app:
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `productId` | string | ID do produto |
| `productName` | string | Nome |
| `type` | string | `"saida"` ou `"descarte"` |
| `quantity` | int | Quantidade saída |
| `performedAt` | ISO string | Data/hora da movimentação |

**Para o Prophet funcionar bem**, você precisa de:
- Ao menos **10 saídas por produto** ao longo de semanas/meses diferentes
- Quanto mais histórico (60–90 dias), melhor a previsão de tendência e sazonalidade

> Se ainda não tem histórico suficiente, o modelo usará **Média Móvel Ponderada** como
> fallback automático (indicado com badge "Média Móvel" no app).

---

## Parte 2 — CU2: Treinar o Modelo de Risco de Vencimento (TFLite)

**Notebook:** `scripts/ml/train_risk_model_colab.ipynb`

### Como executar

1. Acesse [Google Colab](https://colab.research.google.com)
2. **Arquivo → Fazer upload de notebook** → selecione `scripts/ml/train_risk_model_colab.ipynb`
3. Execute as células em ordem (**Runtime → Run all**):

| Célula | O que faz |
|--------|-----------|
| 1 | Instala `firebase-admin`, `scikit-learn`, `tensorflow` |
| 2 | Upload do `serviceAccountKey.json` |
| 3 | Conecta ao Firestore |
| 4 | Exporta lotes reais → DataFrame |
| 5 | Extrai as 4 features + rotula automaticamente |
| 6 | Gera dados sintéticos para complementar |
| 7 | Treina Random Forest + mostra métricas e gráficos |
| 8 | Destila RF → rede neural densa → converte para TFLite + **baixa o arquivo** |
| 9 | (Opcional) Salva metadados JSON |

### Como integrar no app

Após o download do `expiry_risk.tflite`:

```
1. Copie o arquivo para:
   educastock/assets/models/expiry_risk.tflite
   (substitui o arquivo existente)

2. Rebuild do app:
   flutter run        (modo debug)
   flutter build apk  (Android release)

3. Verifique no app:
   Dashboard → seção "Risco ML"
   O badge vai mostrar "tflite" em vez de "rule_based"
```

### Quando re-treinar?

- Quando o estoque crescer bastante (muitos lotes novos cadastrados)
- A cada 1–3 meses, para refletir novos padrões
- Se a acurácia parecer baixa (muitos falsos alarmes ou alarmes perdidos)

---

## Parte 3 — CU1: Gerar Previsões de Consumo (Prophet)

**Notebook:** `scripts/ml/consumption_forecast.ipynb`

### Como executar

1. Acesse [Google Colab](https://colab.research.google.com)
2. **Arquivo → Fazer upload de notebook** → selecione `scripts/ml/consumption_forecast.ipynb`
3. Execute as células em ordem:

| Célula | O que faz |
|--------|-----------|
| 1 | Instala `prophet`, `firebase-admin`, `pandas` |
| 2 | Upload do `serviceAccountKey.json` |
| 3 | Conecta ao Firestore |
| 4 | Exporta histórico de saídas (`stock_movements`, tipo: saida/descarte) |
| 5 | Exporta estoque atual por produto |
| 6 | Agrega saídas por produto/dia |
| 7 | Treina Prophet por produto (fallback: Média Móvel se < 10 pontos) |
| 8 | Escreve previsões na coleção `consumption_forecasts` do Firestore |
| 9 | Gera gráficos de previsão com matplotlib |
| 10 | Resumo final |

### O que acontece no app automaticamente

Assim que o notebook termina de escrever no Firestore:

- O **dashboard** mostra a seção "Sugestão de Reposição" com os 5 produtos mais urgentes
- A **página de Previsão** (`/ml/forecast`) exibe todas as previsões com filtros
- Cada card mostra: previsão semanal/mensal, estoque atual, sugestão de reposição, tendência

### Quando re-executar o notebook?

- **Mensalmente** é o ideal para ONGs com fluxo regular
- Após grandes movimentações (doações ou distribuições em massa)
- Quando quiser atualizar as sugestões de reposição antes de uma reunião

---

## Parte 4 — Fluxo Resumido (do zero ao modelo funcionando)

```
┌─────────────────────────────────────────────────────────────┐
│  1. Cadastrar produtos no app                               │
│  2. Cadastrar lotes com validade (mín. 30 lotes para CU2)  │
│  3. Registrar saídas ao longo do tempo (para CU1)           │
└───────────────┬─────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│  CU2: train_risk_model_colab.ipynb                         │
│  → baixa expiry_risk.tflite                                │
│  → copia para assets/models/ → flutter build               │
│  → app classifica lotes em Verde/Amarelo/Vermelho          │
└─────────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│  CU1: consumption_forecast.ipynb                           │
│  → Prophet treina por produto                               │
│  → escreve em Firestore (consumption_forecasts)            │
│  → app exibe sugestões de reposição no dashboard            │
└─────────────────────────────────────────────────────────────┘
```

---

## Estrutura dos Arquivos ML

```
scripts/ml/
├── train_risk_model_colab.ipynb   ← CU2: Colab com dados reais do Firestore
├── train_risk_model.py            ← CU2: Script local (apenas sintético)
├── consumption_forecast.ipynb     ← CU1: Colab Prophet
├── generate_placeholder_model.py  ← Gera modelo placeholder para CI/CD
└── requirements.txt               ← Dependências para rodar localmente

assets/models/
├── expiry_risk.tflite             ← Modelo TFLite (substituído após Colab)
└── expiry_risk_meta.json          ← Metadados do modelo (opcional)
```

---

## Perguntas Frequentes

**P: O app funciona sem treinar nenhum modelo?**  
R: Sim. O CU2 usa o classificador baseado em regras como fallback (sem TFLite).  
O CU1 mostra estado vazio com instruções para rodar o Colab.

**P: E se eu não tiver lotes suficientes?**  
R: O notebook do CU2 complementa automaticamente com dados sintéticos (baseados nas mesmas regras).
Basta ter pelo menos 1 lote no Firestore para ele funcionar.

**P: O Prophet precisa de dados históricos?**  
R: Sim. Sem histórico de saídas, ele não gera previsão para aquele produto.  
Mínimo recomendado: 10 registros de saída por produto em dias diferentes.

**P: Com que frequência preciso rodar os notebooks?**  
R: CU1 (Prophet) → mensalmente ou após grandes eventos de doação/distribuição.  
CU2 (TFLite) → a cada 2–3 meses ou quando o acervo de lotes crescer muito.

**P: O modelo fica melhor com o tempo?**  
R: Sim! Quanto mais lotes reais cadastrados e mais histórico de saídas acumulado,
mais preciso fica o CU2. O CU1 melhora conforme mais saídas são registradas.

---

## Localização dos Notebooks no Google Colab

Para deixar os notebooks sempre acessíveis, você pode:
1. Salvar no **Google Drive** pessoal
2. Abrir direto do GitHub: `File → Open notebook → GitHub → cole a URL do repositório`

---

*Guia gerado automaticamente — EducaStock v1.0 | ONG Casa da Criança*
