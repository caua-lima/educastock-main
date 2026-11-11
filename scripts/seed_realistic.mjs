/**
 * Dados de DEMONSTRAÇÃO realistas para o EducaStock (Casa da Criança, Itapira/SP).
 *
 * Simula 5 meses de operação de uma entidade que atende cerca de 100 crianças de famílias
 * de baixa renda: doações e compras entram, a cozinha e a despensa consomem por FEFO, o que
 * vence é descartado, e tudo deixa rastro (lotes, movimentações, auditoria, alertas, doações
 * com linha do tempo, previsões e classificações de risco). Lotes, movimentações e doações
 * saem da MESMA simulação, então os números fecham entre si.
 *
 * Tudo é FICTÍCIO: pessoas, empresas, telefones e quantidades. Só a instituição, a cidade e o
 * endereço da sede vêm de reportagem pública (Itapira News, 2016); confira antes de divulgar.
 *
 * Uso (a chave da conta de serviço vem de variável de ambiente, nunca do repositório):
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\caminho\chave.json"
 *   node scripts/seed_realistic.mjs            # só mostra o que faria (não grava nada)
 *   node scripts/seed_realistic.mjs --apply    # APAGA os dados de demonstração antigos e grava os novos
 *
 * Preserva: contas de login (Auth), `users` das contas reais, `donors` das contas reais e as
 * configurações. Recria: produtos, lotes, movimentações, auditoria, alertas, aprovações, receitas,
 * localizações, doações (com eventos), necessidades, pontos, previsões e riscos.
 */
