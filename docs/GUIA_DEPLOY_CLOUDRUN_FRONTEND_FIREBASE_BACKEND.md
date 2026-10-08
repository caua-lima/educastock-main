# Guia completo: Frontend no Cloud Run + Backend no Firebase (do zero, nova conta)

Este guia cobre tudo que voce precisa fazer ao criar um projeto novo em uma nova conta Google:
configurar o Firebase do zero, banco de dados, autenticacao, storage, functions e subir o frontend no Cloud Run.

Arquitetura:

- Frontend Web (Flutter): Cloud Run (container Docker + nginx)
- Backend completo: Firebase (Firestore, Auth, Storage, Functions, FCM)

O repositorio ja tem um `Dockerfile` pronto. Voce nao precisa criar nenhum.

---

## Visao geral do fluxo

```
Usuario no browser
       |
       v
Cloud Run (container Docker com nginx)
  -> serve o build web do Flutter
  -> o app Flutter chama o Firebase diretamente
       |
       v
Firebase
  -> Auth          (login e gestao de usuarios)
  -> Firestore     (banco de dados em tempo real)
  -> Storage       (arquivos e imagens)
  -> Functions     (alertas, agendamentos, auditoria)
  -> FCM           (notificacoes push)
```

---

## PARTE 1: Criar conta e projeto do zero

> Todos os passos desta parte sao feitos no **Google Cloud Console** (console.cloud.google.com) — exceto o passo 1 que e no Google.

---

### 1) Criar conta Google (se necessario)

1. Acesse accounts.google.com.
2. Clique em Criar conta.
3. Preencha nome, e-mail e senha.
4. Confirme e-mail.

---

### 2) Criar projeto no Google Cloud

> **Google Cloud Console** → console.cloud.google.com

1. Acesse console.cloud.google.com com a nova conta.
2. No topo da tela, clique no seletor de projeto.
3. Clique em Novo projeto.
4. Nome do projeto: `educastock` (ou nome de sua preferencia).
5. Deixe a organizacao em branco se for conta pessoal.
6. Clique em Criar.
7. Aguarde o projeto ser criado e selecione-o.

---

### 3) Ativar faturamento (obrigatorio para Cloud Run e Functions)

> **Google Cloud Console** → console.cloud.google.com → menu lateral > Faturamento

1. No menu lateral, clique em Faturamento.
2. Clique em Vincular conta de faturamento.
3. Clique em Criar conta de faturamento se nao tiver uma.
4. Preencha nome, pais (Brasil) e dados de pagamento.
5. Confirme e vincule ao projeto.

Importante:
O plano gratuito do Firebase (Spark) nao permite Functions 2nd gen nem Cloud Run.
Voce precisa do plano Blaze (pago por uso) para este projeto funcionar.
O custo real para uma ONG pequena normalmente fica dentro da cota gratuita mensal.

---

### 4) Ativar APIs obrigatorias no Google Cloud

> **Google Cloud Console** → console.cloud.google.com → APIs e servicos > Biblioteca

Ativar uma por uma:

Para o frontend (Cloud Run):

1. Cloud Run Admin API
2. Cloud Build API
3. Artifact Registry API
4. Secret Manager API
5. Cloud Logging API
6. Cloud Monitoring API

Para o backend (Firebase Functions):

7. Cloud Functions API
8. Cloud Scheduler API
9. Firebase Management API
10. Firestore API

Como ativar cada uma:

1. Pesquise o nome da API na barra de busca da Biblioteca.
2. Clique no resultado correto.
3. Clique em Ativar.
4. Aguarde ativacao (alguns segundos).
5. Repita para cada API da lista.

---

## PARTE 2: Configurar o Firebase do zero

> Todos os passos desta parte sao feitos no **Firebase Console** (console.firebase.google.com).

---

### 5) Criar projeto Firebase vinculado ao Google Cloud

> **Firebase Console** → console.firebase.google.com

1. Acesse console.firebase.google.com com a mesma conta Google.
2. Clique em Adicionar projeto.
3. Clique em Importar projeto do Google Cloud.
4. Selecione o projeto que voce criou no passo 2.
5. Clique em Continuar.
6. Ative o Google Analytics se quiser (opcional).
7. Clique em Adicionar Firebase.
8. Aguarde a configuracao ser concluida.

---

### 6) Configurar Authentication (login de usuarios)

> **Firebase Console** → console.firebase.google.com → seu projeto > Authentication

