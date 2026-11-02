# Roteiro do vídeo (câmera, ~2 minutos)

Texto corrido para falar olhando para a câmera, sem abertura nem despedida. Fale com calma.

O EducaStock é um aplicativo de controle de estoque criado para a ONG Casa da Criança, que controlava as doações em planilhas e papel. Por isso, produtos venciam sem uso e faltavam itens básicos para as crianças. Agora, o voluntário registra cada doação lendo o código de barras com a câmera do celular, o sistema aplica a regra FEFO, em que sai primeiro o lote que vence primeiro, e a inteligência artificial classifica o risco de cada lote em verde, amarelo ou vermelho. Tudo funciona em Android, iOS e na web, com uma única base de código em Flutter e o Firebase na nuvem.

Nesta nova versão, a principal novidade é o Portal do Doador. Quem quer ajudar se cadastra sozinho, vê as necessidades mais urgentes da ONG, faz a doação em quatro passos e acompanha o andamento até o fim. Na tela inicial, o card "Seu impacto" mostra o resultado da sua contribuição.

E estamos implementando uma série de melhorias. Os alertas de validade passam a ser gerados automaticamente e chegam como notificação no celular da equipe, mesmo com o aplicativo fechado. A leitura da data de validade pela câmera fica mais precisa, reconhecendo vários formatos de embalagem. O aplicativo também vai funcionar sem internet: as operações ficam guardadas no aparelho e são sincronizadas sozinhas quando a conexão volta. E estamos criando relatórios completos de movimentações por período, com exportação, e filtros avançados na auditoria.

Também reforçamos a segurança, com regras de acesso por tipo de usuário, e migramos para um novo ambiente Firebase, conectado à web, ao Android e ao iOS.

No fim, o objetivo é simples: que nenhuma doação se perca e que cada criança receba o que precisa.