import { createRequire } from 'node:module';
const require = createRequire(new URL('../functions/package.json', import.meta.url));
const { initializeApp, applicationDefault, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const APPLY = process.argv.includes('--apply');
if (!getApps().length) initializeApp({ credential: applicationDefault(), projectId: 'educastock-69936' });
const db = getFirestore();

// ─── Aleatório determinístico (mesma semente = mesmos dados) ─────────────────
let _s = 20261103;
const rnd = () => {
  _s |= 0; _s = (_s + 0x6d2b79f5) | 0;
  let t = Math.imul(_s ^ (_s >>> 15), 1 | _s);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const between = (a, b) => a + rnd() * (b - a);
const int = (a, b) => Math.round(between(a, b));
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
const chance = (p) => rnd() < p;

// ─── Datas ───────────────────────────────────────────────────────────────────
const NOW = new Date();
const TODAY = new Date(NOW.getFullYear(), NOW.getMonth(), NOW.getDate());
const HORIZON = 150; // dias simulados
const at = (daysAgo, h = 9, m = 0) => {
  const d = new Date(TODAY.getTime() - daysAgo * 86_400_000);
  d.setHours(h, m, 0, 0);
  return d;
};
const iso = (d) => d.toISOString();
const ts = (d) => Timestamp.fromDate(d);
const weekday = (daysAgo) => at(daysAgo).getDay(); // 0 dom ... 6 sáb
const isWeekday = (daysAgo) => { const w = weekday(daysAgo); return w >= 1 && w <= 5; };
const endOfDay = (d) => { const x = new Date(d); x.setHours(23, 59, 0, 0); return x; };
const addDays = (d, n) => new Date(d.getTime() + n * 86_400_000);
const jitterTime = (daysAgo, h0, h1) => at(daysAgo, int(h0, h1 - 1), int(0, 59));

// ─── Equipe (fictícia) ───────────────────────────────────────────────────────
const U = {
  admin:  { id: 'uid-admin-marta',     name: 'Marta Helena Ribeiro',        email: 'marta.ribeiro@educastock.test',  role: 'admin' },
  est1:   { id: 'uid-estoquista-joao', name: 'João Pedro Oliveira',         email: 'joao.oliveira@educastock.test',  role: 'estoquista' },
  est2:   { id: 'uid-estoquista-bruna', name: 'Bruna Tavares de Souza',     email: 'bruna.souza@educastock.test',    role: 'estoquista' },
  cook:   { id: 'uid-voluntaria-neusa', name: 'Neusa Aparecida Ferreira',   email: 'neusa.ferreira@educastock.test', role: 'voluntario' },
  vol:    { id: 'uid-voluntaria-ana',  name: 'Ana Paula Santos',            email: 'ana.santos@educastock.test',     role: 'voluntario' },
  viewer: { id: 'uid-consulta-carlos', name: 'Carlos Henrique Lima',        email: 'carlos.lima@educastock.test',    role: 'consulta' },
};
const STAFF = Object.values(U);

// ─── Locais de armazenamento ─────────────────────────────────────────────────
const LOC = {
  seca:   (s, sh) => `Despensa Seca • Seção ${s} • Prateleira ${sh}`,
  fria:   (s, sh) => `Câmara Fria • Seção ${s} • Prateleira ${sh}`,
  limp:   (s, sh) => `Almoxarifado de Limpeza • Seção ${s} • Prateleira ${sh}`,
  esc:    (s, sh) => `Sala de Material Escolar • Seção ${s} • Prateleira ${sh}`,
  bazar:  (s, sh) => `Bazar e Roupas • Seção ${s} • Prateleira ${sh}`,
};
const LOCATIONS = [
  ['loc-seca-a1', 'Despensa Seca', 'A', '1', 4, 3, 8], ['loc-seca-a2', 'Despensa Seca', 'A', '2', 4, 3, 8],
  ['loc-seca-b1', 'Despensa Seca', 'B', '1', 4, 3, 8], ['loc-seca-b2', 'Despensa Seca', 'B', '2', 4, 3, 8],
  ['loc-fria-a1', 'Câmara Fria', 'A', '1', 3, 3, 6], ['loc-fria-a2', 'Câmara Fria', 'A', '2', 3, 3, 6],
  ['loc-limp-a1', 'Almoxarifado de Limpeza', 'A', '1', 3, 3, 8], ['loc-limp-a2', 'Almoxarifado de Limpeza', 'A', '2', 3, 3, 8],
  ['loc-esc-a1', 'Sala de Material Escolar', 'A', '1', 3, 3, 8], ['loc-bazar-a1', 'Bazar e Roupas', 'A', '1', 3, 3, 10],
].map(([id, room, section, shelf, shelves, levels, perLevel]) => ({
  id, locationName: room, section, shelf, level: '1', room, shelvesCount: shelves, levelsCount: levels,
  productsPerLevel: perLevel, capacity: levels * perLevel, isActive: true, createdAt: iso(at(HORIZON + 20, 10)),
  normalizedKey: `${section.toLowerCase()}|${shelf}|1`, label: `${room} • Seção ${section} • Prateleira ${shelf}`,
}));

// ─── Produtos ────────────────────────────────────────────────────────────────
// [slug, nome, marca, categoria, unidade, perecível, uso/semana, validade(dias) mín-máx,
//  intervalo entre entradas mín-máx, qtd por entrada mín-máx, preço, origens (doação/compra/parceiro), local, atividade]
const A = 'alimento', B = 'bebida', L = 'limpeza', H = 'higienePessoal', E = 'escolar', R = 'roupas';
const PRODUCTS_RAW = [
  ['arroz',      'Arroz agulha tipo 1 · 5 kg',      'Camil',        A, 'un', true, 8,  [300, 420], [12, 18], [30, 60],  27.9, [.7, .25, .05], LOC.seca('A', 1), 'Almoço'],
  ['feijao',     'Feijão carioca · 1 kg',            'Kicaldo',      A, 'un', true, 26, [240, 300], [9, 14],  [50, 90],   8.5, [.65, .3, .05], LOC.seca('A', 1), 'Almoço'],
  ['feijaopreto','Feijão preto · 1 kg',              'Camil',        A, 'un', true, 4,  [240, 300], [20, 30], [20, 40],   9.2, [.6, .35, .05], LOC.seca('A', 1), 'Almoço'],
  ['espaguete',  'Macarrão espaguete · 500 g',       'Renata',       A, 'un', true, 14, [330, 420], [12, 18], [40, 70],   4.8, [.7, .25, .05], LOC.seca('A', 2), 'Almoço'],
  ['parafuso',   'Macarrão parafuso · 500 g',        'Adria',        A, 'un', true, 6,  [330, 420], [16, 24], [24, 48],   4.6, [.7, .25, .05], LOC.seca('A', 2), 'Almoço'],
  ['oleo',       'Óleo de soja · 900 mL',            'Liza',         A, 'un', true, 7,  [300, 360], [12, 20], [24, 48],   7.4, [.6, .35, .05], LOC.seca('A', 2), 'Almoço'],
  ['acucar',     'Açúcar refinado · 1 kg',           'União',        A, 'un', true, 9,  [540, 720], [14, 22], [30, 60],   4.9, [.7, .25, .05], LOC.seca('B', 1), 'Lanche da tarde'],
  ['sal',        'Sal refinado · 1 kg',              'Cisne',        A, 'un', true, 2,  [720, 900], [30, 45], [12, 24],   2.8, [.6, .35, .05], LOC.seca('B', 1), 'Almoço'],
  ['trigo',      'Farinha de trigo · 1 kg',          'Dona Benta',   A, 'un', true, 3,  [200, 260], [20, 30], [15, 30],   5.9, [.7, .25, .05], LOC.seca('B', 1), 'Lanche da tarde'],
  ['mandioca',   'Farinha de mandioca · 500 g',      'Yoki',         A, 'un', true, 2,  [180, 240], [24, 36], [10, 20],   6.4, [.7, .25, .05], LOC.seca('B', 1), 'Almoço'],
  ['fuba',       'Fubá mimoso · 500 g',              'Yoki',         A, 'un', true, 2,  [180, 240], [24, 36], [10, 20],   3.9, [.7, .25, .05], LOC.seca('B', 1), 'Lanche da tarde'],
  ['molho',      'Molho de tomate · sachê 340 g',    'Fugini',       A, 'un', true, 12, [240, 330], [14, 21], [36, 72],   2.7, [.6, .35, .05], LOC.seca('B', 2), 'Almoço'],
  ['extrato',    'Extrato de tomate · 340 g',        'Elefante',     A, 'un', true, 2,  [300, 420], [28, 40], [12, 24],   4.5, [.6, .35, .05], LOC.seca('B', 2), 'Almoço'],
  ['sardinha',   'Sardinha em óleo · lata 125 g',    'Gomes da Costa', A, 'un', true, 4, [600, 800], [24, 36], [24, 48],  5.4, [.7, .25, .05], LOC.seca('B', 2), 'Almoço'],
  ['milho',      'Milho verde · lata 200 g',         'Quero',        A, 'un', true, 5,  [600, 800], [20, 30], [24, 48],   3.6, [.7, .25, .05], LOC.seca('B', 2), 'Almoço'],
  ['ervilha',    'Ervilha · lata 200 g',             'Quero',        A, 'un', true, 4,  [600, 800], [24, 36], [24, 36],   3.7, [.7, .25, .05], LOC.seca('B', 2), 'Almoço'],
  ['leitepo',    'Leite em pó integral · 400 g',     'Itambé',       A, 'un', true, 6,  [180, 240], [14, 21], [24, 48],  17.9, [.55, .4, .05], LOC.seca('A', 1), 'Café da manhã'],
  ['achoco',     'Achocolatado em pó · 400 g',       'Nescau',       A, 'un', true, 5,  [300, 400], [14, 21], [20, 40],   9.8, [.7, .25, .05], LOC.seca('A', 2), 'Café da manhã'],
  ['maisena',    'Biscoito maisena · 400 g',         'Piraquê',      A, 'un', true, 12, [150, 210], [8, 12],  [36, 72],   5.2, [.65, .3, .05], LOC.seca('B', 1), 'Lanche da tarde'],
  ['cracker',    'Biscoito cream cracker · 400 g',   'Vitarella',    A, 'un', true, 8,  [150, 210], [10, 15], [24, 48],   4.9, [.65, .3, .05], LOC.seca('B', 1), 'Lanche da tarde'],
  ['aveia',      'Aveia em flocos · 170 g',          'Quaker',       A, 'un', true, 3,  [300, 400], [24, 36], [12, 24],   4.3, [.7, .25, .05], LOC.seca('A', 2), 'Café da manhã'],
  ['cafe',       'Café torrado e moído · 500 g',     'Pilão',        A, 'un', true, 3,  [240, 320], [20, 30], [12, 24],  19.9, [.6, .35, .05], LOC.seca('A', 2), 'Café da manhã'],
  ['margarina',  'Margarina cremosa · 500 g',        'Qualy',        A, 'un', true, 8,  [75, 110],  [10, 14], [20, 40],   8.7, [.5, .45, .05], LOC.fria('A', 1), 'Café da manhã'],
  ['ovos',       'Ovos brancos · dúzia',             'Granja Boa Vista', A, 'un', true, 10, [24, 34], [6, 9], [14, 28],   11.5, [.4, .55, .05], LOC.fria('A', 1), 'Almoço'],
  ['frango',     'Peito de frango congelado · 1 kg', 'Seara',        A, 'un', true, 14, [75, 110],  [9, 14],  [30, 60],  16.9, [.45, .5, .05], LOC.fria('A', 2), 'Almoço'],
  ['carne',      'Carne moída congelada · 1 kg',     'Friboi',       A, 'un', true, 8,  [75, 110],  [10, 16], [20, 40],  28.9, [.4, .55, .05], LOC.fria('A', 2), 'Almoço'],
  ['banana',     'Banana prata · kg',                'Hortifruti',   A, 'kg', true, 25, [5, 7],     [4, 5],   [18, 32],   6.5, [.35, .6, .05], LOC.fria('A', 1), 'Lanche da tarde'],
  ['maca',       'Maçã nacional · kg',               'Hortifruti',   A, 'kg', true, 12, [14, 20],   [7, 9],   [14, 26],   9.9, [.5, .45, .05], LOC.fria('A', 1), 'Lanche da tarde'],
  ['cenoura',    'Cenoura · kg',                     'Hortifruti',   A, 'kg', true, 10, [12, 16],   [7, 9],   [14, 24],   5.5, [.45, .5, .05], LOC.fria('A', 1), 'Almoço'],
  ['batata',     'Batata lavada · kg',               'Hortifruti',   A, 'kg', true, 14, [20, 30],   [9, 12],  [20, 36],   6.9, [.45, .5, .05], LOC.fria('A', 1), 'Almoço'],
  ['cebola',     'Cebola · kg',                      'Hortifruti',   A, 'kg', true, 6,  [25, 35],   [14, 18], [12, 20],   5.9, [.45, .5, .05], LOC.fria('A', 1), 'Almoço'],
  ['pao',        'Pão de forma · 500 g',             'Wickbold',     A, 'un', true, 18, [6, 9],     [6, 7],   [18, 30],    8.4, [.7, .25, .05], LOC.seca('A', 1), 'Café da manhã'],
  ['leiteuht',   'Leite UHT integral · 1 L',         'Italac',       B, 'un', true, 140, [100, 150], [5, 8],  [150, 280],   5.2, [.55, .4, .05], LOC.seca('A', 1), 'Café da manhã'],
  ['sucopo',     'Suco em pó sabor uva · 30 g',      'Tang',         B, 'un', true, 20, [300, 400], [14, 21], [40, 80],    1.4, [.7, .25, .05], LOC.seca('A', 2), 'Lanche da tarde'],
  ['detergente', 'Detergente líquido · 500 mL',      'Ypê',          L, 'un', false, 14, [700, 800], [10, 16], [24, 48],   2.9, [.6, .35, .05], LOC.limp('A', 1), 'Limpeza da cozinha'],
  ['agua',       'Água sanitária · 1 L',             'Qboa',         L, 'un', false, 6,  [180, 240], [18, 26], [12, 24],   4.6, [.55, .4, .05], LOC.limp('A', 1), 'Limpeza geral'],
  ['desinf',     'Desinfetante · 2 L',               'Pinho Sol',    L, 'un', false, 3,  [700, 800], [24, 36], [10, 20],   9.9, [.55, .4, .05], LOC.limp('A', 2), 'Limpeza geral'],
  ['sabaopo',    'Sabão em pó · 1 kg',               'Omo',          L, 'un', false, 5,  [700, 800], [14, 22], [16, 30],  14.9, [.55, .4, .05], LOC.limp('A', 2), 'Lavanderia'],
  ['esponja',    'Esponja de louça · pct 3 un',      'Scotch-Brite', L, 'un', false, 4,  [700, 800], [20, 30], [12, 24],   4.2, [.5, .45, .05], LOC.limp('A', 2), 'Limpeza da cozinha'],
  ['lixo',       'Saco de lixo 50 L · pct 10 un',    'Embalixo',     L, 'un', false, 4,  [700, 800], [18, 26], [12, 24],   6.5, [.5, .45, .05], LOC.limp('A', 2), 'Limpeza geral'],
  ['papel',      'Papel higiênico folha dupla · pct 12', 'Neve',     H, 'un', false, 6,  [700, 800], [12, 18], [20, 40],  17.9, [.6, .35, .05], LOC.limp('A', 1), 'Banheiros'],
  ['sabonete',   'Sabonete em barra · 90 g',         'Lux',          H, 'un', false, 20, [600, 780], [10, 16], [40, 90],   2.2, [.6, .35, .05], LOC.limp('A', 1), 'Higiene e banho'],
  ['dental',     'Creme dental · 90 g',              'Colgate',      H, 'un', false, 10, [500, 700], [14, 20], [30, 60],   3.9, [.65, .3, .05], LOC.limp('A', 1), 'Higiene e banho'],
  ['escova',     'Escova de dentes infantil',        'Condor',       H, 'un', false, 8,  [800, 900], [14, 20], [20, 40],   4.5, [.65, .3, .05], LOC.limp('A', 1), 'Higiene e banho'],
  ['shampoo',    'Shampoo infantil · 350 mL',        'Johnson’s Baby', H, 'un', false, 4, [600, 780], [20, 30], [12, 24], 14.9, [.6, .35, .05], LOC.limp('A', 1), 'Higiene e banho'],
  ['alcool',     'Álcool em gel · 500 mL',           'Start',        H, 'un', false, 3,  [500, 700], [24, 36], [10, 20],   9.9, [.55, .4, .05], LOC.limp('A', 2), 'Higiene geral'],
  ['caderno',    'Caderno brochura · 96 folhas',     'Tilibra',      E, 'un', false, 6,  null,       [10, 16], [30, 60],   9.9, [.7, .25, .05], LOC.esc('A', 1), 'Reforço escolar'],
  ['lapis',      'Lápis preto nº 2',                 'Faber-Castell', E, 'un', false, 20, null,      [12, 18], [60, 120],  1.2, [.7, .25, .05], LOC.esc('A', 1), 'Reforço escolar'],
  ['caneta',     'Caneta esferográfica azul',        'Bic',          E, 'un', false, 10, null,       [14, 20], [50, 100],  1.5, [.7, .25, .05], LOC.esc('A', 1), 'Reforço escolar'],
  ['borracha',   'Borracha branca',                  'Mercur',       E, 'un', false, 8,  null,       [14, 20], [40, 80],   1.0, [.7, .25, .05], LOC.esc('A', 1), 'Reforço escolar'],
  ['mochila',    'Mochila escolar infantil',         'Sestini',      E, 'un', false, 1,  null,       [30, 45], [10, 20],  79.9, [.8, .15, .05], LOC.esc('A', 1), 'Entrega de kits'],
  ['camiseta',   'Camiseta infantil · tamanhos 6 a 12', 'Doação',    R, 'un', false, 6,  null,       [10, 16], [24, 60],  19.9, [.9, .05, .05], LOC.bazar('A', 1), 'Bazar'],
  ['bermuda',    'Bermuda infantil · tamanhos 6 a 12', 'Doação',     R, 'un', false, 4,  null,       [12, 18], [16, 40],  24.9, [.9, .05, .05], LOC.bazar('A', 1), 'Bazar'],
  ['agasalho',   'Agasalho (moletom) infantil',      'Doação',       R, 'un', false, 1,  null,       [30, 45], [10, 30],  49.9, [.9, .05, .05], LOC.bazar('A', 1), 'Bazar'],
  ['meias',      'Meias infantis · par',             'Doação',       R, 'un', false, 8,  null,       [14, 20], [40, 90],   6.9, [.85, .1, .05], LOC.bazar('A', 1), 'Bazar'],
];

// EAN-13 válido (dígito verificador correto) com prefixo 789 (Brasil) e miolo fictício.
const ean13 = (n) => {
  const body = `789${String(100000000 + n * 7919).slice(0, 9)}`.slice(0, 12);
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(body[i]) * (i % 2 === 0 ? 1 : 3);
  return body + ((10 - (sum % 10)) % 10);
};

const MIN_STOCK_WEEKS = 1.5;
const PRODUCTS = PRODUCTS_RAW.map((r, i) => {
  let [slug, name, brand, category, unit, perishable, weekly, shelf, every, qty, price, origins, loc, activity] = r;
  // Entradas menos frequentes e maiores (exceto perecíveis de validade curta, que giram toda semana).
  if (!shelf || shelf[0] >= 100) {
    every = [Math.round(every[0] * 1.6), Math.round(every[1] * 1.6)];
    qty = [Math.round(qty[0] * 1.6), Math.round(qty[1] * 1.6)];
  }
  // Alimentos e itens do dia a dia: cerca de metade vem de doação; o resto, de compra e parceiros.
  if ([A, B, L, H].includes(category)) {
    const d = origins[0] * 0.55;
    origins = [d, (1 - d) * 0.62, (1 - d) * 0.38];
  }
  return {
    id: `prod-${slug}`, slug, name, brand, category, unit, isPerishable: perishable, weeklyUse: weekly, shelf, every, qty,
    price, origins, loc, activity, barcode: brand === 'Doação' || brand === 'Hortifruti' ? null : ean13(i + 1),
    minimumStock: Math.max(2, Math.round(weekly * MIN_STOCK_WEEKS)),
  };
});
const P = Object.fromEntries(PRODUCTS.map((p) => [p.slug, p]));

// Produtos que terminam com estoque baixo (geram necessidades críticas e altas no portal).
const LOW_FROM = { leiteuht: 30, arroz: 26, sabonete: 30, caderno: 36, oleo: 22 }; // dias atrás em que as entradas quase pararam
const RUNNING_LOW = new Set(Object.keys(LOW_FROM));
// Produtos que terminam com lote recém-vencido, ainda não descartado (alertas de VENCIDO).
const RECENTLY_EXPIRED = new Set(['margarina', 'pao']);

// ─── Doadores (fictícios) ────────────────────────────────────────────────────
const DONOR_DEFS = [
  { id: 'donor-boacompra', name: 'Supermercado Boa Compra Ltda', type: 'pj', city: 'Itapira', cats: [A, B, L, H], w: 5 },
  { id: 'donor-paodeouro', name: 'Padaria Pão de Ouro', type: 'pj', city: 'Itapira', cats: [A], only: ['pao', 'maisena', 'cracker', 'trigo', 'fuba', 'acucar'], w: 3 },
  { id: 'donor-hortivale', name: 'Distribuidora Vale Verde Hortifruti', type: 'pj', city: 'Mogi Guaçu', cats: [A], only: ['banana', 'maca', 'cenoura', 'batata', 'cebola'], w: 4 },
  { id: 'donor-menezes', name: 'João Ricardo Menezes', type: 'pf', city: 'Itapira', cats: [A, B], w: 4 },
  { id: 'donor-papelaria', name: 'Papelaria Ponto Certo', type: 'pj', city: 'Itapira', cats: [E], w: 3 },
  { id: 'donor-colegio', name: 'Colégio Novo Horizonte (campanha do quilo)', type: 'pj', city: 'Itapira', cats: [A, H], w: 3 },
  { id: 'donor-armarinho', name: 'Armarinho Estrela', type: 'pj', city: 'Itapira', cats: [R], w: 3 },
  { id: 'donor-clinica', name: 'Clínica Odontológica Sorriso', type: 'pj', city: 'Itapira', cats: [H], only: ['dental', 'escova'], w: 2 },
  { id: 'donor-bela', name: 'Associação de Moradores do Jardim Bela Vista', type: 'pj', city: 'Itapira', cats: [A, H, R], w: 2 },
  { id: 'donor-corrida', name: 'Grupo de Corrida Itapira Runners', type: 'pj', city: 'Itapira', cats: [A, B], w: 2 },
  { id: 'donor-transp', name: 'Transportadora Rota Sul', type: 'pj', city: 'Mogi Mirim', cats: [A, L], w: 2 },
  { id: 'donor-fernanda', name: 'Fernanda Alves de Camargo', type: 'pf', city: 'Itapira', cats: [A, H, R], w: 2 },
  { id: 'donor-paulo', name: 'Paulo Sérgio Martins', type: 'pf', city: 'Itapira', cats: [A, L], w: 2 },
  { id: 'donor-luciana', name: 'Luciana Prado Nogueira', type: 'pf', city: 'Jacutinga', cats: [E, R, H], w: 2 },
  { id: 'donor-roberto', name: 'Roberto Carlos Teixeira', type: 'pf', city: 'Itapira', cats: [A, B], w: 2 },
  { id: 'donor-patricia', name: 'Patrícia Gomes Moraes', type: 'pf', city: 'Itapira', cats: [A, L, H], w: 2 },
];
DONOR_DEFS.forEach((d, i) => { d.phone = `(19) 99000-${String(100 + i * 7).padStart(4, '0')}`; });

// ─── Simulação ───────────────────────────────────────────────────────────────
const batches = [];     // todos os lotes
const movements = [];   // todas as movimentações
const donationEntries = []; // entradas de origem "doacao" (viram doações recebidas)
let batchSeq = 0, movSeq = 0;
const live = Object.fromEntries(PRODUCTS.map((p) => [p.slug, []])); // lotes ativos por produto

const performerFor = (p, kind) => {
  if (kind === 'entrada') return pick([U.est1, U.est2]);
  if (['Café da manhã', 'Almoço', 'Lanche da tarde'].includes(p.activity)) return U.cook;
  return pick([U.est1, U.est2, U.vol]);
};

function newBatch(p, qty, entryDay, origin, extra = {}) {
  const shelfDays = p.shelf ? int(p.shelf[0], p.shelf[1]) : null;
  // Doações costumam chegar com parte da validade já consumida.
  const remaining = shelfDays ? Math.max(4, Math.round(shelfDays * (origin === 'doacao' ? between(0.45, 0.9) : between(0.75, 1))) ) : null;
  const entryDate = jitterTime(entryDay, 9, 12);
  const b = {
    id: `batch-${p.slug}-${String(++batchSeq).padStart(4, '0')}`,
    productId: p.id, productName: p.name, quantity: qty, initialQuantity: qty,
    expiryDate: remaining ? endOfDay(addDays(entryDate, remaining)) : null,
    noExpiry: !remaining, entryDate, origin, donor: null, supplier: null,
    unitPrice: origin === 'compra' ? Math.round(p.price * between(0.9, 1.08) * 100) / 100 : null,
    batchNumber: `L${int(100000, 999999)}`, imageUrl: null, shelfLocation: p.loc, notes: null,
    status: 'disponivel', createdBy: pick([U.est1, U.est2]).id, createdAt: entryDate, _p: p, ...extra,
  };
  batches.push(b);
  live[p.slug].push(b);
  return b;
}

function logMovement(b, type, qty, when, who, { reasonCode = null, reason = null, activity = null, before, after } = {}) {
  movements.push({
    id: `mov-${String(++movSeq).padStart(5, '0')}`,
    productId: b.productId, productName: b.productName, batchId: b.id, type, quantity: qty,
    reasonCode, reason, activity, performedBy: who.id, performedByName: who.name,
    performedAt: when, isPendingSync: false,
    auditBefore: before == null ? null : { quantity: before }, auditAfter: after == null ? null : { quantity: after },
  });
}

const fefoOrder = (a, b) => {
  if (a.noExpiry !== b.noExpiry) return a.noExpiry ? 1 : -1;
  return (a.expiryDate?.getTime() ?? 0) - (b.expiryDate?.getTime() ?? 0);
};

function consume(p, want, day, who, when, meta) {
  let left = want;
  const usable = live[p.slug].filter((b) => b.quantity > 0 && (b.noExpiry || b.expiryDate > when)).sort(fefoOrder);
  const used = [];
  for (const b of usable) {
    if (left <= 0) break;
    const take = Math.min(b.quantity, left);
    const before = b.quantity;
    b.quantity -= take; left -= take;
    if (b.quantity === 0) b.status = 'distribuido';
    logMovement(b, 'saida', take, when, who, { ...meta, before, after: b.quantity });
    used.push({ batch: b, qty: take });
  }
  return used;
}

// Receitas / cestas: saídas "para famílias" (reasonCode doacao) por receita.
const RECIPES = [
  { id: 'recipe-cesta-grande', name: 'Cesta básica · família grande', description: 'Cesta mensal para famílias com 4 ou mais pessoas', items: [['arroz', 2], ['feijao', 3], ['oleo', 1], ['espaguete', 2], ['acucar', 2], ['trigo', 1], ['sal', 1], ['sardinha', 2]] },
  { id: 'recipe-cesta-pequena', name: 'Cesta básica · família pequena', description: 'Cesta mensal para famílias com até 3 pessoas', items: [['arroz', 1], ['feijao', 2], ['oleo', 1], ['espaguete', 1], ['acucar', 1]] },
  { id: 'recipe-kit-higiene', name: 'Kit de higiene pessoal', description: 'Kit mensal por criança', items: [['sabonete', 2], ['dental', 1], ['escova', 1], ['shampoo', 1]] },
  { id: 'recipe-kit-escolar', name: 'Kit escolar', description: 'Kit para o ano letivo (6 a 12 anos)', items: [['caderno', 4], ['lapis', 6], ['caneta', 2], ['borracha', 2], ['mochila', 1]] },
  { id: 'recipe-lanche', name: 'Lanche da tarde (100 crianças)', description: 'Pão com margarina, leite e fruta', items: [['pao', 7], ['margarina', 1], ['leiteuht', 20], ['banana', 14]] },
];
const recipeRuns = [];

// Dias de saída por produto: muito uso = todos os dias úteis; pouco uso = 1 ou 2 dias por semana.
const useDays = (p) => (p.weeklyUse >= 10 ? [1, 2, 3, 4, 5] : p.weeklyUse >= 4 ? [1, 4] : [3]);

// Estado inicial (há HORIZON dias): um lote por produto, cobrindo ~3 semanas de uso.
for (const p of PRODUCTS) {
  const origin = chance(p.origins[0]) ? 'doacao' : 'compra';
  const b = newBatch(p, Math.max(6, Math.round(p.weeklyUse * 4)), HORIZON, origin);
  if (origin === 'doacao') donationEntries.push({ batch: b, p, day: HORIZON });
  logMovement(b, 'entrada', b.quantity, b.entryDate, pick([U.est1, U.est2]), { reasonCode: origin === 'doacao' ? 'doacao' : 'compra', reason: origin === 'doacao' ? 'Doação' : 'Compra', before: 0, after: b.quantity });
}
const nextEntry = Object.fromEntries(PRODUCTS.map((p) => [p.slug, HORIZON - int(p.every[0], p.every[1])]));
const lastEntryDay = Object.fromEntries(PRODUCTS.map((p) => [p.slug, HORIZON]));

for (let day = HORIZON - 1; day >= 0; day--) {
  const date = at(day);
  const wd = date.getDay();

  // 1) Entradas (seg a sáb de manhã): repõe até o estoque-alvo quando cai abaixo do ponto de pedido
  if (wd !== 0) {
    for (const p of PRODUCTS) {
      const shortLife = p.shelf && p.shelf[1] <= 40;
      const stockNow = live[p.slug].filter((b) => b.quantity > 0 && (b.noExpiry || b.expiryDate > date)).reduce((n, b) => n + b.quantity, 0);
      const forced = RECENTLY_EXPIRED.has(p.slug) && day === 9;
      if (!forced) {
        if (stockNow >= p.weeklyUse * (shortLife ? between(0.5, 0.8) : between(1.0, 1.7))) continue;
        if (lastEntryDay[p.slug] - day < (shortLife ? 3 : 6)) continue; // intervalo mínimo entre entradas
        // Produtos "acabando": as entradas quase pararam nos últimos dias (falta de doação e de verba).
        if (RUNNING_LOW.has(p.slug) && day < LOW_FROM[p.slug] && chance(0.97)) continue;
      }
      const r = rnd();
      const origin = r < p.origins[0] ? 'doacao' : r < p.origins[0] + p.origins[1] ? 'compra' : 'parceiro';
      // Doações chegam em dias de recebimento (terça, quinta e sábado); espera o próximo.
      if (origin === 'doacao' && ![2, 4, 6].includes(wd) && !forced) continue;
      let target = p.weeklyUse * (shortLife ? between(1.0, 1.3) : between(3.2, 5.0));
      if (p.shelf) target = Math.min(target, p.weeklyUse * ((p.shelf[0] * 0.55) / 7)); // não comprar mais do que dá para usar antes de vencer
      let qty = Math.max(4, Math.round(target - stockNow));
      if (RUNNING_LOW.has(p.slug) && day < LOW_FROM[p.slug] + 18) qty = Math.max(4, Math.round(qty * 0.3));
      const b = newBatch(p, qty, day, origin);
      if (forced) b.expiryDate = endOfDay(addDays(TODAY, -2)); // lote que venceu "anteontem" e ainda não foi descartado
      if (origin === 'compra') b.supplier = pick(['Atacadão Itapira', 'Mercado Central', 'Distribuidora Souza']);
      if (origin === 'parceiro') b.supplier = pick(['Banco de Alimentos de Campinas', 'Mesa Brasil SESC']);
      if (origin === 'doacao') donationEntries.push({ batch: b, p, day });
      const who = pick([U.est1, U.est2]);
      logMovement(b, 'entrada', qty, b.entryDate, who, {
        reasonCode: origin === 'doacao' ? 'doacao' : 'compra', reason: origin === 'doacao' ? 'Doação' : origin === 'compra' ? 'Compra' : 'Parceria', before: 0, after: qty,
      });
      lastEntryDay[p.slug] = day;
    }
  }

  // 2) Descartes por validade (dia útil seguinte ao vencimento; lotes muito recentes ficam para gerar alerta)
  if (isWeekday(day)) {
    for (const p of PRODUCTS) {
      for (const b of live[p.slug]) {
        if (b.quantity <= 0 || b.noExpiry) continue;
        const expiredDays = Math.floor((date - b.expiryDate) / 86_400_000);
        if (expiredDays >= 1 && !(RECENTLY_EXPIRED.has(p.slug) && day <= 5)) {
          const who = pick([U.est1, U.est2]);
          const before = b.quantity;
          logMovement(b, 'descarte', before, jitterTime(day, 8, 10), who, { reasonCode: 'validade', reason: 'Descarte por validade vencida', before, after: 0 });
          b.quantity = 0; b.status = 'descartado'; b.discardedAt = date;
        }
      }
    }
  }

  // 3) Consumo diário (cozinha e despensa)
  if (isWeekday(day)) {
    const kitchenWhen = at(day, 11, int(5, 40));
    const pantryWhen = at(day, 15, int(5, 50));
    for (const p of PRODUCTS) {
      if (!useDays(p).includes(wd)) continue;
      const perDay = p.weeklyUse / useDays(p).length;
      const want = Math.max(1, Math.round(perDay * between(0.75, 1.25)));
      const isKitchen = ['Café da manhã', 'Almoço', 'Lanche da tarde'].includes(p.activity);
      const who = isKitchen ? U.cook : pick([U.est1, U.est2, U.vol]);
      const when = isKitchen ? kitchenWhen : pantryWhen;
      const reasonCode = isKitchen ? 'uso' : p.category === E || p.category === R ? 'doacao' : 'uso';
      const reason = isKitchen ? 'Preparo de refeições' : p.category === E ? 'Entrega de material escolar' : p.category === R ? 'Entrega no bazar' : 'Uso na instituição';
      consume(p, want, day, who, when, { reasonCode, reason, activity: p.activity });
    }

    // Avarias ocasionais
    if (chance(0.12)) {
      const p = pick(PRODUCTS.filter((x) => x.category === A || x.category === B));
      const b = live[p.slug].filter((x) => x.quantity > 3).sort(fefoOrder)[0];
      if (b) {
        const q = int(1, 3); const before = b.quantity;
        b.quantity -= q;
        logMovement(b, 'saida', q, at(day, 14, int(0, 59)), U.cook, { reasonCode: 'avaria', reason: 'Embalagem danificada', activity: 'Armazenamento', before, after: b.quantity });
      }
    }

    // Cestas e kits: 1ª e 3ª sexta-feira do mês (cestas), kits escolares/higiene na 2ª semana
    const dom = date.getDate();
    if (wd === 5 && (dom <= 7 || (dom >= 15 && dom <= 21))) {
      const recipe = dom <= 7 ? RECIPES[0] : RECIPES[1];
      const mult = int(10, 16);
      const run = { id: `run-${String(recipeRuns.length + 1).padStart(3, '0')}`, recipe, mult, when: at(day, 16, int(0, 40)), who: U.est1, movements: [] };
      for (const [slug, q] of recipe.items) {
        for (const u of consume(P[slug], q * mult, day, run.who, run.when, { reasonCode: 'doacao', reason: `Receita: ${recipe.name}`, activity: 'Cestas básicas' })) {
          run.movements.push({ productId: P[slug].id, productName: P[slug].name, batchId: u.batch.id, consumed: u.qty });
        }
      }
      recipeRuns.push(run);
    }
    if (wd === 3 && dom >= 8 && dom <= 14 && chance(0.7)) {
      const recipe = pick([RECIPES[2], RECIPES[3]]);
      const mult = int(8, 14);
      const run = { id: `run-${String(recipeRuns.length + 1).padStart(3, '0')}`, recipe, mult, when: at(day, 15, int(0, 40)), who: U.est2, movements: [] };
      for (const [slug, q] of recipe.items) {
        for (const u of consume(P[slug], q * mult, day, run.who, run.when, { reasonCode: 'doacao', reason: `Receita: ${recipe.name}`, activity: 'Kits' })) {
          run.movements.push({ productId: P[slug].id, productName: P[slug].name, batchId: u.batch.id, consumed: u.qty });
        }
      }
      recipeRuns.push(run);
    }
  }
}

// Estado final dos lotes
for (const b of batches) {
  if (b.status === 'disponivel' && b.quantity <= 0) b.status = 'distribuido';
}
const available = batches.filter((b) => b.status === 'disponivel' && b.quantity > 0);
const stockOf = (slug) => available.filter((b) => b._p.slug === slug).reduce((s, b) => s + b.quantity, 0);
const daysOfStock = (p) => stockOf(p.slug) / Math.max(0.1, p.weeklyUse / 7);

// ─── Doações recebidas: agrupa as entradas "doacao" em doações por doador ────
function donorFor(p) {
  const pool = DONOR_DEFS.filter((d) => (d.only ? d.only.includes(p.slug) : d.cats.includes(p.category)));
  const bag = pool.flatMap((d) => Array(d.w).fill(d));
  return bag.length ? pick(bag) : pick(DONOR_DEFS);
}
const groups = new Map(); // dia|doador -> entradas
const activeByDay = new Map(); // doadores que já apareceram no dia (o mesmo doador costuma trazer vários itens)
for (const e of donationEntries) {
  const act = activeByDay.get(e.day) ?? [];
  const fits = (d) => (d.only ? d.only.includes(e.p.slug) : d.cats.includes(e.p.category));
  const reuse = act.filter(fits);
  const donor = reuse.length && chance(0.85) ? pick(reuse) : donorFor(e.p);
  if (!act.includes(donor)) act.push(donor);
  activeByDay.set(e.day, act);
  const key = `${e.day}|${donor.id}`;
  if (!groups.has(key)) groups.set(key, { day: e.day, donor, entries: [] });
  groups.get(key).entries.push(e);
}
const SECTOR_BY = (p) => {
  if (p.category === E) return 'Material Escolar';
  if (p.category === R) return 'Bazar Beneficente';
  if (p.category === L || p.category === H) return 'Higiene e Limpeza';
  if (['Café da manhã', 'Lanche da tarde'].includes(p.activity)) return 'Cozinha da Creche (Lanches)';
  return chance(0.25) ? 'Cestas Básicas para Famílias' : 'Refeitório (Almoço/Jantar)';
};
const sectorPhrase = (s) => ({
  'Cozinha da Creche (Lanches)': 'à Cozinha da Creche, para o preparo dos lanches',
  'Refeitório (Almoço/Jantar)': 'ao Refeitório, para as refeições do dia a dia',
  'Cestas Básicas para Famílias': 'às cestas básicas entregues às famílias atendidas',
  'Bazar Beneficente': 'ao Bazar Beneficente da instituição',
  'Higiene e Limpeza': 'ao uso em higiene e limpeza da instituição',
  'Material Escolar': 'ao material escolar das crianças atendidas',
}[s] ?? `a ${s}`);
const impactMessage = (donorName, items, sector) => {
  const first = donorName.trim().split(/\s+/)[0];
  const clean = items.map((i) => i.trim()).filter(Boolean);
  const joined = clean.length === 1 ? `o item "${clean[0]}"` : clean.length === 2 ? `os itens "${clean[0]}" e "${clean[1]}"` : `os itens "${clean[0]}", "${clean[1]}" e mais ${clean.length - 2}`;
  const plural = clean.length > 1;
  return `${first}, ${joined} que você doou ${plural ? 'foram' : 'foi'} destinado${plural ? 's' : ''} ${sectorPhrase(sector)}. Muito obrigado por ajudar a Casa da Criança a cuidar de quem mais precisa!`;
};

const donations = []; // doações recebidas (derivadas das entradas) + abertas/encerradas (abaixo)
for (const g of [...groups.values()].sort((a, b) => b.day - a.day)) {
  const received = at(g.day, 10, int(0, 40));
  const created = addDays(received, -int(1, 3));
  const approved = addDays(received, -int(0, 1) - 1 + 0.3);
  const partial = chance(0.07);
  const hasImpact = g.day > 4 ? chance(0.82) : false;
  const sector = SECTOR_BY(g.entries[0].p);
  const items = g.entries.map((e) => ({
    needId: null, category: e.p.category, description: e.p.name, quantity: e.batch.initialQuantity, unit: e.p.unit,
    expiryDate: e.batch.expiryDate, hasExpiry: !e.batch.noExpiry, condition: 'novo', subjectToReview: false,
  }));
  const don = {
    status: partial ? 'recebida_parcial' : 'recebida', donor: g.donor, items, created, approved, received,
    entries: g.entries, sector: hasImpact ? sector : null, window: { from: addDays(received, -0), to: addDays(received, 0) },
  };
  if (partial) {
    // chegou menos do que o prometido em um item
    const e0 = g.entries[0];
    const promised = Math.min(e0.batch.initialQuantity + int(2, 6), Math.round(e0.batch.initialQuantity * 1.2) + 2);
    items[0].quantity = promised;
    don.partialNote = 'Parte das caixas chegou amassada e foi devolvida ao doador.';
  }
  donations.push(don);
}

// ─── Necessidades (portal do doador) ─────────────────────────────────────────
const isFresh = (p) => p.shelf && p.shelf[1] <= 40; // hortifruti, pão, ovos, margarina e congelados giram toda semana
const needCandidates = [
  // itens de despensa, higiene, limpeza e escolar: os de menor cobertura primeiro
  ...PRODUCTS.filter((p) => !isFresh(p)).map((p) => ({ p, days: daysOfStock(p) })).filter((x) => x.days < 24).sort((a, b) => a.days - b.days).slice(0, 8),
  // no máximo dois frescos entram no painel (os mais urgentes)
  ...PRODUCTS.filter(isFresh).map((p) => ({ p, days: daysOfStock(p) })).filter((x) => x.days < 3).sort((a, b) => a.days - b.days).slice(0, 2),
];
const priorityOf = (days, fresh) => (days < (fresh ? 2 : 5) ? 'critica' : days < (fresh ? 3 : 12) ? 'alta' : 'normal');
const RANK = { critica: 1, alta: 2, normal: 3 };
const needs = needCandidates.map(({ p, days }) => {
  const target = Math.ceil(p.weeklyUse * 3); // meta: três semanas de cobertura
  const suggested = Math.max(10, target - stockOf(p.slug));
  const pr = priorityOf(days, isFresh(p));
  return {
    id: `need-${p.slug}`, source: 'auto', productId: p.id, categoryId: p.category, title: p.name, unit: p.unit,
    priority: pr, priorityRank: RANK[pr], suggestedQty: Math.round(suggested / 5) * 5 || 10, pledgedQty: 0, remainingQty: 0,
    minShelfLifeDays: p.isPerishable ? (p.shelf[1] > 200 ? 90 : p.shelf[1] > 60 ? 45 : 7) : 0,
    validUntil: null, isActive: true, note: null,
  };
});
needs.push({
  id: 'need-kit-escolar-2027', source: 'manual', productId: null, categoryId: E, title: 'Material escolar para o ano letivo de 2027', unit: 'un',
  priority: 'normal', priorityRank: 3, suggestedQty: 150, pledgedQty: 0, remainingQty: 0, minShelfLifeDays: 0,
  validUntil: new Date(TODAY.getFullYear() + 1, 1, 15), isActive: true,
  note: 'Cadernos, lápis, canetas e borrachas para a volta às aulas.',
});
needs.push({
  id: 'need-agasalhos-2027', source: 'manual', productId: null, categoryId: R, title: 'Agasalhos infantis (campanha de inverno)', unit: 'un',
  priority: 'normal', priorityRank: 3, suggestedQty: 80, pledgedQty: 0, remainingQty: 0, minShelfLifeDays: 0,
  validUntil: new Date(TODAY.getFullYear() + 1, 4, 31), isActive: true, note: 'Moletons e casacos tamanhos 6 a 12 anos.',
});

// ─── Doações em andamento e encerradas ───────────────────────────────────────
const openDonations = []; // pendente / aprovada / recusada / cancelada / expirada
function addOpen(status, donor, daysAgoCreated, lines, extra = {}) {
  openDonations.push({ status, donor, created: at(daysAgoCreated, int(8, 17), int(0, 59)), lines, ...extra });
}
const needBy = (slug) => needs.find((n) => n.id === `need-${slug}`);
const lineFor = (slug, qty, needSlug = slug) => {
  const p = P[slug];
  const n = needBy(needSlug);
  // A doação cobre parte da necessidade (nunca mais do que ela pede).
  if (n) qty = Math.min(qty, Math.max(6, Math.floor(n.suggestedQty * 0.7)));
  const remainingShelf = p.shelf ? int(Math.max(40, Math.round(p.shelf[0] * 0.5)), p.shelf[1]) : null;
  return {
    needId: n ? n.id : null, category: p.category, description: p.name, quantity: qty, unit: p.unit,
    expiryDate: remainingShelf ? endOfDay(addDays(TODAY, remainingShelf)) : null, hasExpiry: !!remainingShelf, condition: 'novo',
    subjectToReview: !!(n && remainingShelf && n.minShelfLifeDays > remainingShelf),
  };
};
const D = Object.fromEntries(DONOR_DEFS.map((d) => [d.id, d]));
addOpen('pendente', D['donor-boacompra'], 1, [lineFor('leiteuht', 120), lineFor('arroz', 40)]);
addOpen('pendente', D['donor-menezes'], 2, [lineFor('leiteuht', 60), lineFor('achoco', 24)]);
addOpen('pendente', D['donor-papelaria'], 1, [lineFor('caderno', 80), lineFor('lapis', 120)]);
addOpen('pendente', D['donor-fernanda'], 0, [lineFor('sabonete', 36), lineFor('dental', 24)]);
addOpen('pendente', D['donor-colegio'], 3, [lineFor('feijao', 80), lineFor('maisena', 48)]);
addOpen('aprovada', D['donor-hortivale'], 5, [lineFor('banana', 30), lineFor('maca', 20)], { approvalMessage: 'Podem entregar de segunda a sexta, das 8h às 16h, direto na cozinha.' });
addOpen('aprovada', D['donor-transp'], 4, [lineFor('detergente', 48), lineFor('agua', 18)], { approvalMessage: 'Entrega pela entrada lateral, falar com a Neusa ou com o João.' });
addOpen('aprovada', D['donor-paulo'], 6, [lineFor('oleo', 36)], { approvalMessage: 'Combinado para quinta-feira de manhã.' });
addOpen('recusada', D['donor-roberto'], 12, [lineFor('sucopo', 200)], { reason: 'No momento já temos estoque suficiente deste item. Obrigado por pensar na gente!' });
addOpen('recusada', D['donor-patricia'], 20, [lineFor('esponja', 100)], { reason: 'Validade informada abaixo do mínimo e quantidade acima da capacidade de armazenamento.' });
addOpen('cancelada', D['donor-luciana'], 9, [lineFor('lapis', 60)], { reason: 'Doador desistiu da entrega.' });
addOpen('cancelada', D['donor-corrida'], 15, [lineFor('feijao', 50)], { reason: 'Campanha adiada pela organização.' });
addOpen('expirada', D['donor-bela'], 28, [lineFor('arroz', 30)], { reason: 'O prazo de entrega terminou sem a doação chegar.' });

// Reserva de quantidade (RN-D05): pendente e aprovada reservam; encerradas não.
for (const od of openDonations.filter((d) => d.status === 'pendente' || d.status === 'aprovada')) {
  for (const l of od.lines) {
    const n = needs.find((x) => x.id === l.needId);
    if (n) n.pledgedQty += l.quantity;
  }
}
for (const n of needs) n.remainingQty = Math.max(0, n.suggestedQty - n.pledgedQty);

// ─── Protocolos (DOA-AAAA-NNNNNN) por ordem de criação ───────────────────────
const allDon = [
  ...donations.map((d) => ({ ref: d, created: d.created })),
  ...openDonations.map((d) => ({ ref: d, created: d.created })),
].sort((a, b) => a.created - b.created);
allDon.forEach((x, i) => { x.ref.protocol = `DOA-${TODAY.getFullYear()}-${String(i + 1).padStart(6, '0')}`; });
const protocolsIssued = allDon.length;

// Doação recebida ↔ lotes e movimentações
for (const d of donations) {
  for (const e of d.entries) {
    e.batch.donor = d.donor.name; e.batch.donorId = d.donor.id; e.batch.donationId = d.protocol;
    e.batch.notes = `Doação ${d.protocol}`;
  }
}
for (const m of movements) {
  const b = batches.find((x) => x.id === m.batchId); // ok: poucos milhares
  if (b && m.type === 'entrada' && b.donationId) m.reason = `Doação ${b.donationId}`;
}

// ─── Alertas ─────────────────────────────────────────────────────────────────
const alerts = [];
const CRIT = 7, WARN = 30;
for (const b of available) {
  if (b.noExpiry) continue;
  const days = Math.ceil((b.expiryDate - NOW) / 86_400_000);
  if (days > WARN) continue;
  const level = days <= CRIT ? 'critical' : 'warning';
  const message = days <= 0
    ? `Lote VENCIDO — descarte imediato: ${b.productName}`
    : `${level === 'critical' ? 'Crítico' : 'Atenção'}: "${b.productName}" vence em ${days} dia${days === 1 ? '' : 's'}`;
  alerts.push({
    id: `alert-${b.id}-${level}`, productId: b.productId, productName: b.productName, batchId: b.id, level, message,
    createdAt: ts(at(Math.max(0, Math.min(3, 30 - days)) , 7, int(0, 30))), resolved: false,
  });
}
// histórico de alertas resolvidos (lotes descartados)
batches.filter((b) => b.status === 'descartado' && b.discardedAt).slice(-8).forEach((b) => {
  alerts.push({
    id: `alert-${b.id}-critical-resolvido`, productId: b.productId, productName: b.productName, batchId: b.id, level: 'critical',
    message: `Crítico: "${b.productName}" vence em 5 dias`, createdAt: ts(addDays(b.expiryDate, -5)), resolved: true,
  });
});
alerts.push({
  id: 'alert-manual-geladeira', productId: 'manual', productName: 'Câmara fria', batchId: null, level: 'warning',
  message: 'A câmara fria está oscilando de temperatura. Pedir revisão técnica e conferir os congelados.', createdAt: ts(at(2, 8, 40)), resolved: false,
});
alerts.push({
  id: 'alert-manual-dedetizacao', productId: 'manual', productName: 'Despensa seca', batchId: null, level: 'info',
  message: 'Dedetização da despensa agendada para o próximo sábado. Retirar os produtos das prateleiras baixas na sexta.', createdAt: ts(at(4, 16, 10)), resolved: false,
});
for (const od of openDonations.filter((d) => d.status === 'pendente')) {
  alerts.push({
    id: `alert-doacao-${od.protocol}`, productId: 'donation', productName: od.protocol, batchId: null, donationId: od.protocol, level: 'info',
    message: `Nova intenção de doação ${od.protocol} de ${od.donor.name} (${od.lines.length} ${od.lines.length === 1 ? 'item' : 'itens'}).`, createdAt: ts(od.created), resolved: false,
  });
}

// ─── Aprovações de ajuste ────────────────────────────────────────────────────
const approvalBatches = available.filter((b) => b.quantity >= 30).slice(0, 4);
const adjustments = approvalBatches.map((b, i) => {
  const status = ['pending', 'pending', 'approved', 'rejected'][i];
  const qty = int(12, 22);
  const reasons = ['Contagem do inventário mostrou diferença na prateleira', 'Caixas molhadas por goteira no depósito', 'Produtos entregues a outra entidade parceira', 'Quebra durante a organização do estoque'];
  const created = at(int(1, 9), 15, int(0, 50));
  return {
    id: `approval-${String(i + 1).padStart(3, '0')}`, productId: b.productId, productName: b.productName, batchId: b.id, quantity: qty,
    requestedBy: i % 2 ? U.est2.id : U.vol.id, requestedByName: i % 2 ? U.est2.name : U.vol.name, reason: reasons[i], status,
    createdAt: iso(created),
    ...(status === 'pending' ? {} : { reviewedBy: U.admin.id, reviewedByName: U.admin.name, reviewedAt: iso(addDays(created, 1)) }),
  };
});

// ─── Auditoria ───────────────────────────────────────────────────────────────
const audit = [];
let auditSeq = 0;
const addAudit = (collection, documentId, action, before, after, who, when) => audit.push({
  id: `audit-${String(++auditSeq).padStart(5, '0')}`, collection, documentId, action, before, after,
  performedBy: who.id, performedByName: who.name, performedAt: iso(when),
});
STAFF.forEach((u, i) => addAudit('users', u.id, 'create', null, { role: u.role, isActive: true }, U.admin, at(HORIZON + 15 - i, 10)));
PRODUCTS.forEach((p, i) => addAudit('products', p.id, 'create', null, { name: p.name, category: p.category }, i % 2 ? U.est1 : U.est2, at(HORIZON + 10, 9, i)));
for (const m of movements) {
  if (m.type === 'saida' && m.reasonCode === 'uso') continue; // consumo diário não gera linha de auditoria (muito volume)
  if (m.type === 'entrada' || m.type === 'descarte' || m.reasonCode === 'avaria') {
    audit.push({
      id: `audit-${String(++auditSeq).padStart(5, '0')}`, collection: 'batches', documentId: m.batchId, action: m.type === 'saida' ? 'saida' : m.type,
      before: m.auditBefore, after: m.auditAfter, performedBy: m.performedBy, performedByName: m.performedByName, performedAt: iso(m.performedAt),
    });
  }
}
for (const a of adjustments) {
  addAudit('adjustment_approvals', a.id, a.status === 'pending' ? 'requested' : a.status, { status: 'pending' }, { status: a.status }, a.status === 'pending' ? { id: a.requestedBy, name: a.requestedByName } : U.admin, new Date(a.createdAt));
}
audit.sort((a, b) => a.performedAt.localeCompare(b.performedAt));
audit.forEach((a, i) => { a.id = `audit-${String(i + 1).padStart(5, '0')}`; });

// ─── Previsões (Prophet) e riscos (Random Forest) ────────────────────────────
const weeklySeries = (p, weeks) => {
  const out = Array(weeks).fill(0);
  for (const m of movements) {
    if (m.productId !== p.id || m.type !== 'saida' || m.reasonCode === 'avaria') continue;
    const w = Math.floor((TODAY - m.performedAt) / (7 * 86_400_000));
    if (w >= 0 && w < weeks) out[w] += m.quantity;
  }
  return out; // índice 0 = semana mais recente
};
const forecasts = PRODUCTS.map((p) => {
  const s = weeklySeries(p, 16);
  const recent = s.slice(0, 4).reduce((a, b) => a + b, 0) / 4;
  const prev = s.slice(4, 8).reduce((a, b) => a + b, 0) / 4 || recent;
  const trendPct = prev > 0 ? ((recent - prev) / prev) * 100 : 0;
  const weekly = Math.max(0.5, recent * 0.7 + (s.slice(0, 12).reduce((a, b) => a + b, 0) / 12) * 0.3);
  const stock = stockOf(p.slug);
  const monthly = weekly * 4.3;
  return {
    id: p.id, productId: p.id, productName: p.name, categoryId: p.category,
    forecastWeekly: Math.round(weekly * 10) / 10, forecastMonthly: Math.round(monthly * 10) / 10, currentStock: stock,
    suggestedReplenishment: Math.max(0, Math.ceil(monthly + p.minimumStock - stock)),
    ciLower: Math.round(weekly * 0.82 * 10) / 10, ciUpper: Math.round(weekly * 1.18 * 10) / 10,
    trend: trendPct > 7 ? 'increasing' : trendPct < -7 ? 'decreasing' : 'stable', trendPercent: Math.round(trendPct * 10) / 10,
    modelVersion: 'prophet-1.1.5', generatedAt: iso(at(0, 6, 30)), dataPoints: s.filter((x) => x > 0).length * 5 || 20, source: 'prophet',
  };
});
const risks = available.map((b) => {
  const days = b.noExpiry ? 9999 : Math.ceil((b.expiryDate - NOW) / 86_400_000);
  const ratio = b.quantity / Math.max(1, b.initialQuantity);
  const level = days <= 7 ? 'vermelho' : days <= 30 || (ratio < 0.2 && !b.noExpiry && days <= 90) ? 'amarelo' : 'verde';
  const main = 0.72 + rnd() * 0.24;
  const rest = (1 - main) * between(0.3, 0.7);
  const probabilities = level === 'verde' ? [main, rest, 1 - main - rest] : level === 'amarelo' ? [rest, main, 1 - main - rest] : [rest, 1 - main - rest, main];
  return { id: b.id, batchId: b.id, productName: b.productName, level, probabilities: probabilities.map((x) => Math.round(x * 1000) / 1000), source: 'random_forest', updatedAt: iso(at(0, 6, 35)) };
});

// ═════════════════════════════════════════════════════════════════════════════
// Resumo e gravação
// ═════════════════════════════════════════════════════════════════════════════
const counts = {
  produtos: PRODUCTS.length, lotes: batches.length, 'lotes disponíveis': available.length, movimentações: movements.length,
  auditoria: audit.length, alertas: alerts.length, aprovações: adjustments.length, receitas: RECIPES.length, 'execuções de receita': recipeRuns.length,
  localizações: LOCATIONS.length, doadores: DONOR_DEFS.length, 'doações recebidas': donations.length, 'doações em andamento/encerradas': openDonations.length,
  necessidades: needs.length, previsões: forecasts.length, riscos: risks.length,
};
const lowest = PRODUCTS.map((p) => ({ n: p.name, d: Math.round(daysOfStock(p)), s: stockOf(p.slug) })).sort((a, b) => a.d - b.d).slice(0, 8);
console.log(`\n${APPLY ? 'GRAVANDO' : 'SIMULAÇÃO (nada foi gravado; use --apply)'} — EducaStock / Casa da Criança (Itapira)\n`);
console.table(counts);
console.log('Estoque mais baixo (dias de cobertura):'); console.table(lowest);
console.log('Itens que deveriam estar baixos:'); console.table([...RUNNING_LOW].map((k) => ({ item: P[k].name, estoque: stockOf(k), dias: Math.round(daysOfStock(P[k])), ultimaEntrada: batches.filter((b) => b._p.slug === k).map((b) => Math.round((TODAY - b.entryDate) / 86400000)).sort((a, b) => a - b)[0] })));
console.log('Necessidades:'); console.table(needs.map((n) => ({ item: n.title, prioridade: n.priority, sugerido: n.suggestedQty, prometido: n.pledgedQty, restante: n.remainingQty })));
if (!APPLY) process.exit(0);

// ─── Gravação ────────────────────────────────────────────────────────────────
const CLEAR = ['products', 'batches', 'stock_movements', 'audit_logs', 'alerts', 'adjustment_approvals', 'recipes', 'recipe_runs', 'storage_locations',
  'donations', 'donation_needs', 'donation_points', 'consumption_forecasts', 'risk_classifications', 'user_notifications'];
for (const c of CLEAR) {
  await db.recursiveDelete(db.collection(c));
  console.log(`  limpo: ${c}`);
}
// Usuários da equipe fictícia anteriores e novos (as contas reais ficam intactas).
for (const id of ['uid-admin-maria', 'uid-estoquista-joao', 'uid-voluntario-ana', 'uid-consulta-carlos']) await db.collection('users').doc(id).delete();
for (const d of DONOR_DEFS) await db.collection('donors').doc(d.id).delete().catch(() => {});

const writer = db.bulkWriter();
writer.onWriteError((e) => { console.error('erro de escrita', e.documentRef.path, e.message); return e.failedAttempts < 3; });
const set = (col, id, data) => writer.set(db.collection(col).doc(id), data);
const sub = (path, data) => writer.set(db.doc(path), data);

for (const u of STAFF) set('users', u.id, { name: u.name, email: u.email, role: u.role, isActive: true, twoFactorEnabled: u.role === 'admin', createdAt: iso(at(HORIZON + 15)) });
for (const l of LOCATIONS) { const { id, ...d } = l; set('storage_locations', id, d); }
for (const p of PRODUCTS) {
  set('products', p.id, {
    name: p.name, brand: p.brand === 'Doação' || p.brand === 'Hortifruti' ? null : p.brand, category: p.category, unit: p.unit, barcode: p.barcode,
    imageUrl: null, description: null, isPerishable: p.isPerishable, minimumStock: p.minimumStock, createdAt: iso(at(HORIZON + 10, 9)), createdBy: U.est1.id, isActive: true,
  });
}
for (const b of batches) {
  set('batches', b.id, {
    productId: b.productId, productName: b.productName, quantity: b.quantity, initialQuantity: b.initialQuantity,
    expiryDate: b.expiryDate ? iso(b.expiryDate) : null, noExpiry: b.noExpiry, entryDate: iso(b.entryDate), origin: b.origin, donor: b.donor,
    supplier: b.supplier, unitPrice: b.unitPrice, batchNumber: b.batchNumber, imageUrl: null, shelfLocation: b.shelfLocation, notes: b.notes,
    status: b.status, createdBy: b.createdBy, createdAt: iso(b.createdAt),
    ...(b.donationId ? { donorId: b.donorId, donationProtocol: b.donationId } : {}),
  });
}
for (const m of movements) { const { id, performedAt, ...d } = m; set('stock_movements', id, { ...d, performedAt: iso(performedAt) }); }
for (const a of audit) { const { id, ...d } = a; set('audit_logs', id, d); }
for (const a of alerts) { const { id, ...d } = a; set('alerts', id, d); }
for (const a of adjustments) { const { id, ...d } = a; set('adjustment_approvals', id, d); }
for (const r of RECIPES) set('recipes', r.id, { name: r.name, description: r.description, isPredefined: true, isActive: true, createdAt: iso(at(HORIZON, 10)), createdBy: U.admin.id, items: r.items.map(([s, q]) => ({ productId: P[s].id, productName: P[s].name, quantity: q })) });
for (const r of recipeRuns) set('recipe_runs', r.id, { recipeId: r.recipe.id, recipeName: r.recipe.name, multiplier: r.mult, performedBy: r.who.id, performedByName: r.who.name, performedAt: iso(r.when), movements: r.movements });
for (const f of forecasts) { const { id, ...d } = f; set('consumption_forecasts', id, d); }
for (const r of risks) { const { id, ...d } = r; set('risk_classifications', id, d); }

// Portal do doador
const POINTS = [
  { id: 'ponto-sede', name: 'Sede da Casa da Criança', address: 'Rua Silvio Galizoni, 238 · Cubatão · Itapira/SP', hours: [1, 2, 3, 4, 5].map((weekday) => ({ weekday, from: '08:00', to: '16:00' })).concat([{ weekday: 6, from: '08:00', to: '11:30' }]), contact: 'Secretaria da Casa da Criança', instructions: 'Entrega pela entrada lateral. Informe o protocolo da doação na recepção e procure a Neusa (cozinha) ou o João (estoque).', isActive: true },
  { id: 'ponto-mercado', name: 'Ponto de coleta · Supermercado Boa Compra', address: 'Av. Principal, 1000 · Centro · Itapira/SP', hours: [1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, from: '08:00', to: '20:00' })), contact: 'Caixa de coleta na entrada do mercado', instructions: 'Deixe os itens na caixa de coleta, no balcão de atendimento. A equipe retira duas vezes por semana.', isActive: true },
];
for (const pt of POINTS) { const { id, ...d } = pt; set('donation_points', id, d); }
for (const n of needs) { const { id, validUntil, ...d } = n; set('donation_needs', id, { ...d, validUntil: validUntil ? validUntil.toISOString() : null, updatedAt: ts(at(0, 6, 30)) }); }
set('settings', 'donation_rules', { minShelfLifeDays: 30, maxOpenPledges: 3, maxItems: 20, blockedCategories: [] });
set('settings', 'counters', { [`donations_${TODAY.getFullYear()}`]: protocolsIssued });
set('settings', 'alerts', { criticalDays: 7, warningDays: 30, expiryEnabled: true, silentModeEnabled: false, silentFrom: null, silentUntil: null });
set('settings', 'stock_rules', { negativeAdjustmentApprovalLimit: 10 });
set('settings', 'report_schedule', { enabled: true, recipientEmail: U.admin.email, dayOfWeek: 1, sendTime: '08:00' });
for (const [id, label] of [['alimento', 'Alimento'], ['bebida', 'Bebida'], ['limpeza', 'Limpeza'], ['higienePessoal', 'Higiene Pessoal'], ['escolar', 'Material Escolar'], ['roupas', 'Roupas'], ['outro', 'Outro']]) set('settings_categories', id, { label, isActive: true });

