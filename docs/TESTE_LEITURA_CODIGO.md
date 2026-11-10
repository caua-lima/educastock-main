# Como testar a leitura de código de barras e QR Code

Guia rápido para testar o **Escanear** do EducaStock no PC (navegador), no Android e no iPhone.
Só **administrador** e **estoquista** veem o Escanear.

## Códigos para testar

| Código | Onde está | O que deve acontecer |
|---|---|---|
| `7891001425427` (Achocolatado) | `docs/codigos_teste/ean_7891001425427_achocolatado.png` | Se o produto já está cadastrado: abre o produto com **Adicionar Novo Lote**. |
| `7891000100103` | `docs/codigos_teste/ean_7891000100103_desconhecido.png` | Se não está cadastrado: o app procura o nome na internet (Open Food Facts e outras bases) e oferece **Confirmar e cadastrar produto** ou **Cadastrar manualmente**. |
| Qualquer produto da despensa | A embalagem | Igual aos casos acima. |
| QR Code do protocolo da doação (`DOA-AAAA-NNNNNN`) | Tela da doação no portal do doador (doação **aprovada** ou **pendente** com protocolo) | Abre a doação na fila da equipe, pronta para conferir e receber. |

Dica: abra a imagem PNG no celular (ou imprima) e aponte a câmera do PC para ela, ou o contrário.

## 1. No PC (navegador)

1. Abra https://educastock-69936.web.app no **Chrome** ou no **Edge** e entre com uma conta de administrador ou estoquista.
2. Clique em **Escanear** (menu lateral ou atalho no painel).
3. O navegador pergunta se pode usar a câmera: clique em **Permitir**.
4. Mostre o código para a câmera, a uns 15–20 cm, com boa luz. Use os botões de **zoom** se o código estiver pequeno.
5. Quando o código for lido, aparece a confirmação com o número: toque em **Continuar com este código** (ou **Ler outro código**).

Sem câmera (ou com a câmera bloqueada), há duas outras formas, no rodapé do Escanear:

- **Ler o código de uma imagem** (ícone de galeria): escolha um PNG/JPG com o código, por exemplo um dos arquivos de `docs/codigos_teste/`.
- **Digitar o código** (ícone de teclado): digite os números que aparecem embaixo das barras. O app confere o último dígito e avisa se houver erro de digitação.

Se a câmera não abrir:

- Clique no cadeado da barra de endereço e libere **Câmera** para o site; depois recarregue a página.
- Feche outros programas que estejam usando a câmera (Teams, Meet, Zoom).
- A câmera só funciona em endereço **https** (o site publicado já é).

## 2. No Android

1. Instale o app (APK gerado com `flutter build apk --release`, ou rode com `flutter run` com o celular ligado no USB e a depuração USB ativa).
2. Entre com administrador ou estoquista e abra **Escanear**.
3. Na primeira vez, o Android pede a permissão da câmera: toque em **Permitir**.
4. Aponte para o código. Também dá para usar **Ler o código de uma imagem** (escolhe uma foto da galeria) e **Digitar o código**.

Se negou a permissão sem querer: Configurações do Android › Apps › EducaStock › Permissões › Câmera › Permitir.

Observação: o login com **Google** no Android só funciona depois de cadastrar a impressão digital **SHA-1** do app no Firebase (Configurações do projeto › app Android › Adicionar impressão digital) e baixar o `google-services.json` novo. Login com e-mail e senha funciona sem isso.

## 3. No iPhone

Precisa de um **Mac com Xcode** (não dá para gerar o app de iPhone no Windows).

1. No Mac: `flutter pub get`, depois `cd ios && pod install`, depois `flutter run` com o iPhone conectado.
2. Na primeira vez, o iOS mostra o pedido de câmera com o texto do app: toque em **Permitir**.
3. Teste igual ao Android.

Se negou a permissão: Ajustes › EducaStock › Câmera.

O projeto iOS já está pronto para isso: textos de permissão de câmera e de fotos, iOS mínimo 15.5 (exigido pelo leitor ML Kit) e retorno do login com Google configurado.

## 4. QR Code da doação (entrega)

1. Como **doador**: faça uma doação pelo portal.
2. Como **equipe**: aprove a doação em **Doações** (a aprovação gera o protocolo).
3. Como **doador**: abra a doação. Aparece **Mostre este QR Code na entrega**, com o QR e o protocolo.
4. Como **equipe**: no **Escanear**, leia o QR da tela do doador. O app abre a doação direto para **conferir e receber**.

Se a câmera não ler, digite o protocolo (ex.: `DOA-2026-000104`) em **Digitar o código**.

## 5. Teste local, sem mexer nos dados reais (para quem desenvolve)

```bash
firebase emulators:start --only auth,firestore,storage,functions --project educastock-69936
```

```bash
flutter run -d chrome --dart-define=USE_EMULATORS=true
```

Com `USE_EMULATORS=true` o app só fala com os emuladores locais e, na web, o login não fica salvo entre recargas (é preciso entrar de novo). Se ele não conseguir ligar o login ao emulador (por exemplo, por causa de uma sessão antiga salva no navegador), ele **para com um erro** em vez de usar o servidor real; recarregue a página.

Para simular uma câmera no Chrome com um vídeo de código de barras:

```bash
chrome --use-fake-ui-for-media-stream --use-fake-device-for-media-stream --use-file-for-fake-video-capture=camera.y4m
```