1. No Firebase Console, clique em Authentication no menu lateral.
2. Clique em Comecar.
3. Va na aba Metodo de login.
4. Ative os provedores que o app usa:
   - E-mail/senha: clique, ative e salve.
   - Google: clique, ative, informe nome do projeto e e-mail de suporte, salve.
5. Va na aba Configuracoes e defina o dominio autorizado:
   - Adicione o dominio do Cloud Run quando tiver a URL.
   - Adicione `localhost` para testes locais.

---

### 7) Configurar Firestore (banco de dados)

> **Firebase Console** → console.firebase.google.com → seu projeto > Firestore Database

1. No menu lateral, clique em Firestore Database.
2. Clique em Criar banco de dados.
3. Escolha Modo de producao (mais seguro).
4. Selecione a regiao: `southamerica-east1` (Brasil).
5. Clique em Criar.
6. Aguarde o banco ser provisionado.

Configurar regras de seguranca do Firestore:

1. Clique na aba Regras.
2. Substitua o conteudo pelo conteudo do arquivo `firestore.rules` do repositorio.
3. Clique em Publicar.

Estrutura de colecoes esperada pelo app (criadas automaticamente no primeiro uso):

- `users` - usuarios cadastrados
- `products` - produtos do estoque
- `batches` - lotes de produtos
- `alerts` - alertas de vencimento e estoque baixo
- `audit_logs` - registro de alteracoes sensiveis
- `device_tokens` - tokens FCM para notificacoes
- `settings` - configuracoes do sistema
- `stock_movements` - movimentacoes de estoque

Voce nao precisa criar essas colecoes manualmente. O app cria ao primeiro uso.

---

### 8) Configurar Storage (arquivos e imagens)

> **Firebase Console** → console.firebase.google.com → seu projeto > Storage

1. No menu lateral, clique em Storage.
2. Clique em Comecar.
3. Escolha Modo de producao.
4. Selecione a regiao: `southamerica-east1`.
5. Clique em Concluir.

Configurar regras de seguranca do Storage:

1. Clique na aba Regras.
2. Substitua o conteudo pelo conteudo do arquivo `storage.rules` do repositorio.
3. Clique em Publicar.

---

### 9) Configurar Cloud Messaging (FCM - notificacoes push)

> **Firebase Console** → console.firebase.google.com
> Em alguns projetos aparece como **Messaging** (menu lateral) em vez de **Mensagens na nuvem/Cloud Messaging**.

1. Tente abrir por um destes caminhos:
   - Menu lateral > **Messaging**.
   - Configuracoes do projeto (engrenagem) > aba **Cloud Messaging**.
2. O FCM e habilitado automaticamente ao criar o projeto Firebase.
3. Nao e necessaria configuracao adicional pelo console para o backend neste momento.
4. Se abrir uma tela para criar campanha de mensagem, pode fechar (nao e obrigatorio para configurar o app).
5. O app Android/iOS precisa do arquivo de configuracao correto (passos 12 e 13).

---

### 10) Configurar Functions (backend)

> **Firebase Console** → console.firebase.google.com → seu projeto > Functions

1. No menu lateral, clique em Functions.
2. Clique em Comecar.
3. Confirme que o projeto esta no plano Blaze (sera solicitado se nao estiver).
4. A configuracao de runtime sera feita no deploy.

Funcoes presentes no repositorio (`functions/src/index.ts`):

- `generateExpiryAlerts` - agendada todo dia as 07:00 (America/Sao_Paulo).
- `generateLowStockAlerts` - agendada todo dia as 07:10 (America/Sao_Paulo).
- `auditSensitiveChanges` - gatilho ao alterar produtos, lotes, usuarios e settings.
- `notifyOnAlertCreated` - gatilho ao criar alerta, dispara notificacao FCM.

As funcoes sao publicadas via terminal ou CI/CD. O console serve para monitorar.

---

## PARTE 3: Conectar o app ao novo projeto Firebase

> Todos os passos desta parte sao feitos no **Firebase Console** (console.firebase.google.com).

---

### 11) Registrar o app Web no Firebase

> **Firebase Console** → console.firebase.google.com → Configuracoes do projeto (engrenagem) > Seus aplicativos

1. No Firebase Console, clique na engrenagem > Configuracoes do projeto.
2. Role ate Seus aplicativos.
3. Clique no icone Web (</> ).
4. Nome do app: `EducaStock Web`.
5. Nao marque Firebase Hosting (estamos usando Cloud Run).
6. Clique em Registrar app.
7. Copie o objeto `firebaseConfig` exibido. Ele tem esta forma:

```
const firebaseConfig = {
  apiKey: "...",
  authDomain: "...",
  projectId: "...",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "...",
  measurementId: "..."
};
```

8. Abra o arquivo `lib/firebase_options.dart` no repositorio.
9. Atualize os valores de `apiKey`, `authDomain`, `projectId`, `storageBucket`, `messagingSenderId`, `appId` e `measurementId` com os valores copiados.
10. Repita nos arquivos de ambiente que o app usa:
    - `lib/firebase_options_prod.dart` (se for producao).

---

### 12) Registrar o app Android no Firebase

> **Firebase Console** → console.firebase.google.com → Configuracoes do projeto > Seus aplicativos

1. Ainda em Configuracoes do projeto > Seus aplicativos.
2. Clique no icone Android.
3. Nome do pacote Android: `br.com.casadacrianca.educastock` (confirme em `android/app/build.gradle.kts`).
4. Apelido: `EducaStock Android`.
5. Clique em Registrar app.
6. Clique em Baixar google-services.json.
7. Substitua o arquivo existente em `android/app/google-services.json`.

---

### 13) Registrar o app iOS no Firebase (se aplicavel)

> **Firebase Console** → console.firebase.google.com → Configuracoes do projeto > Seus aplicativos

1. Clique no icone Apple.
2. Bundle ID (ID do pacote Apple): `br.org.casadacrianca.educastock`.
3. Formato esperado do Bundle ID: texto em dominio reverso (ex.: `br.org.casadacrianca.educastock`).
4. Nao use caminho de arquivo (ex.: `ios/Runner.xcodeproj`) nesse campo.
5. Apelido: `EducaStock iOS`.
6. Clique em Registrar app.
7. Baixe `GoogleService-Info.plist`.
8. Substitua o arquivo em `ios/Runner/GoogleService-Info.plist`.

---

## PARTE 4: Deploy do Frontend no Cloud Run

> Os passos 14 e 15 sao feitos no **Google Cloud Console** (console.cloud.google.com).
> O passo 16 volta ao **Firebase Console** (console.firebase.google.com).

---

### 14) O Dockerfile ja esta pronto

O arquivo `Dockerfile` na raiz do projeto faz:

1. Compila o Flutter Web em modo release.
2. Copia o build para o nginx.
3. Configura rotas SPA (necessario para Flutter Web com go_router).
4. Expoe na porta 8080 (porta padrao do Cloud Run).

Voce nao precisa alterar nada no Dockerfile.

---

### 15) Conectar GitHub ao Cloud Run e criar o servico

> **Google Cloud Console** → console.cloud.google.com → Cloud Run

1. Acesse console.cloud.google.com.
2. No menu lateral, clique em Cloud Run.
3. Clique em Criar servico.
4. Selecione Repositorio de codigo-fonte (nao imagem pronta).
5. Clique em Configurar deploy continuo com o Cloud Build.
6. Clique em Autenticar e autorize o Google Cloud no GitHub.
7. Selecione o repositorio: `Marco-Bubola/educastock`.
8. Selecione a branch: `main`.

Configuracao do build:

9. Branch: `^main$`
10. Tipo de build: **Dockerfile**.
11. Localizacao do Dockerfile: `Dockerfile`.
12. Diretorio de contexto de build: `educastock` (pasta dentro do repositorio onde esta o Dockerfile).

Configuracao do servico:

13. Nome: `educastock-web`.
14. Regiao: `southamerica-east1`.
15. Porta do container: `8080`.
16. Autenticacao: Permitir invocacoes nao autenticadas (o app e publico).
17. Min instances: `0`.
18. Max instances: `10`.
19. Memoria: `512Mi`.
20. CPU: `1`.
21. Timeout: `30s`.

20. Clique em Criar.
21. Aguarde o build e deploy (pode levar alguns minutos na primeira vez).
22. Copie a URL gerada (formato: `https://educastock-web-xxxx-uc.a.run.app`).

---

### 16) Adicionar URL do Cloud Run no Firebase Auth

> **Firebase Console** → console.firebase.google.com → Authentication > Configuracoes > Dominios autorizados

Apos ter a URL do Cloud Run:

1. Abra o Firebase Console > Authentication > Configuracoes.
2. Em Dominios autorizados, clique em Adicionar dominio.
3. Cole a URL do Cloud Run sem `https://` (ex.: `educastock-web-xxxx-uc.a.run.app`).
4. Salve.

Sem isso, o login pelo navegador sera bloqueado pelo Firebase.

---