// Doadores fictícios
for (const d of DONOR_DEFS) {
  set('donors', d.id, {
    displayName: d.name, donorType: d.type, phone: d.phone, city: d.city, termsVersion: '2026-1',
    prefs: { anonimo: false, notificacoes: true }, createdAt: ts(at(HORIZON - int(0, 100))), consentAt: ts(at(HORIZON - int(0, 100))),
  });
}

// Conta real de doador (Auth): recebe doações para a demonstração do portal
let realDonor = null;
try {
  const u = await getAuth().getUserByEmail('caua.lm4@gmail.com');
  const snap = await db.collection('donors').doc(u.uid).get();
  realDonor = { id: u.uid, name: snap.data()?.displayName ?? 'Doador', phone: snap.data()?.phone ?? null };
} catch { /* sem conta real de doador: segue só com os fictícios */ }

const writeDonation = (d, id) => {
  const donorId = d.donor.id;
  const eventsBase = `donations/${id}/events`;
  const status = d.status;
  const doc = {
    protocol: d.protocol, donorId, donorSnapshot: { displayName: d.donor.name, phone: d.donor.phone ?? null }, status,
    items: d.items.map((i) => ({ ...i, expiryDate: i.expiryDate ? ts(i.expiryDate) : null })), pointId: 'ponto-sede',
    window: { from: ts(d.window.from), to: ts(d.window.to) }, termsAcceptedAt: ts(d.created), createdAt: ts(d.created), updatedAt: ts(d.received ?? d.approved ?? d.created),
    reservationApplied: status === 'pendente' || status === 'aprovada' || status === 'recebida' || status === 'recebida_parcial',
    reservationReleased: !(status === 'pendente' || status === 'aprovada'),
  };
  let n = 0;
  const event = (type, from, to, by, byRole, note, when) => sub(`${eventsBase}/ev${String(++n).padStart(2, '0')}`, { type, fromStatus: from, toStatus: to, by, byRole, note: note ?? null, at: ts(when) });
  const notify = (title, body, st, when, read) => sub(`user_notifications/${donorId}/items/${id}-${st}`, { title, body, donationId: id, status: st, readAt: read ? ts(addDays(when, 0.1)) : null, createdAt: ts(when) });
  event('created', null, 'pendente', donorId, 'doador', d.protocol, d.created);
  const staff = pick([U.est1, U.est2, U.admin]);
  if (['aprovada', 'recebida', 'recebida_parcial'].includes(status)) {
    const when = d.approved ?? addDays(d.created, 1);
    event('status_changed', 'pendente', 'aprovada', staff.id, staff.role, d.approvalMessage ?? null, when);
    notify('Doação aprovada', `A equipe aprovou sua doação. Veja onde e quando entregar. (${d.protocol})`, 'aprovada', when, status !== 'aprovada');
    if (d.approvalMessage) doc.approvalMessage = d.approvalMessage;
    doc.updatedBy = staff.id; doc.updatedByName = staff.name; doc.updatedByRole = staff.role; doc.clientProcessedStatus = status;
  }
  if (status === 'recebida' || status === 'recebida_parcial') {
    event('status_changed', 'aprovada', status, staff.id, staff.role, d.protocol, d.received);
    doc.receivedAt = ts(d.received);
    doc.receivedItems = d.entries.map((e, i) => ({ index: i, receivedQty: e.batch.initialQuantity, batchId: e.batch.id, note: i === 0 && d.partialNote ? d.partialNote : null }));
    const impact = d.sector ? { sector: d.sector, message: impactMessage(d.donor.name, d.items.map((i) => i.description), d.sector), usedAt: ts(addDays(d.received, int(1, 4))), byName: staff.name } : null;
    if (impact) { doc.impact = impact; event('impact_registered', status, status, staff.id, staff.role, d.sector, addDays(d.received, 1)); }
    notify(status === 'recebida' ? 'Doação recebida' : 'Doação recebida parcialmente', `Recebemos sua doação. Obrigado por ajudar a Casa da Criança! (${d.protocol})${impact ? ' ' + impact.message : ''}`, status, d.received, d.created < at(10));
    doc.clientProcessedStatus = status;
  }
  if (status === 'recusada') {
    event('status_changed', 'pendente', 'recusada', staff.id, staff.role, d.reason, addDays(d.created, 1));
    doc.refusalReason = d.reason; doc.updatedBy = staff.id; doc.updatedByName = staff.name; doc.updatedByRole = staff.role; doc.clientProcessedStatus = 'recusada';
    notify('Doação recusada', `A equipe não pôde aceitar esta doação. ${d.reason} (${d.protocol})`, 'recusada', addDays(d.created, 1), true);
  }
  if (status === 'cancelada') { event('status_changed', 'pendente', 'cancelada', donorId, 'doador', d.reason, addDays(d.created, 1)); doc.cancelReason = d.reason; }
  if (status === 'expirada') { event('status_changed', 'aprovada', 'expirada', 'system', 'system', d.reason, addDays(d.created, 12)); doc.cancelReason = d.reason; }
  writer.set(db.collection('donations').doc(id), doc);
  if (['aprovada', 'recebida', 'recebida_parcial', 'recusada'].includes(status)) {
    sub(`audit_logs/aud-don-${id}`, { collection: 'donations', documentId: id, action: `donation_${status}`, before: { status: 'pendente' }, after: { status }, performedBy: staff.id, performedByName: staff.name, performedAt: iso(d.received ?? addDays(d.created, 1)) });
  }
};

