# Roteiro do vídeo de 2 minutos — EducaStock

Tempo de fala: cerca de 2 minutos (aprox. 290 palavras, ritmo calmo). Entre colchetes, o que mostrar na tela.
Se alguém mais for gravar junto, divida os blocos por pessoa.

---

## 0:00 – 0:15 · Abertura
[Tela: logo e tela de login do EducaStock]

"Olá! Nós somos o grupo do EducaStock, aluno da Fatec Itapira, no curso de Desenvolvimento de Software Multiplataforma. Neste vídeo vamos mostrar o que é o projeto e o que melhoramos nesta nova versão."

## 0:15 – 0:45 · O problema e a solução
[Tela: dashboard do administrador]

"O EducaStock foi criado para a ONG Casa da Criança. Lá, o controle de doações era feito em planilhas e papel. O resultado: produtos vencendo sem uso e falta de itens básicos para as crianças.

Nosso aplicativo substitui isso por um sistema único, que funciona no celular e na web, a partir de uma só base de código em Flutter, com Firebase no servidor."

## 0:45 – 1:15 · O que o sistema faz
[Tela: scanner de código de barras, depois alertas e o semáforo de risco]

"O voluntário registra a doação lendo o código de barras pela câmera. O sistema aplica a regra FEFO, que sugere sair primeiro o lote com a validade mais próxima.

Ele avisa quando um produto está perto de vencer ou quando o estoque chega ao mínimo, e um módulo de inteligência artificial classifica o risco de cada lote em verde, amarelo ou vermelho. Tudo isso com controle de acesso por perfil e relatórios em PDF e Excel."

## 1:15 – 1:50 · O que há de novo nesta versão
[Tela: Portal do Doador — início, necessidades, formulário de doação, acompanhamento]

"Nesta versão, a grande novidade é o Portal do Doador. Agora quem quer ajudar se cadastra sozinho, vê as necessidades mais urgentes da ONG, faz a doação em quatro passos e acompanha o status até a entrega. Na tela inicial, o card 'Seu impacto' mostra o quanto cada doador já contribuiu.

Também reforçamos a segurança, com regras do banco por tipo de usuário, migramos tudo para um novo projeto Firebase, conectando web, Android e iOS, e atualizamos o código para as versões mais recentes do Flutter."

## 1:50 – 2:00 · Encerramento
[Tela: logo e link do repositório no GitHub]

"O EducaStock une tecnologia e solidariedade para que nenhuma doação se perca. O código está no nosso GitHub. Obrigado!"

---

## Dicas de gravação
* Grave a tela em 1080p; use dados de demonstração (rode `node scripts/seed_database.mjs`) para o app não aparecer vazio.
* Feche abas e notificações; não mostre chaves, senhas nem o console do Firebase com credenciais.
* Se passar de 2 minutos, corte a frase sobre o Flutter no bloco 1:15 – 1:50.
* Mostre o link do GitHub só no final: https://github.com/caua-lima/educastock-main