## PARTE 5: Deploy do Backend (Functions)

> O passo 17 e feito no **terminal** do computador (nao em nenhum console web).
> O passo 18 e feito no **Firebase Console** (console.firebase.google.com).

---

### 17) Publicar as Functions no Firebase

As Functions precisam ser publicadas via terminal uma primeira vez ou via CI/CD.

Para publicar pelo terminal (unica vez para configurar):

```
cd educastock/functions
npm install
npm run build
cd ..
firebase deploy --only functions --project SEU_PROJECT_ID
```

Substitua `SEU_PROJECT_ID` pelo ID do projeto criado.

Apos o primeiro deploy:

1. Abra Firebase Console > Functions.
2. Confirme que as 4 funcoes aparecem como Ativas.
3. Verifique os logs iniciais para garantir que nao ha erro de configuracao.

---

### 18) Verificar regras publicadas

> **Firebase Console** → console.firebase.google.com → Firestore > Regras / Storage > Regras

1. Firestore > Regras: confirmar que as regras do repositorio estao publicadas.
2. Storage > Regras: idem.
3. Se nao estiverem, copie o conteudo dos arquivos `firestore.rules` e `storage.rules` e publique pelo console.

---

## PARTE 6: Validacao completa

---

### 19) Checklist de validacao pos-configuracao

Firebase:

1. Projeto criado e vinculado ao Google Cloud.
2. Billing ativo (plano Blaze).
3. Authentication ativo com provedores corretos.
4. Firestore criado em `southamerica-east1`.
5. Regras do Firestore publicadas.
6. Storage criado em `southamerica-east1`.
7. Regras do Storage publicadas.
8. Functions publicadas e ativas (4 funcoes).
9. App Web registrado com firebaseConfig atualizado em `firebase_options.dart`.
10. App Android registrado e `google-services.json` atualizado.

Cloud Run:

11. Servico `educastock-web` criado e ativo.
12. URL do Cloud Run adicionada nos dominios autorizados do Firebase Auth.
13. App abre no navegador sem erro.
14. Login funciona corretamente.
15. Dados carregam do Firestore.

---

## PARTE 7: Configuracoes extras

---

### 20) Dominio customizado (opcional)

> **Google Cloud Console** → console.cloud.google.com → Cloud Run > educastock-web
> Depois voltar ao **Firebase Console** para adicionar o novo dominio nos dominios autorizados.

No Cloud Run:

1. Abra o servico `educastock-web`.
2. Clique em Gerenciar dominios personalizados.
3. Adicione seu dominio.
4. Configure os registros DNS conforme instrucoes exibidas.
5. Aguarde emissao do certificado SSL (pode levar horas).
6. Adicione o novo dominio nos dominios autorizados do Firebase Auth.

---

### 21) Monitoramento basico

**Google Cloud Console** (console.cloud.google.com):
- Cloud Run > Metricas: requisicoes, latencia, erros do frontend.
- Faturamento > Relatorios: acompanhar custo total.

**Firebase Console** (console.firebase.google.com):
- Functions > Logs: execucoes e erros do backend.
- Authentication > Usuarios: monitorar acessos.

---

### 22) Erros comuns e solucao rapida

**Legenda:** [FCons] = Firebase Console | [GCons] = Google Cloud Console | [Terminal] = linha de comando

1. **[FCons]** Login bloqueado com erro de dominio.
   - [FCons] Authentication > Configuracoes > Dominios autorizados: adicionar URL do Cloud Run.
2. **[App]** App abre mas nao carrega dados.
   - Verificar se `firebase_options.dart` tem os valores do projeto correto (projectId, apiKey, etc.).
3. **[GCons]** Build falha no Cloud Build.
   - Cloud Run > servico > Triggers: verificar se o diretorio de contexto aponta para `educastock/`.
4. **[GCons]** Pagina em branco apos deploy.
   - Cloud Run > Logs: verificar erro do container. O nginx ja esta configurado para SPA.
5. **[FCons]** Functions nao aparecem no console.
   - Verificar se o plano Blaze esta ativo e se o deploy foi executado no terminal.
6. **[GCons]** Agendamento nao executa.
   - Google Cloud Console > Cloud Scheduler: verificar se os jobs foram criados e estao ativos.

---

Com este guia, o EducaStock fica totalmente configurado em uma nova conta Google:
- Firebase do zero (banco, auth, storage, functions, FCM).
- Frontend no Cloud Run com deploy automatico pelo GitHub.
- Backend integramente no Firebase sem servidor para gerenciar.