// Doações do doador real: uma recebida (com impacto), uma aprovada e uma pendente
if (realDonor) {
  const mine = donations.filter((d) => d.status === 'recebida' && d.sector && d.entries.length >= 1).slice(0, 2);
  for (const d of mine) { d.donor = { ...d.donor, id: realDonor.id, name: realDonor.name, phone: realDonor.phone }; }
  const approved = openDonations.find((d) => d.status === 'aprovada' && d.donor.id === 'donor-paulo');
  if (approved) approved.donor = { ...approved.donor, id: realDonor.id, name: realDonor.name, phone: realDonor.phone };
  const pending = openDonations.find((d) => d.status === 'pendente' && d.donor.id === 'donor-fernanda');
  if (pending) pending.donor = { ...pending.donor, id: realDonor.id, name: realDonor.name, phone: realDonor.phone };
}

donations.forEach((d, i) => writeDonation(d, `don-rec-${String(i + 1).padStart(3, '0')}`));
openDonations.forEach((d, i) => writeDonation({
  ...d, items: d.lines.map((l) => ({ ...l })), approved: addDays(d.created, 1), window: { from: addDays(TODAY, 1), to: addDays(TODAY, 6) }, entries: [],
}, `don-abr-${String(i + 1).padStart(3, '0')}`));

await writer.close();
console.log('\nPronto. Dados de demonstração gravados em educastock-69936.');
