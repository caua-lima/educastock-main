/**
 * Seed completo do Firestore – EducaStock / Casa da Criança
 * Simula 6 meses de operação (doações, compras, distribuições, receitas).
 *
 * Pré-requisito: firebase-admin acessível (rode de dentro de functions/ ou
 *   exporte GOOGLE_APPLICATION_CREDENTIALS apontando para a service-account).
 *
 * Execução:
 *   node scripts/seed_database.mjs
 *   # ou, a partir da pasta functions/:
 *   node ../scripts/seed_database.mjs
 */

import { initializeApp, applicationDefault, getApps } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

if (!getApps().length) initializeApp({ credential: applicationDefault(), projectId: 'educastock-69936' });
const db = getFirestore();

// ─── Helpers de data ─────────────────────────────────────────────────────────
const now = new Date();
const daysAgo     = (n) => new Date(now.getTime() - n * 86_400_000).toISOString();
const daysFromNow = (n) => new Date(now.getTime() + n * 86_400_000).toISOString();

// ─── UIDs ────────────────────────────────────────────────────────────────────
const UID_ADMIN      = 'uid-admin-maria';
const UID_ESTOQUISTA = 'uid-estoquista-joao';
const UID_VOL        = 'uid-voluntario-ana';
const UID_CONSULTA   = 'uid-consulta-carlos';

// ═════════════════════════════════════════════════════════════════════════════
// 1. USERS
// ═════════════════════════════════════════════════════════════════════════════
const USERS = [
  { id: UID_ADMIN,      name: 'Maria Fernanda Costa',   email: 'maria.fernanda@casadacrianca.org.br', role: 'admin',      isActive: true,  twoFactorEnabled: true,  createdAt: daysAgo(180) },
  { id: UID_ESTOQUISTA, name: 'João Pedro Oliveira',    email: 'joao.pedro@casadacrianca.org.br',     role: 'estoquista', isActive: true,  twoFactorEnabled: false, createdAt: daysAgo(175) },
  { id: UID_VOL,        name: 'Ana Paula Santos',       email: 'ana.paula@casadacrianca.org.br',       role: 'voluntario', isActive: true,  twoFactorEnabled: false, createdAt: daysAgo(120) },
  { id: UID_CONSULTA,   name: 'Carlos Henrique Lima',   email: 'carlos.lima@casadacrianca.org.br',     role: 'consulta',   isActive: true,  twoFactorEnabled: false, createdAt: daysAgo(90)  },
];

// ═════════════════════════════════════════════════════════════════════════════
// 2. PRODUCTS
// ═════════════════════════════════════════════════════════════════════════════
const PRODUCTS = [
  // — alimento ————————————————————————————————————————————————————————————————
  { id:'prod-arroz',      name:'Arroz Branco Tipo 1',            brand:'Tio João',       category:'alimento',        unit:'kg',   barcode:'7891234560001', isPerishable:false, minimumStock:50, description:'Pacote 5 kg, longo fino tipo 1',              createdBy:UID_ADMIN,      createdAt:daysAgo(180), isActive:true },
  { id:'prod-feijao',     name:'Feijão Carioca',                 brand:'Camil',          category:'alimento',        unit:'kg',   barcode:'7891234560002', isPerishable:false, minimumStock:30, description:'Feijão carioca tipo 1, pacote 1 kg',          createdBy:UID_ADMIN,      createdAt:daysAgo(180), isActive:true },
  { id:'prod-macarrao',   name:'Macarrão Espaguete',             brand:'Renata',         category:'alimento',        unit:'pct',  barcode:'7891234560003', isPerishable:false, minimumStock:40, description:'Espaguete nº8, pacote 500 g',                 createdBy:UID_ADMIN,      createdAt:daysAgo(180), isActive:true },
  { id:'prod-oleo',       name:'Óleo de Soja Refinado',          brand:'Soya',           category:'alimento',        unit:'L',    barcode:'7891234560004', isPerishable:false, minimumStock:20, description:'Frasco 900 ml',                               createdBy:UID_ADMIN,      createdAt:daysAgo(180), isActive:true },
  { id:'prod-farinha',    name:'Farinha de Trigo Especial',      brand:'Dona Benta',     category:'alimento',        unit:'kg',   barcode:'7891234560005', isPerishable:false, minimumStock:25, description:'Pacote 1 kg',                                 createdBy:UID_ADMIN,      createdAt:daysAgo(180), isActive:true },
  { id:'prod-acucar',     name:'Açúcar Cristal',                 brand:'União',          category:'alimento',        unit:'kg',   barcode:'7891234560006', isPerishable:false, minimumStock:20, description:'Pacote 2 kg',                                 createdBy:UID_ADMIN,      createdAt:daysAgo(180), isActive:true },
  { id:'prod-leite',      name:'Leite em Pó Integral',           brand:'Ninho',          category:'alimento',        unit:'lata', barcode:'7891234560007', isPerishable:true,  minimumStock:30, description:'Lata 400 g',                                  createdBy:UID_ADMIN,      createdAt:daysAgo(180), isActive:true },
  { id:'prod-sardinha',        name:'Sardinha em Lata ao Molho',         brand:'Coqueiro',       category:'alimento',       unit:'un',   barcode:'7891234560008', isPerishable:true,  minimumStock:50, description:'Lata 125 g ao molho de tomate',                createdBy:UID_ESTOQUISTA, createdAt:daysAgo(115), isActive:true },
  { id:'prod-farinha-mandioca',name:'Farinha de Mandioca Torrada',        brand:'Yoki',           category:'alimento',       unit:'kg',   barcode:'7891234560020', isPerishable:false, minimumStock:20, description:'Pacote 500 g',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(100), isActive:true },
  { id:'prod-aveia',           name:'Aveia em Flocos',                    brand:'Quaker',         category:'alimento',       unit:'pct',  barcode:'7891234560021', isPerishable:false, minimumStock:20, description:'Pacote 200 g',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(95),  isActive:true },
  { id:'prod-extrato-tomate',  name:'Extrato de Tomate',                  brand:'Elefante',       category:'alimento',       unit:'un',   barcode:'7891234560022', isPerishable:true,  minimumStock:30, description:'Lata 370 g',                                    createdBy:UID_ESTOQUISTA, createdAt:daysAgo(90),  isActive:true },
  { id:'prod-milho-lata',      name:'Milho Verde em Lata',                brand:'Bonduelle',      category:'alimento',       unit:'un',   barcode:'7891234560023', isPerishable:true,  minimumStock:25, description:'Lata 170 g drenado',                            createdBy:UID_ESTOQUISTA, createdAt:daysAgo(85),  isActive:true },
  { id:'prod-ervilha-lata',    name:'Ervilha em Lata',                    brand:'Bonduelle',      category:'alimento',       unit:'un',   barcode:'7891234560024', isPerishable:true,  minimumStock:20, description:'Lata 170 g drenado',                            createdBy:UID_ESTOQUISTA, createdAt:daysAgo(80),  isActive:true },
  { id:'prod-biscoito',        name:'Biscoito Cream Cracker',             brand:'Marilan',        category:'alimento',       unit:'pct',  barcode:'7891234560025', isPerishable:false, minimumStock:30, description:'Pacote 400 g',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(75),  isActive:true },
  { id:'prod-achocolatado',    name:'Achocolatado em Pó',                 brand:'Nescau',         category:'alimento',       unit:'pct',  barcode:'7891234560026', isPerishable:false, minimumStock:15, description:'Pacote 400 g',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(70),  isActive:true },
  { id:'prod-fuba',            name:'Fubá de Milho',                      brand:'Yoki',           category:'alimento',       unit:'kg',   barcode:'7891234560027', isPerishable:false, minimumStock:20, description:'Pacote 1 kg',                                   createdBy:UID_VOL,        createdAt:daysAgo(65),  isActive:true },
  { id:'prod-sal',             name:'Sal Refinado Iodado',                brand:'Cisne',          category:'alimento',       unit:'kg',   barcode:'7891234560028', isPerishable:false, minimumStock:15, description:'Pacote 1 kg',                                   createdBy:UID_ESTOQUISTA, createdAt:daysAgo(60),  isActive:true },
  { id:'prod-cafe',            name:'Café Torrado e Moído',               brand:'Pilão',          category:'alimento',       unit:'pct',  barcode:'7891234560029', isPerishable:false, minimumStock:15, description:'Pacote 250 g',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(55),  isActive:true },
  // — bebida ——————————————————————————————————————————————————————————————————
  { id:'prod-suco',       name:'Suco de Uva Integral',           brand:'Maguary',        category:'bebida',          unit:'L',    barcode:'7891234560009', isPerishable:true,  minimumStock:30, description:'Embalagem 1 L',                               createdBy:UID_ESTOQUISTA, createdAt:daysAgo(105), isActive:true },
  // — limpeza —————————————————————————————————————————————————————————————————
  { id:'prod-sabao',      name:'Sabão em Pó Concentrado',        brand:'OMO',            category:'limpeza',         unit:'kg',   barcode:'7891234560010', isPerishable:false, minimumStock:15, description:'Caixa 1 kg',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(95),  isActive:true },
  { id:'prod-sanitario',  name:'Água Sanitária',                 brand:'Ypê',            category:'limpeza',         unit:'L',    barcode:'7891234560011', isPerishable:false, minimumStock:10, description:'Frasco 1 L',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(85),  isActive:true },
  { id:'prod-detergente', name:'Detergente Neutro Concentrado',  brand:'Ypê',            category:'limpeza',         unit:'L',    barcode:'7891234560012', isPerishable:false, minimumStock:12, description:'Frasco 500 ml',                               createdBy:UID_VOL,        createdAt:daysAgo(80),  isActive:true },
  // — higienePessoal ——————————————————————————————————————————————————————————
  { id:'prod-sabonete',   name:'Sabonete Glicerinado',           brand:'Lux',            category:'higienePessoal',  unit:'un',   barcode:'7891234560013', isPerishable:false, minimumStock:50, description:'Barra 90 g',                                  createdBy:UID_ESTOQUISTA, createdAt:daysAgo(75),  isActive:true },
  { id:'prod-shampoo',    name:'Shampoo Suave Uso Diário',       brand:'Seda',           category:'higienePessoal',  unit:'L',    barcode:'7891234560014', isPerishable:false, minimumStock:20, description:'Frasco 350 ml',                               createdBy:UID_VOL,        createdAt:daysAgo(70),  isActive:true },
  { id:'prod-dental',     name:'Creme Dental com Flúor',         brand:'Colgate',        category:'higienePessoal',  unit:'un',   barcode:'7891234560015', isPerishable:false, minimumStock:30, description:'Tubo 90 g',                                   createdBy:UID_ESTOQUISTA, createdAt:daysAgo(65),  isActive:true },
  { id:'prod-papel',      name:'Papel Higiênico Folha Dupla',    brand:'Neve',           category:'higienePessoal',  unit:'pct',  barcode:'7891234560016', isPerishable:false, minimumStock:20, description:'Pacote com 4 rolos',                          createdBy:UID_VOL,        createdAt:daysAgo(60),  isActive:true },
  // — escolar —————————————————————————————————————————————————————————————————
  { id:'prod-caderno',    name:'Caderno Universitário 96 Folhas',brand:'Foroni',         category:'escolar',         unit:'un',   barcode:'7891234560017', isPerishable:false, minimumStock:40, description:'1 matéria, capa flexível',                    createdBy:UID_ESTOQUISTA, createdAt:daysAgo(55),  isActive:true },
  { id:'prod-lapis',      name:'Lápis de Cor 12 Cores',          brand:'Faber-Castell',  category:'escolar',         unit:'pct',  barcode:'7891234560018', isPerishable:false, minimumStock:20, description:'Estojo com 12 cores',                         createdBy:UID_ESTOQUISTA, createdAt:daysAgo(50),  isActive:true },
  // — outro ———————————————————————————————————————————————————————————————————
  { id:'prod-fralda',     name:'Fralda Descartável Tamanho P',   brand:'Pampers',        category:'outro',           unit:'pct',  barcode:'7891234560019', isPerishable:false, minimumStock:15, description:'Pacote com 28 unidades',                      createdBy:UID_ADMIN,      createdAt:daysAgo(45),  isActive:true },
  // — roupas ——————————————————————————————————————————————————————————————————
  { id:'prod-camiseta',   name:'Camiseta Infantil Unissex Tam. 8',brand:null,            category:'roupas',          unit:'un',   barcode:null,            isPerishable:false, minimumStock:20, description:'Doações em boas condições, tamanho 8',        createdBy:UID_VOL,        createdAt:daysAgo(40),  isActive:true },
];

// ═════════════════════════════════════════════════════════════════════════════
// 3. STORAGE LOCATIONS
// ═════════════════════════════════════════════════════════════════════════════
const LOCATIONS = [
  { id:'loc-dep-a1',  locationName:'Depósito Principal', section:'A', shelf:'1', level:'1', room:'Depósito Principal', shelvesCount:4, levelsCount:3, productsPerLevel:6, capacity:72,  isActive:true, createdAt:daysAgo(180), normalizedKey:'a|1|1', label:'Depósito Principal • Seção A • Prateleira 1' },
  { id:'loc-dep-a2',  locationName:'Depósito Principal', section:'A', shelf:'2', level:'1', room:'Depósito Principal', shelvesCount:4, levelsCount:3, productsPerLevel:6, capacity:72,  isActive:true, createdAt:daysAgo(180), normalizedKey:'a|2|1', label:'Depósito Principal • Seção A • Prateleira 2' },
  { id:'loc-dep-b1',  locationName:'Depósito Principal', section:'B', shelf:'1', level:'1', room:'Depósito Principal', shelvesCount:4, levelsCount:3, productsPerLevel:6, capacity:72,  isActive:true, createdAt:daysAgo(180), normalizedKey:'b|1|1', label:'Depósito Principal • Seção B • Prateleira 1' },
  { id:'loc-dep-b2',  locationName:'Depósito Principal', section:'B', shelf:'2', level:'1', room:'Depósito Principal', shelvesCount:4, levelsCount:3, productsPerLevel:6, capacity:72,  isActive:true, createdAt:daysAgo(180), normalizedKey:'b|2|1', label:'Depósito Principal • Seção B • Prateleira 2' },
  { id:'loc-dep-c1',  locationName:'Depósito Principal', section:'C', shelf:'1', level:'1', room:'Depósito Principal', shelvesCount:2, levelsCount:2, productsPerLevel:4, capacity:16,  isActive:true, createdAt:daysAgo(180), normalizedKey:'c|1|1', label:'Depósito Principal • Seção C • Prateleira 1' },
  { id:'loc-frig-a1', locationName:'Frigorífico',        section:'A', shelf:'1', level:'1', room:'Frigorífico',        shelvesCount:2, levelsCount:2, productsPerLevel:4, capacity:16,  isActive:true, createdAt:daysAgo(180), normalizedKey:'a|1|1', label:'Frigorífico • Seção A • Prateleira 1' },
  { id:'loc-alm-a1',  locationName:'Almoxarifado',       section:'A', shelf:'1', level:null, room:'Almoxarifado',      shelvesCount:3, levelsCount:null, productsPerLevel:null, capacity:30, isActive:true, createdAt:daysAgo(180), normalizedKey:'a|1|null', label:'Almoxarifado • Seção A • Prateleira 1' },
  { id:'loc-dist-a1', locationName:'Sala de Distribuição',section:'A',shelf:'1', level:null, room:'Sala de Distribuição',shelvesCount:2,levelsCount:null,productsPerLevel:null,capacity:20, isActive:true, createdAt:daysAgo(180), normalizedKey:'a|1|null', label:'Sala de Distribuição • Seção A • Prateleira 1' },
];

// ═════════════════════════════════════════════════════════════════════════════
// 4. BATCHES
// Quantidades finais verificadas contra todos os movimentos abaixo.
// ═════════════════════════════════════════════════════════════════════════════
const BATCHES = [
  // ── ARROZ ──────────────────────────────────────────────────────────────────
  // 200 init → -50(r1) -30(r2) -20(d,-100) -15(d,-80) -40(r4) = 45 final
  { id:'batch-arroz-001', productId:'prod-arroz', productName:'Arroz Branco Tipo 1',
    quantity:45, initialQuantity:200, expiryDate:daysFromNow(365), noExpiry:false,
    entryDate:daysAgo(180), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:4.50,
    batchNumber:'CC-ARR-001', imageUrl:null, shelfLocation:'loc-dep-a1', status:'disponivel',
    notes:'Estoque inicial do semestre', createdBy:UID_ADMIN, createdAt:daysAgo(180) },
  // 150 init → -20(r6,-20) = 130 final
  { id:'batch-arroz-002', productId:'prod-arroz', productName:'Arroz Branco Tipo 1',
    quantity:130, initialQuantity:150, expiryDate:daysFromNow(300), noExpiry:false,
    entryDate:daysAgo(25), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:4.80,
    batchNumber:'CC-ARR-002', imageUrl:null, shelfLocation:'loc-dep-a1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(25) },

  // ── FEIJÃO ─────────────────────────────────────────────────────────────────
  // 150 init → -20(r1) -15(r2) -20(r4) -65(d) -10(ajuste) = 20 final
  { id:'batch-feijao-001', productId:'prod-feijao', productName:'Feijão Carioca',
    quantity:20, initialQuantity:150, expiryDate:daysFromNow(300), noExpiry:false,
    entryDate:daysAgo(170), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:6.90,
    batchNumber:'CC-FEJ-001', imageUrl:null, shelfLocation:'loc-dep-a1', status:'disponivel',
    notes:'Estoque inicial do semestre', createdBy:UID_ADMIN, createdAt:daysAgo(170) },
  // 100 init → -10(r6,-20) = 90 final
  { id:'batch-feijao-002', productId:'prod-feijao', productName:'Feijão Carioca',
    quantity:90, initialQuantity:100, expiryDate:daysFromNow(350), noExpiry:false,
    entryDate:daysAgo(15), origin:'doacao', donor:'Banco de Alimentos SP', supplier:null, unitPrice:null,
    batchNumber:'CC-FEJ-002', imageUrl:null, shelfLocation:'loc-dep-a1', status:'disponivel',
    notes:'Doação do Banco de Alimentos São Paulo', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(15) },

  // ── MACARRÃO ───────────────────────────────────────────────────────────────
  // 200 init → -10(r1) -15(r2) -60(d,-100) -55(d,-80) -10(r4) = 50 final
  { id:'batch-macarrao-001', productId:'prod-macarrao', productName:'Macarrão Espaguete',
    quantity:50, initialQuantity:200, expiryDate:daysFromNow(180), noExpiry:false,
    entryDate:daysAgo(160), origin:'doacao', donor:'Paróquia São José', supplier:null, unitPrice:null,
    batchNumber:'CC-MAC-001', imageUrl:null, shelfLocation:'loc-dep-a1', status:'disponivel',
    notes:'Campanha solidária da paróquia', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(160) },
  // 150 init → -10(r6,-20) = 140 final
  { id:'batch-macarrao-002', productId:'prod-macarrao', productName:'Macarrão Espaguete',
    quantity:140, initialQuantity:150, expiryDate:daysFromNow(270), noExpiry:false,
    entryDate:daysAgo(10), origin:'parceiro', donor:null, supplier:'Supermercado BomPreço', unitPrice:null,
    batchNumber:'CC-MAC-002', imageUrl:null, shelfLocation:'loc-dep-a2', status:'disponivel',
    notes:'Parceria mensal com Supermercado BomPreço', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(10) },

  // ── ÓLEO ───────────────────────────────────────────────────────────────────
  // 60 init → -10(r1) -27(d,-100) -8(r4) = 15 final
  { id:'batch-oleo-001', productId:'prod-oleo', productName:'Óleo de Soja Refinado',
    quantity:15, initialQuantity:60, expiryDate:daysFromNow(120), noExpiry:false,
    entryDate:daysAgo(150), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:6.50,
    batchNumber:'CC-OLE-001', imageUrl:null, shelfLocation:'loc-dep-b1', status:'disponivel',
    notes:null, createdBy:UID_ADMIN, createdAt:daysAgo(150) },
  // 40 init → -5(d,-50) = 35 final
  { id:'batch-oleo-002', productId:'prod-oleo', productName:'Óleo de Soja Refinado',
    quantity:35, initialQuantity:40, expiryDate:daysFromNow(200), noExpiry:false,
    entryDate:daysAgo(70), origin:'doacao', donor:'Distribuidora Irmãos Pereira', supplier:null, unitPrice:null,
    batchNumber:'CC-OLE-002', imageUrl:null, shelfLocation:'loc-dep-b1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(70) },

  // ── FARINHA ────────────────────────────────────────────────────────────────
  // 100 init → -10(r1) -50(d,-100) -10(r4) = 30 final
  { id:'batch-farinha-001', productId:'prod-farinha', productName:'Farinha de Trigo Especial',
    quantity:30, initialQuantity:100, expiryDate:daysFromNow(150), noExpiry:false,
    entryDate:daysAgo(140), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:4.20,
    batchNumber:'CC-FAR-001', imageUrl:null, shelfLocation:'loc-dep-b1', status:'disponivel',
    notes:null, createdBy:UID_ADMIN, createdAt:daysAgo(140) },

  // ── AÇÚCAR ─────────────────────────────────────────────────────────────────
  // 80 init → -10(r1) -35(d,-100) -10(r4) = 25 final
  { id:'batch-acucar-001', productId:'prod-acucar', productName:'Açúcar Cristal',
    quantity:25, initialQuantity:80, expiryDate:daysFromNow(500), noExpiry:false,
    entryDate:daysAgo(130), origin:'doacao', donor:'Usina Santa Cruz', supplier:null, unitPrice:null,
    batchNumber:'CC-ACU-001', imageUrl:null, shelfLocation:'loc-dep-b1', status:'disponivel',
    notes:'Doação direta da usina para a ONG', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(130) },

  // ── LEITE – VENCIMENTO CRÍTICO (≤ 7 dias) ──────────────────────────────────
  // 100 init → -40(d,-90) -40(d,-60) = 20 final
  { id:'batch-leite-001', productId:'prod-leite', productName:'Leite em Pó Integral',
    quantity:20, initialQuantity:100, expiryDate:daysFromNow(5), noExpiry:false,
    entryDate:daysAgo(120), origin:'compra', donor:null, supplier:'Distribuidora NutriLife Alimentos', unitPrice:18.90,
    batchNumber:'CC-LEI-001', imageUrl:null, shelfLocation:'loc-frig-a1', status:'disponivel',
    notes:'⚠ Vencimento próximo — distribuir com urgência', createdBy:UID_ADMIN, createdAt:daysAgo(120) },

  // ── LEITE – VENCIMENTO DE ATENÇÃO (≤ 30 dias) ─────────────────────────────
  // 50 init → -10(d,-25) = 40 final
  { id:'batch-leite-002', productId:'prod-leite', productName:'Leite em Pó Integral',
    quantity:40, initialQuantity:50, expiryDate:daysFromNow(20), noExpiry:false,
    entryDate:daysAgo(30), origin:'doacao', donor:'Campanha do Agasalho SP', supplier:null, unitPrice:null,
    batchNumber:'CC-LEI-002', imageUrl:null, shelfLocation:'loc-frig-a1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(30) },

  // ── SARDINHA ───────────────────────────────────────────────────────────────
  // 200 init → -60(d,-90) -60(d,-60) = 80 final
  { id:'batch-sardinha-001', productId:'prod-sardinha', productName:'Sardinha em Lata ao Molho',
    quantity:80, initialQuantity:200, expiryDate:daysFromNow(400), noExpiry:false,
    entryDate:daysAgo(110), origin:'parceiro', donor:null, supplier:'Supermercado BomPreço', unitPrice:null,
    batchNumber:'CC-SAR-001', imageUrl:null, shelfLocation:'loc-dep-a2', status:'disponivel',
    notes:'Parceria mensal', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(110) },
  // 100 init → sem saída = 100 final
  { id:'batch-sardinha-002', productId:'prod-sardinha', productName:'Sardinha em Lata ao Molho',
    quantity:100, initialQuantity:100, expiryDate:daysFromNow(600), noExpiry:false,
    entryDate:daysAgo(5), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:4.50,
    batchNumber:'CC-SAR-002', imageUrl:null, shelfLocation:'loc-dep-a2', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(5) },

  // ── SUCO – DISTRIBUÍDO INTEGRALMENTE ──────────────────────────────────────
  // 150 init → -150(d,-80) = 0 final  → status: distribuido
  { id:'batch-suco-001', productId:'prod-suco', productName:'Suco de Uva Integral',
    quantity:0, initialQuantity:150, expiryDate:daysAgo(10), noExpiry:false,
    entryDate:daysAgo(100), origin:'doacao', donor:'Campanha Solidária Feirão 2025', supplier:null, unitPrice:null,
    batchNumber:'CC-SUC-001', imageUrl:null, shelfLocation:'loc-dist-a1', status:'distribuido',
    notes:'Distribuído integralmente na festa junina da ONG', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(100) },

  // ── SABÃO ──────────────────────────────────────────────────────────────────
  { id:'batch-sabao-001', productId:'prod-sabao', productName:'Sabão em Pó Concentrado',
    quantity:25, initialQuantity:40, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(90), origin:'compra', donor:null, supplier:'Distribuidora Clean Total', unitPrice:12.50,
    batchNumber:'CC-SAB-001', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(90) },

  // ── ÁGUA SANITÁRIA ─────────────────────────────────────────────────────────
  { id:'batch-sanitario-001', productId:'prod-sanitario', productName:'Água Sanitária',
    quantity:18, initialQuantity:30, expiryDate:daysFromNow(90), noExpiry:false,
    entryDate:daysAgo(80), origin:'compra', donor:null, supplier:'Distribuidora Clean Total', unitPrice:3.20,
    batchNumber:'CC-SAN-001', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(80) },

  // ── DETERGENTE ─────────────────────────────────────────────────────────────
  { id:'batch-detergente-001', productId:'prod-detergente', productName:'Detergente Neutro Concentrado',
    quantity:20, initialQuantity:24, expiryDate:daysFromNow(150), noExpiry:false,
    entryDate:daysAgo(75), origin:'doacao', donor:'Rotary Club São Paulo Centro', supplier:null, unitPrice:null,
    batchNumber:'CC-DET-001', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:null, createdBy:UID_VOL, createdAt:daysAgo(75) },

  // ── SABONETE ───────────────────────────────────────────────────────────────
  // 100 init → -16(r3,-80) -40(d,-55) = 44 final
  { id:'batch-sabonete-001', productId:'prod-sabonete', productName:'Sabonete Glicerinado',
    quantity:44, initialQuantity:100, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(70), origin:'compra', donor:null, supplier:'Distribuidora Clean Total', unitPrice:2.80,
    batchNumber:'CC-SAO-001', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(70) },
  // 80 init → sem saída = 80 final
  { id:'batch-sabonete-002', productId:'prod-sabonete', productName:'Sabonete Glicerinado',
    quantity:80, initialQuantity:80, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(3), origin:'doacao', donor:'Lions Club São Paulo Norte', supplier:null, unitPrice:null,
    batchNumber:'CC-SAO-002', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:'Campanha higiene pessoal Lions Club', createdBy:UID_VOL, createdAt:daysAgo(3) },

  // ── SHAMPOO ────────────────────────────────────────────────────────────────
  { id:'batch-shampoo-001', productId:'prod-shampoo', productName:'Shampoo Suave Uso Diário',
    quantity:20, initialQuantity:30, expiryDate:daysFromNow(300), noExpiry:false,
    entryDate:daysAgo(65), origin:'doacao', donor:'Escola Estadual Prof. Marcos Freire', supplier:null, unitPrice:null,
    batchNumber:'CC-SHA-001', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:null, createdBy:UID_VOL, createdAt:daysAgo(65) },

  // ── CREME DENTAL ───────────────────────────────────────────────────────────
  // 60 init → -8(r3,-80) -8(d,-55) = 44 final
  { id:'batch-dental-001', productId:'prod-dental', productName:'Creme Dental com Flúor',
    quantity:44, initialQuantity:60, expiryDate:daysFromNow(400), noExpiry:false,
    entryDate:daysAgo(60), origin:'compra', donor:null, supplier:'Distribuidora Clean Total', unitPrice:3.50,
    batchNumber:'CC-DEN-001', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(60) },

  // ── PAPEL HIGIÊNICO ────────────────────────────────────────────────────────
  // 40 init → -8(r3,-80) -8(d,-55) = 24 final
  { id:'batch-papel-001', productId:'prod-papel', productName:'Papel Higiênico Folha Dupla',
    quantity:24, initialQuantity:40, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(55), origin:'doacao', donor:'Igreja Batista Central', supplier:null, unitPrice:null,
    batchNumber:'CC-PAP-001', imageUrl:null, shelfLocation:'loc-dep-c1', status:'disponivel',
    notes:null, createdBy:UID_VOL, createdAt:daysAgo(55) },

  // ── CADERNO ────────────────────────────────────────────────────────────────
  // 80 init → -24(r5,-40) = 56 final
  { id:'batch-caderno-001', productId:'prod-caderno', productName:'Caderno Universitário 96 Folhas',
    quantity:56, initialQuantity:80, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(50), origin:'doacao', donor:'Campanha Volta às Aulas Solidária', supplier:null, unitPrice:null,
    batchNumber:'CC-CAD-001', imageUrl:null, shelfLocation:'loc-alm-a1', status:'disponivel',
    notes:'Doação da campanha volta às aulas', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(50) },

  // ── LÁPIS DE COR ───────────────────────────────────────────────────────────
  // 40 init → -12(r5,-40) = 28 final
  { id:'batch-lapis-001', productId:'prod-lapis', productName:'Lápis de Cor 12 Cores',
    quantity:28, initialQuantity:40, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(45), origin:'doacao', donor:'Campanha Volta às Aulas Solidária', supplier:null, unitPrice:null,
    batchNumber:'CC-LAP-001', imageUrl:null, shelfLocation:'loc-alm-a1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(45) },

  // ── FRALDA ─────────────────────────────────────────────────────────────────
  { id:'batch-fralda-001', productId:'prod-fralda', productName:'Fralda Descartável Tamanho P',
    quantity:20, initialQuantity:30, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(40), origin:'compra', donor:null, supplier:'Farmácia Popular Saúde+', unitPrice:45.90,
    batchNumber:'CC-FRA-001', imageUrl:null, shelfLocation:'loc-alm-a1', status:'disponivel',
    notes:null, createdBy:UID_ADMIN, createdAt:daysAgo(40) },

  // ── CAMISETA ───────────────────────────────────────────────────────────────
  { id:'batch-camiseta-001', productId:'prod-camiseta', productName:'Camiseta Infantil Unissex Tam. 8',
    quantity:35, initialQuantity:50, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(35), origin:'doacao', donor:'Associação de Moradores Vila Nova', supplier:null, unitPrice:null,
    batchNumber:'CC-CAM-001', imageUrl:null, shelfLocation:'loc-alm-a1', status:'disponivel',
    notes:'Roupas usadas em boas condições', createdBy:UID_VOL, createdAt:daysAgo(35) },

  // ── FARINHA DE MANDIOCA ────────────────────────────────────────────────────
  // 60 init → -25(d,-70) = 35 final
  { id:'batch-farinha-mandioca-001', productId:'prod-farinha-mandioca', productName:'Farinha de Mandioca Torrada',
    quantity:35, initialQuantity:60, expiryDate:daysFromNow(180), noExpiry:false,
    entryDate:daysAgo(95), origin:'doacao', donor:'CEASA Campinas', supplier:null, unitPrice:null,
    batchNumber:'CC-FMA-001', imageUrl:null, shelfLocation:'loc-dep-b2', status:'disponivel',
    notes:'Doação excedente do CEASA', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(95) },

  // ── AVEIA ──────────────────────────────────────────────────────────────────
  // 80 init → -30(d,-65) = 50 final
  { id:'batch-aveia-001', productId:'prod-aveia', productName:'Aveia em Flocos',
    quantity:50, initialQuantity:80, expiryDate:daysFromNow(200), noExpiry:false,
    entryDate:daysAgo(90), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:3.90,
    batchNumber:'CC-AVE-001', imageUrl:null, shelfLocation:'loc-dep-b2', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(90) },

  // ── EXTRATO DE TOMATE ──────────────────────────────────────────────────────
  // 120 init → -50(d,-60) = 70 final
  { id:'batch-extrato-tomate-001', productId:'prod-extrato-tomate', productName:'Extrato de Tomate',
    quantity:70, initialQuantity:120, expiryDate:daysFromNow(300), noExpiry:false,
    entryDate:daysAgo(85), origin:'parceiro', donor:null, supplier:'Supermercado BomPreço', unitPrice:null,
    batchNumber:'CC-EXT-001', imageUrl:null, shelfLocation:'loc-dep-a2', status:'disponivel',
    notes:'Parceria mensal BomPreço', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(85) },

  // ── MILHO VERDE ────────────────────────────────────────────────────────────
  // 100 init → -40(d,-55) = 60 final
  { id:'batch-milho-lata-001', productId:'prod-milho-lata', productName:'Milho Verde em Lata',
    quantity:60, initialQuantity:100, expiryDate:daysFromNow(500), noExpiry:false,
    entryDate:daysAgo(80), origin:'doacao', donor:'Banco de Alimentos SP', supplier:null, unitPrice:null,
    batchNumber:'CC-MLH-001', imageUrl:null, shelfLocation:'loc-dep-a2', status:'disponivel',
    notes:null, createdBy:UID_VOL, createdAt:daysAgo(80) },

  // ── ERVILHA ────────────────────────────────────────────────────────────────
  // 80 init → -30(d,-50) = 50 final
  { id:'batch-ervilha-lata-001', productId:'prod-ervilha-lata', productName:'Ervilha em Lata',
    quantity:50, initialQuantity:80, expiryDate:daysFromNow(500), noExpiry:false,
    entryDate:daysAgo(75), origin:'doacao', donor:'Banco de Alimentos SP', supplier:null, unitPrice:null,
    batchNumber:'CC-ERV-001', imageUrl:null, shelfLocation:'loc-dep-a2', status:'disponivel',
    notes:null, createdBy:UID_VOL, createdAt:daysAgo(75) },

  // ── BISCOITO ───────────────────────────────────────────────────────────────
  // 150 init → -70(d,-45) = 80 final
  { id:'batch-biscoito-001', productId:'prod-biscoito', productName:'Biscoito Cream Cracker',
    quantity:80, initialQuantity:150, expiryDate:daysFromNow(120), noExpiry:false,
    entryDate:daysAgo(70), origin:'doacao', donor:'Paróquia São José', supplier:null, unitPrice:null,
    batchNumber:'CC-BSC-001', imageUrl:null, shelfLocation:'loc-dep-b2', status:'disponivel',
    notes:'Doação campanha solidária paróquia', createdBy:UID_VOL, createdAt:daysAgo(70) },

  // ── ACHOCOLATADO ───────────────────────────────────────────────────────────
  // 50 init → -20(d,-40) = 30 final
  { id:'batch-achocolatado-001', productId:'prod-achocolatado', productName:'Achocolatado em Pó',
    quantity:30, initialQuantity:50, expiryDate:daysFromNow(250), noExpiry:false,
    entryDate:daysAgo(65), origin:'compra', donor:null, supplier:'Distribuidora NutriLife Alimentos', unitPrice:9.90,
    batchNumber:'CC-ACH-001', imageUrl:null, shelfLocation:'loc-dep-b2', status:'disponivel',
    notes:'Para crianças em acompanhamento nutricional', createdBy:UID_ADMIN, createdAt:daysAgo(65) },

  // ── FUBÁ ───────────────────────────────────────────────────────────────────
  // 80 init → -30(d,-35) = 50 final
  { id:'batch-fuba-001', productId:'prod-fuba', productName:'Fubá de Milho',
    quantity:50, initialQuantity:80, expiryDate:daysFromNow(300), noExpiry:false,
    entryDate:daysAgo(60), origin:'doacao', donor:'CEASA Campinas', supplier:null, unitPrice:null,
    batchNumber:'CC-FUB-001', imageUrl:null, shelfLocation:'loc-dep-b2', status:'disponivel',
    notes:'Para receitas de canjica e bolo de milho', createdBy:UID_VOL, createdAt:daysAgo(60) },

  // ── SAL ────────────────────────────────────────────────────────────────────
  // 100 init → -30(d,-30) = 70 final
  { id:'batch-sal-001', productId:'prod-sal', productName:'Sal Refinado Iodado',
    quantity:70, initialQuantity:100, expiryDate:null, noExpiry:true,
    entryDate:daysAgo(55), origin:'compra', donor:null, supplier:'Distribuidora Alimentos Santos Ltda', unitPrice:2.50,
    batchNumber:'CC-SAL-001', imageUrl:null, shelfLocation:'loc-dep-b1', status:'disponivel',
    notes:null, createdBy:UID_ESTOQUISTA, createdAt:daysAgo(55) },

  // ── CAFÉ ───────────────────────────────────────────────────────────────────
  // 60 init → -20(d,-25) = 40 final
  { id:'batch-cafe-001', productId:'prod-cafe', productName:'Café Torrado e Moído',
    quantity:40, initialQuantity:60, expiryDate:daysFromNow(180), noExpiry:false,
    entryDate:daysAgo(50), origin:'parceiro', donor:null, supplier:'Cafeteria Sabor da Serra', unitPrice:null,
    batchNumber:'CC-CAF-001', imageUrl:null, shelfLocation:'loc-dep-b2', status:'disponivel',
    notes:'Parceria com cafeteria local para doação mensal', createdBy:UID_ESTOQUISTA, createdAt:daysAgo(50) },
];

// ═════════════════════════════════════════════════════════════════════════════
// 5. RECIPES
// ═════════════════════════════════════════════════════════════════════════════
const RECIPES = [
  { id:'recipe-cesta-grande', name:'Cesta Básica Família Grande', description:'Cesta mensal para família com 4+ membros', isPredefined:true, isActive:true, createdAt:daysAgo(178), createdBy:UID_ADMIN,
    items:[
      { productId:'prod-arroz',    productName:'Arroz Branco Tipo 1',         quantity:5  },
      { productId:'prod-feijao',   productName:'Feijão Carioca',               quantity:2  },
      { productId:'prod-oleo',     productName:'Óleo de Soja Refinado',        quantity:1  },
      { productId:'prod-macarrao', productName:'Macarrão Espaguete',           quantity:2  },
      { productId:'prod-farinha',  productName:'Farinha de Trigo Especial',    quantity:1  },
      { productId:'prod-acucar',   productName:'Açúcar Cristal',               quantity:1  },
    ]},
  { id:'recipe-cesta-pequena', name:'Cesta Básica Família Pequena', description:'Cesta mensal para família com até 3 membros', isPredefined:true, isActive:true, createdAt:daysAgo(178), createdBy:UID_ADMIN,
    items:[
      { productId:'prod-arroz',    productName:'Arroz Branco Tipo 1',         quantity:2  },
      { productId:'prod-feijao',   productName:'Feijão Carioca',               quantity:1  },
      { productId:'prod-macarrao', productName:'Macarrão Espaguete',           quantity:1  },
    ]},
  { id:'recipe-kit-higiene', name:'Kit de Higiene Pessoal', description:'Kit mensal por família', isPredefined:true, isActive:true, createdAt:daysAgo(75), createdBy:UID_ESTOQUISTA,
    items:[
      { productId:'prod-sabonete', productName:'Sabonete Glicerinado',         quantity:2  },
      { productId:'prod-dental',   productName:'Creme Dental com Flúor',       quantity:1  },
      { productId:'prod-papel',    productName:'Papel Higiênico Folha Dupla',  quantity:1  },
    ]},
  { id:'recipe-kit-escolar', name:'Kit Escolar Criança', description:'Kit para alunos de 6–12 anos', isPredefined:true, isActive:true, createdAt:daysAgo(55), createdBy:UID_ESTOQUISTA,
    items:[
      { productId:'prod-caderno',  productName:'Caderno Universitário 96 Folhas', quantity:2 },
      { productId:'prod-lapis',    productName:'Lápis de Cor 12 Cores',           quantity:1 },
    ]},
];

// ═════════════════════════════════════════════════════════════════════════════
// 6. STOCK MOVEMENTS  (entradas + saídas diretas + receitas)
// ═════════════════════════════════════════════════════════════════════════════
const MOVEMENTS = [
  // ── ENTRADAS ───────────────────────────────────────────────────────────────
  { id:'mov-ent-arroz-001',     productId:'prod-arroz',      productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-001',      type:'entrada',        quantity:200, reasonCode:null,              reason:'Compra para estoque inicial',                            activity:null, performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(180), isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:200, status:'disponivel'} },
  { id:'mov-ent-arroz-002',     productId:'prod-arroz',      productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-002',      type:'entrada',        quantity:150, reasonCode:null,              reason:'Reposição mensal',                                       activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(25),  isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:150, status:'disponivel'} },
  { id:'mov-ent-feijao-001',    productId:'prod-feijao',     productName:'Feijão Carioca',                  batchId:'batch-feijao-001',     type:'entrada',        quantity:150, reasonCode:null,              reason:'Compra para estoque inicial',                            activity:null, performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(170), isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:150, status:'disponivel'} },
  { id:'mov-ent-feijao-002',    productId:'prod-feijao',     productName:'Feijão Carioca',                  batchId:'batch-feijao-002',     type:'entrada',        quantity:100, reasonCode:null,              reason:'Doação Banco de Alimentos SP',                           activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(15),  isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-ent-macarrao-001',  productId:'prod-macarrao',   productName:'Macarrão Espaguete',              batchId:'batch-macarrao-001',   type:'entrada',        quantity:200, reasonCode:null,              reason:'Doação Paróquia São José',                               activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(160), isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:200, status:'disponivel'} },
  { id:'mov-ent-macarrao-002',  productId:'prod-macarrao',   productName:'Macarrão Espaguete',              batchId:'batch-macarrao-002',   type:'entrada',        quantity:150, reasonCode:null,              reason:'Parceria Supermercado BomPreço',                         activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(10),  isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:150, status:'disponivel'} },
  { id:'mov-ent-oleo-001',      productId:'prod-oleo',       productName:'Óleo de Soja Refinado',           batchId:'batch-oleo-001',       type:'entrada',        quantity:60,  reasonCode:null,              reason:'Compra mensal',                                          activity:null, performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(150), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:60,  status:'disponivel'} },
  { id:'mov-ent-oleo-002',      productId:'prod-oleo',       productName:'Óleo de Soja Refinado',           batchId:'batch-oleo-002',       type:'entrada',        quantity:40,  reasonCode:null,              reason:'Doação Distribuidora Irmãos Pereira',                    activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(70),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:40,  status:'disponivel'} },
  { id:'mov-ent-farinha-001',   productId:'prod-farinha',    productName:'Farinha de Trigo Especial',       batchId:'batch-farinha-001',    type:'entrada',        quantity:100, reasonCode:null,              reason:'Compra mensal',                                          activity:null, performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(140), isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-ent-acucar-001',    productId:'prod-acucar',     productName:'Açúcar Cristal',                  batchId:'batch-acucar-001',     type:'entrada',        quantity:80,  reasonCode:null,              reason:'Doação Usina Santa Cruz',                                activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(130), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-ent-leite-001',     productId:'prod-leite',      productName:'Leite em Pó Integral',            batchId:'batch-leite-001',      type:'entrada',        quantity:100, reasonCode:null,              reason:'Compra NutriLife Alimentos',                             activity:null, performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(120), isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-ent-leite-002',     productId:'prod-leite',      productName:'Leite em Pó Integral',            batchId:'batch-leite-002',      type:'entrada',        quantity:50,  reasonCode:null,              reason:'Doação Campanha do Agasalho SP',                         activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(30),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:50,  status:'disponivel'} },
  { id:'mov-ent-sardinha-001',  productId:'prod-sardinha',   productName:'Sardinha em Lata ao Molho',       batchId:'batch-sardinha-001',   type:'entrada',        quantity:200, reasonCode:null,              reason:'Parceria Supermercado BomPreço',                         activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(110), isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:200, status:'disponivel'} },
  { id:'mov-ent-sardinha-002',  productId:'prod-sardinha',   productName:'Sardinha em Lata ao Molho',       batchId:'batch-sardinha-002',   type:'entrada',        quantity:100, reasonCode:null,              reason:'Compra reposição',                                       activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(5),   isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-ent-suco-001',      productId:'prod-suco',       productName:'Suco de Uva Integral',            batchId:'batch-suco-001',       type:'entrada',        quantity:150, reasonCode:null,              reason:'Doação Campanha Solidária Feirão 2025',                  activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(100), isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:150, status:'disponivel'} },
  { id:'mov-ent-sabao-001',     productId:'prod-sabao',      productName:'Sabão em Pó Concentrado',         batchId:'batch-sabao-001',      type:'entrada',        quantity:40,  reasonCode:null,              reason:'Compra mensal',                                          activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(90),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:40,  status:'disponivel'} },
  { id:'mov-ent-sanitario-001', productId:'prod-sanitario',  productName:'Água Sanitária',                  batchId:'batch-sanitario-001',  type:'entrada',        quantity:30,  reasonCode:null,              reason:'Compra mensal',                                          activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(80),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:30,  status:'disponivel'} },
  { id:'mov-ent-detergente-001',productId:'prod-detergente', productName:'Detergente Neutro Concentrado',   batchId:'batch-detergente-001', type:'entrada',        quantity:24,  reasonCode:null,              reason:'Doação Rotary Club',                                     activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(75),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:24,  status:'disponivel'} },
  { id:'mov-ent-sabonete-001',  productId:'prod-sabonete',   productName:'Sabonete Glicerinado',            batchId:'batch-sabonete-001',   type:'entrada',        quantity:100, reasonCode:null,              reason:'Compra mensal',                                          activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(70),  isPendingSync:false, auditBefore:{quantity:0,   status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-ent-sabonete-002',  productId:'prod-sabonete',   productName:'Sabonete Glicerinado',            batchId:'batch-sabonete-002',   type:'entrada',        quantity:80,  reasonCode:null,              reason:'Doação Lions Club',                                      activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(3),   isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-ent-shampoo-001',   productId:'prod-shampoo',    productName:'Shampoo Suave Uso Diário',        batchId:'batch-shampoo-001',    type:'entrada',        quantity:30,  reasonCode:null,              reason:'Doação Escola Estadual',                                 activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(65),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:30,  status:'disponivel'} },
  { id:'mov-ent-dental-001',    productId:'prod-dental',     productName:'Creme Dental com Flúor',          batchId:'batch-dental-001',     type:'entrada',        quantity:60,  reasonCode:null,              reason:'Compra mensal',                                          activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(60),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:60,  status:'disponivel'} },
  { id:'mov-ent-papel-001',     productId:'prod-papel',      productName:'Papel Higiênico Folha Dupla',     batchId:'batch-papel-001',      type:'entrada',        quantity:40,  reasonCode:null,              reason:'Doação Igreja Batista',                                  activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(55),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:40,  status:'disponivel'} },
  { id:'mov-ent-caderno-001',   productId:'prod-caderno',    productName:'Caderno Universitário 96 Folhas', batchId:'batch-caderno-001',    type:'entrada',        quantity:80,  reasonCode:null,              reason:'Doação Campanha Volta às Aulas',                         activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(50),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-ent-lapis-001',     productId:'prod-lapis',      productName:'Lápis de Cor 12 Cores',           batchId:'batch-lapis-001',      type:'entrada',        quantity:40,  reasonCode:null,              reason:'Doação Campanha Volta às Aulas',                         activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(45),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:40,  status:'disponivel'} },
  { id:'mov-ent-fralda-001',    productId:'prod-fralda',     productName:'Fralda Descartável Tamanho P',    batchId:'batch-fralda-001',     type:'entrada',        quantity:30,  reasonCode:null,              reason:'Compra para famílias com bebês',                         activity:null, performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(40),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:30,  status:'disponivel'} },
  { id:'mov-ent-camiseta-001',  productId:'prod-camiseta',   productName:'Camiseta Infantil Unissex Tam. 8',batchId:'batch-camiseta-001',   type:'entrada',        quantity:50,  reasonCode:null,              reason:'Doação Associação de Moradores',                         activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(35),  isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'},  auditAfter:{quantity:50,  status:'disponivel'} },

  // ── SAÍDAS DIRETAS (distribuições mensais) ────────────────────────────────
  { id:'mov-sai-arroz-001a',    productId:'prod-arroz',      productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-001',      type:'saida',          quantity:20,  reasonCode:'doacao',          reason:'Distribuição mensal – Novembro',                        activity:'Distribuição Novembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(100), isPendingSync:false, auditBefore:{quantity:120, status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-sai-arroz-001b',    productId:'prod-arroz',      productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-001',      type:'saida',          quantity:15,  reasonCode:'doacao',          reason:'Distribuição emergencial',                              activity:'Distribuição Emergencial', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(80),  isPendingSync:false, auditBefore:{quantity:100, status:'disponivel'}, auditAfter:{quantity:85,  status:'disponivel'} },
  { id:'mov-sai-feijao-001a',   productId:'prod-feijao',     productName:'Feijão Carioca',                  batchId:'batch-feijao-001',     type:'saida',          quantity:30,  reasonCode:'doacao',          reason:'Distribuição mensal – Novembro',                        activity:'Distribuição Novembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(100), isPendingSync:false, auditBefore:{quantity:95, status:'disponivel'},  auditAfter:{quantity:65,  status:'disponivel'} },
  { id:'mov-sai-feijao-001b',   productId:'prod-feijao',     productName:'Feijão Carioca',                  batchId:'batch-feijao-001',     type:'saida',          quantity:35,  reasonCode:'doacao',          reason:'Distribuição mensal – Dezembro',                        activity:'Distribuição Dezembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(75),  isPendingSync:false, auditBefore:{quantity:65, status:'disponivel'},  auditAfter:{quantity:30,  status:'disponivel'} },
  { id:'mov-sai-macarrao-001a', productId:'prod-macarrao',   productName:'Macarrão Espaguete',              batchId:'batch-macarrao-001',   type:'saida',          quantity:60,  reasonCode:'doacao',          reason:'Distribuição mensal – Novembro',                        activity:'Distribuição Novembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(100), isPendingSync:false, auditBefore:{quantity:165, status:'disponivel'},auditAfter:{quantity:105, status:'disponivel'} },
  { id:'mov-sai-macarrao-001b', productId:'prod-macarrao',   productName:'Macarrão Espaguete',              batchId:'batch-macarrao-001',   type:'saida',          quantity:55,  reasonCode:'doacao',          reason:'Distribuição mensal – Dezembro',                        activity:'Distribuição Dezembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(75),  isPendingSync:false, auditBefore:{quantity:105, status:'disponivel'},auditAfter:{quantity:50,  status:'disponivel'} },
  { id:'mov-sai-oleo-001a',     productId:'prod-oleo',       productName:'Óleo de Soja Refinado',           batchId:'batch-oleo-001',       type:'saida',          quantity:27,  reasonCode:'doacao',          reason:'Distribuição mensal – Novembro/Dezembro',               activity:'Distribuição Novembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(100), isPendingSync:false, auditBefore:{quantity:50, status:'disponivel'},  auditAfter:{quantity:23,  status:'disponivel'} },
  { id:'mov-sai-oleo-002a',     productId:'prod-oleo',       productName:'Óleo de Soja Refinado',           batchId:'batch-oleo-002',       type:'saida',          quantity:5,   reasonCode:'doacao',          reason:'Distribuição Março',                                    activity:'Distribuição Março',     performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(50),  isPendingSync:false, auditBefore:{quantity:40, status:'disponivel'},  auditAfter:{quantity:35,  status:'disponivel'} },
  { id:'mov-sai-farinha-001a',  productId:'prod-farinha',    productName:'Farinha de Trigo Especial',       batchId:'batch-farinha-001',    type:'saida',          quantity:50,  reasonCode:'doacao',          reason:'Distribuição mensal – Novembro/Dezembro',               activity:'Distribuição Novembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(100), isPendingSync:false, auditBefore:{quantity:80, status:'disponivel'},  auditAfter:{quantity:30,  status:'disponivel'} },
  { id:'mov-sai-acucar-001a',   productId:'prod-acucar',     productName:'Açúcar Cristal',                  batchId:'batch-acucar-001',     type:'saida',          quantity:35,  reasonCode:'doacao',          reason:'Distribuição mensal – Dezembro/Janeiro',                activity:'Distribuição Dezembro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(100), isPendingSync:false, auditBefore:{quantity:60, status:'disponivel'},  auditAfter:{quantity:25,  status:'disponivel'} },
  { id:'mov-sai-leite-001a',    productId:'prod-leite',      productName:'Leite em Pó Integral',            batchId:'batch-leite-001',      type:'saida',          quantity:40,  reasonCode:'doacao',          reason:'Distribuição para famílias com crianças < 5 anos',      activity:'Distribuição Leite Jan', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(90),  isPendingSync:false, auditBefore:{quantity:100, status:'disponivel'},auditAfter:{quantity:60,  status:'disponivel'} },
  { id:'mov-sai-leite-001b',    productId:'prod-leite',      productName:'Leite em Pó Integral',            batchId:'batch-leite-001',      type:'saida',          quantity:40,  reasonCode:'doacao',          reason:'Distribuição para famílias com crianças < 5 anos',      activity:'Distribuição Leite Mar', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(60),  isPendingSync:false, auditBefore:{quantity:60, status:'disponivel'},  auditAfter:{quantity:20,  status:'disponivel'} },
  { id:'mov-sai-leite-002a',    productId:'prod-leite',      productName:'Leite em Pó Integral',            batchId:'batch-leite-002',      type:'saida',          quantity:10,  reasonCode:'doacao',          reason:'Distribuição emergencial',                              activity:'Distribuição Emergencial', performedBy:UID_VOL,      performedByName:'Ana Paula Santos',     performedAt:daysAgo(25),  isPendingSync:false, auditBefore:{quantity:50, status:'disponivel'},  auditAfter:{quantity:40,  status:'disponivel'} },
  { id:'mov-sai-sardinha-001a', productId:'prod-sardinha',   productName:'Sardinha em Lata ao Molho',       batchId:'batch-sardinha-001',   type:'saida',          quantity:60,  reasonCode:'doacao',          reason:'Distribuição mensal – Janeiro',                         activity:'Distribuição Janeiro',   performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(90),  isPendingSync:false, auditBefore:{quantity:200, status:'disponivel'},auditAfter:{quantity:140, status:'disponivel'} },
  { id:'mov-sai-sardinha-001b', productId:'prod-sardinha',   productName:'Sardinha em Lata ao Molho',       batchId:'batch-sardinha-001',   type:'saida',          quantity:60,  reasonCode:'doacao',          reason:'Distribuição mensal – Março',                           activity:'Distribuição Março',     performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(60),  isPendingSync:false, auditBefore:{quantity:140, status:'disponivel'},auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-sai-suco-001a',     productId:'prod-suco',       productName:'Suco de Uva Integral',            batchId:'batch-suco-001',       type:'saida',          quantity:150, reasonCode:'doacao',          reason:'Festa junina da ONG – distribuição integral',           activity:'Festa Junina',           performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(80),  isPendingSync:false, auditBefore:{quantity:150, status:'disponivel'},auditAfter:{quantity:0,   status:'distribuido'} },
  { id:'mov-sai-sabao-001a',    productId:'prod-sabao',      productName:'Sabão em Pó Concentrado',         batchId:'batch-sabao-001',      type:'saida',          quantity:15,  reasonCode:'doacao',          reason:'Distribuição Kit Limpeza Fevereiro',                    activity:'Distribuição Fevereiro', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(65),  isPendingSync:false, auditBefore:{quantity:40, status:'disponivel'},  auditAfter:{quantity:25,  status:'disponivel'} },
  { id:'mov-sai-sanitario-001a',productId:'prod-sanitario',  productName:'Água Sanitária',                  batchId:'batch-sanitario-001',  type:'saida',          quantity:12,  reasonCode:'doacao',          reason:'Distribuição Kit Limpeza Fevereiro',                    activity:'Distribuição Fevereiro', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(60),  isPendingSync:false, auditBefore:{quantity:30, status:'disponivel'},  auditAfter:{quantity:18,  status:'disponivel'} },
  { id:'mov-sai-detergente-001a',productId:'prod-detergente',productName:'Detergente Neutro Concentrado',   batchId:'batch-detergente-001', type:'saida',          quantity:4,   reasonCode:'doacao',          reason:'Distribuição Kit Limpeza Março',                        activity:'Distribuição Março',     performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(55),  isPendingSync:false, auditBefore:{quantity:24, status:'disponivel'},  auditAfter:{quantity:20,  status:'disponivel'} },
  { id:'mov-sai-sabonete-001a', productId:'prod-sabonete',   productName:'Sabonete Glicerinado',            batchId:'batch-sabonete-001',   type:'saida',          quantity:40,  reasonCode:'doacao',          reason:'Distribuição Kit Higiene Março/Abril',                  activity:'Distribuição Março',     performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(55),  isPendingSync:false, auditBefore:{quantity:84, status:'disponivel'},  auditAfter:{quantity:44,  status:'disponivel'} },
  { id:'mov-sai-shampoo-001a',  productId:'prod-shampoo',    productName:'Shampoo Suave Uso Diário',        batchId:'batch-shampoo-001',    type:'saida',          quantity:10,  reasonCode:'doacao',          reason:'Distribuição Kit Higiene Março',                        activity:'Distribuição Março',     performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(50),  isPendingSync:false, auditBefore:{quantity:30, status:'disponivel'},  auditAfter:{quantity:20,  status:'disponivel'} },
  { id:'mov-sai-dental-001a',   productId:'prod-dental',     productName:'Creme Dental com Flúor',          batchId:'batch-dental-001',     type:'saida',          quantity:8,   reasonCode:'doacao',          reason:'Distribuição Kit Higiene Março',                        activity:'Distribuição Março',     performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(50),  isPendingSync:false, auditBefore:{quantity:52, status:'disponivel'},  auditAfter:{quantity:44,  status:'disponivel'} },
  { id:'mov-sai-papel-001a',    productId:'prod-papel',      productName:'Papel Higiênico Folha Dupla',     batchId:'batch-papel-001',      type:'saida',          quantity:8,   reasonCode:'doacao',          reason:'Distribuição Kit Higiene Março',                        activity:'Distribuição Março',     performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(50),  isPendingSync:false, auditBefore:{quantity:32, status:'disponivel'},  auditAfter:{quantity:24,  status:'disponivel'} },
  { id:'mov-sai-fralda-001a',   productId:'prod-fralda',     productName:'Fralda Descartável Tamanho P',    batchId:'batch-fralda-001',     type:'saida',          quantity:10,  reasonCode:'doacao',          reason:'Distribuição famílias com bebês – Abril',               activity:'Distribuição Abril',     performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(30),  isPendingSync:false, auditBefore:{quantity:30, status:'disponivel'},  auditAfter:{quantity:20,  status:'disponivel'} },
  { id:'mov-sai-camiseta-001a', productId:'prod-camiseta',   productName:'Camiseta Infantil Unissex Tam. 8',batchId:'batch-camiseta-001',   type:'saida',          quantity:15,  reasonCode:'doacao',          reason:'Distribuição roupas Abril',                             activity:'Distribuição Roupas',    performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(25),  isPendingSync:false, auditBefore:{quantity:50, status:'disponivel'},  auditAfter:{quantity:35,  status:'disponivel'} },

  // ── AJUSTE NEGATIVO (referente a approval-feijao-001 aprovado) ─────────────
  { id:'mov-ajuste-feijao-001', productId:'prod-feijao',     productName:'Feijão Carioca',                  batchId:'batch-feijao-001',     type:'ajusteNegativo', quantity:10,  reasonCode:'ajusteInventario', reason:'Ajuste de inventário – avaria identificada na contagem', activity:null, performedBy:UID_ADMIN, performedByName:'Maria Fernanda Costa', performedAt:daysAgo(50), isPendingSync:false, auditBefore:{quantity:30, status:'disponivel'}, auditAfter:{quantity:20, status:'disponivel', reasonCode:'ajusteInventario'} },

  // ── ENTRADAS NOVOS PRODUTOS ALIMENTOS ────────────────────────────────────
  { id:'mov-ent-farinha-mandioca-001', productId:'prod-farinha-mandioca', productName:'Farinha de Mandioca Torrada',  batchId:'batch-farinha-mandioca-001', type:'entrada', quantity:60,  reasonCode:null, reason:'Doação excedente CEASA Campinas',        activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(95), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:60,  status:'disponivel'} },
  { id:'mov-ent-aveia-001',            productId:'prod-aveia',            productName:'Aveia em Flocos',              batchId:'batch-aveia-001',            type:'entrada', quantity:80,  reasonCode:null, reason:'Compra mensal',                          activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(90), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-ent-extrato-tomate-001',   productId:'prod-extrato-tomate',   productName:'Extrato de Tomate',            batchId:'batch-extrato-tomate-001',   type:'entrada', quantity:120, reasonCode:null, reason:'Parceria Supermercado BomPreço',          activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(85), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:120, status:'disponivel'} },
  { id:'mov-ent-milho-lata-001',       productId:'prod-milho-lata',       productName:'Milho Verde em Lata',          batchId:'batch-milho-lata-001',       type:'entrada', quantity:100, reasonCode:null, reason:'Doação Banco de Alimentos SP',            activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',   performedAt:daysAgo(80), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-ent-ervilha-lata-001',     productId:'prod-ervilha-lata',     productName:'Ervilha em Lata',              batchId:'batch-ervilha-lata-001',     type:'entrada', quantity:80,  reasonCode:null, reason:'Doação Banco de Alimentos SP',            activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',   performedAt:daysAgo(75), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-ent-biscoito-001',         productId:'prod-biscoito',         productName:'Biscoito Cream Cracker',       batchId:'batch-biscoito-001',         type:'entrada', quantity:150, reasonCode:null, reason:'Doação Paróquia São José',                activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',   performedAt:daysAgo(70), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:150, status:'disponivel'} },
  { id:'mov-ent-achocolatado-001',     productId:'prod-achocolatado',     productName:'Achocolatado em Pó',           batchId:'batch-achocolatado-001',     type:'entrada', quantity:50,  reasonCode:null, reason:'Compra NutriLife Alimentos',              activity:null, performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa',performedAt:daysAgo(65), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:50,  status:'disponivel'} },
  { id:'mov-ent-fuba-001',             productId:'prod-fuba',             productName:'Fubá de Milho',                batchId:'batch-fuba-001',             type:'entrada', quantity:80,  reasonCode:null, reason:'Doação excedente CEASA Campinas',        activity:null, performedBy:UID_VOL,        performedByName:'Ana Paula Santos',   performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-ent-sal-001',              productId:'prod-sal',              productName:'Sal Refinado Iodado',          batchId:'batch-sal-001',              type:'entrada', quantity:100, reasonCode:null, reason:'Compra mensal',                          activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(55), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:100, status:'disponivel'} },
  { id:'mov-ent-cafe-001',             productId:'prod-cafe',             productName:'Café Torrado e Moído',         batchId:'batch-cafe-001',             type:'entrada', quantity:60,  reasonCode:null, reason:'Parceria Cafeteria Sabor da Serra',       activity:null, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(50), isPendingSync:false, auditBefore:{quantity:0,  status:'disponivel'}, auditAfter:{quantity:60,  status:'disponivel'} },

  // ── SAÍDAS DIRETAS NOVOS PRODUTOS ─────────────────────────────────────────
  { id:'mov-sai-farinha-mandioca-001a', productId:'prod-farinha-mandioca', productName:'Farinha de Mandioca Torrada',  batchId:'batch-farinha-mandioca-001', type:'saida', quantity:25, reasonCode:'doacao', reason:'Distribuição Kit Alimentar Fevereiro',   activity:'Distribuição Fevereiro',  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(70), isPendingSync:false, auditBefore:{quantity:60,  status:'disponivel'}, auditAfter:{quantity:35,  status:'disponivel'} },
  { id:'mov-sai-aveia-001a',            productId:'prod-aveia',            productName:'Aveia em Flocos',              batchId:'batch-aveia-001',            type:'saida', quantity:30, reasonCode:'doacao', reason:'Distribuição para famílias com crianças', activity:'Distribuição Março',      performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(65), isPendingSync:false, auditBefore:{quantity:80,  status:'disponivel'}, auditAfter:{quantity:50,  status:'disponivel'} },
  { id:'mov-sai-extrato-tomate-001a',   productId:'prod-extrato-tomate',   productName:'Extrato de Tomate',            batchId:'batch-extrato-tomate-001',   type:'saida', quantity:50, reasonCode:'doacao', reason:'Distribuição Cesta Básica Março',         activity:'Distribuição Março',      performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:120, status:'disponivel'}, auditAfter:{quantity:70,  status:'disponivel'} },
  { id:'mov-sai-milho-lata-001a',       productId:'prod-milho-lata',       productName:'Milho Verde em Lata',          batchId:'batch-milho-lata-001',       type:'saida', quantity:40, reasonCode:'doacao', reason:'Distribuição Cesta Básica Março',         activity:'Distribuição Março',      performedBy:UID_VOL,        performedByName:'Ana Paula Santos',    performedAt:daysAgo(55), isPendingSync:false, auditBefore:{quantity:100, status:'disponivel'}, auditAfter:{quantity:60,  status:'disponivel'} },
  { id:'mov-sai-ervilha-lata-001a',     productId:'prod-ervilha-lata',     productName:'Ervilha em Lata',              batchId:'batch-ervilha-lata-001',     type:'saida', quantity:30, reasonCode:'doacao', reason:'Distribuição Cesta Básica Abril',         activity:'Distribuição Abril',      performedBy:UID_VOL,        performedByName:'Ana Paula Santos',    performedAt:daysAgo(50), isPendingSync:false, auditBefore:{quantity:80,  status:'disponivel'}, auditAfter:{quantity:50,  status:'disponivel'} },
  { id:'mov-sai-biscoito-001a',         productId:'prod-biscoito',         productName:'Biscoito Cream Cracker',       batchId:'batch-biscoito-001',         type:'saida', quantity:70, reasonCode:'doacao', reason:'Distribuição para crianças – evento ONG',  activity:'Evento ONG',              performedBy:UID_VOL,        performedByName:'Ana Paula Santos',    performedAt:daysAgo(45), isPendingSync:false, auditBefore:{quantity:150, status:'disponivel'}, auditAfter:{quantity:80,  status:'disponivel'} },
  { id:'mov-sai-achocolatado-001a',     productId:'prod-achocolatado',     productName:'Achocolatado em Pó',           batchId:'batch-achocolatado-001',     type:'saida', quantity:20, reasonCode:'doacao', reason:'Distribuição acompanhamento nutricional',  activity:'Acomp. Nutricional',      performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa',performedAt:daysAgo(40), isPendingSync:false, auditBefore:{quantity:50,  status:'disponivel'}, auditAfter:{quantity:30,  status:'disponivel'} },
  { id:'mov-sai-fuba-001a',             productId:'prod-fuba',             productName:'Fubá de Milho',                batchId:'batch-fuba-001',             type:'saida', quantity:30, reasonCode:'doacao', reason:'Distribuição Abril',                      activity:'Distribuição Abril',      performedBy:UID_VOL,        performedByName:'Ana Paula Santos',    performedAt:daysAgo(35), isPendingSync:false, auditBefore:{quantity:80,  status:'disponivel'}, auditAfter:{quantity:50,  status:'disponivel'} },
  { id:'mov-sai-sal-001a',              productId:'prod-sal',              productName:'Sal Refinado Iodado',          batchId:'batch-sal-001',              type:'saida', quantity:30, reasonCode:'doacao', reason:'Distribuição mensal – Abril',             activity:'Distribuição Abril',      performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(30), isPendingSync:false, auditBefore:{quantity:100, status:'disponivel'}, auditAfter:{quantity:70,  status:'disponivel'} },
  { id:'mov-sai-cafe-001a',             productId:'prod-cafe',             productName:'Café Torrado e Moído',         batchId:'batch-cafe-001',             type:'saida', quantity:20, reasonCode:'doacao', reason:'Distribuição Maio',                       activity:'Distribuição Maio',       performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(25), isPendingSync:false, auditBefore:{quantity:60,  status:'disponivel'}, auditAfter:{quantity:40,  status:'disponivel'} },

  // ── SAÍDAS POR RECEITA – Run 001: Cesta Grande x10 (dia -150) ─────────────
  { id:'mov-r001-arroz',    productId:'prod-arroz',    productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-001',    type:'saida', quantity:50, reasonCode:'receita', reason:'Cesta Básica Família Grande x10', activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(150), isPendingSync:false, auditBefore:{quantity:200,status:'disponivel'}, auditAfter:{quantity:150,status:'disponivel'} },
  { id:'mov-r001-feijao',   productId:'prod-feijao',   productName:'Feijão Carioca',                  batchId:'batch-feijao-001',   type:'saida', quantity:20, reasonCode:'receita', reason:'Cesta Básica Família Grande x10', activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(150), isPendingSync:false, auditBefore:{quantity:150,status:'disponivel'}, auditAfter:{quantity:130,status:'disponivel'} },
  { id:'mov-r001-oleo',     productId:'prod-oleo',     productName:'Óleo de Soja Refinado',           batchId:'batch-oleo-001',     type:'saida', quantity:10, reasonCode:'receita', reason:'Cesta Básica Família Grande x10', activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(150), isPendingSync:false, auditBefore:{quantity:60, status:'disponivel'}, auditAfter:{quantity:50, status:'disponivel'} },
  { id:'mov-r001-macarrao', productId:'prod-macarrao', productName:'Macarrão Espaguete',              batchId:'batch-macarrao-001', type:'saida', quantity:20, reasonCode:'receita', reason:'Cesta Básica Família Grande x10', activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(150), isPendingSync:false, auditBefore:{quantity:200,status:'disponivel'}, auditAfter:{quantity:180,status:'disponivel'} },
  { id:'mov-r001-farinha',  productId:'prod-farinha',  productName:'Farinha de Trigo Especial',       batchId:'batch-farinha-001',  type:'saida', quantity:10, reasonCode:'receita', reason:'Cesta Básica Família Grande x10', activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(150), isPendingSync:false, auditBefore:{quantity:100,status:'disponivel'}, auditAfter:{quantity:90, status:'disponivel'} },
  { id:'mov-r001-acucar',   productId:'prod-acucar',   productName:'Açúcar Cristal',                  batchId:'batch-acucar-001',   type:'saida', quantity:10, reasonCode:'receita', reason:'Cesta Básica Família Grande x10', activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(150), isPendingSync:false, auditBefore:{quantity:80, status:'disponivel'}, auditAfter:{quantity:70, status:'disponivel'} },

  // ── SAÍDAS POR RECEITA – Run 002: Cesta Pequena x15 (dia -120) ───────────
  { id:'mov-r002-arroz',    productId:'prod-arroz',    productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-001',    type:'saida', quantity:30, reasonCode:'receita', reason:'Cesta Básica Família Pequena x15', activity:'Cesta Básica Família Pequena', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(120), isPendingSync:false, auditBefore:{quantity:150,status:'disponivel'}, auditAfter:{quantity:120,status:'disponivel'} },
  { id:'mov-r002-feijao',   productId:'prod-feijao',   productName:'Feijão Carioca',                  batchId:'batch-feijao-001',   type:'saida', quantity:15, reasonCode:'receita', reason:'Cesta Básica Família Pequena x15', activity:'Cesta Básica Família Pequena', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(120), isPendingSync:false, auditBefore:{quantity:130,status:'disponivel'}, auditAfter:{quantity:115,status:'disponivel'} },
  { id:'mov-r002-macarrao', productId:'prod-macarrao', productName:'Macarrão Espaguete',              batchId:'batch-macarrao-001', type:'saida', quantity:15, reasonCode:'receita', reason:'Cesta Básica Família Pequena x15', activity:'Cesta Básica Família Pequena', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(120), isPendingSync:false, auditBefore:{quantity:180,status:'disponivel'}, auditAfter:{quantity:165,status:'disponivel'} },

  // ── SAÍDAS POR RECEITA – Run 003: Kit Higiene x8 (dia -80) ───────────────
  { id:'mov-r003-sabonete', productId:'prod-sabonete', productName:'Sabonete Glicerinado',            batchId:'batch-sabonete-001', type:'saida', quantity:16, reasonCode:'receita', reason:'Kit de Higiene Pessoal x8',       activity:'Kit de Higiene Pessoal',      performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(80), isPendingSync:false, auditBefore:{quantity:100,status:'disponivel'}, auditAfter:{quantity:84, status:'disponivel'} },
  { id:'mov-r003-dental',   productId:'prod-dental',   productName:'Creme Dental com Flúor',          batchId:'batch-dental-001',   type:'saida', quantity:8,  reasonCode:'receita', reason:'Kit de Higiene Pessoal x8',       activity:'Kit de Higiene Pessoal',      performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(80), isPendingSync:false, auditBefore:{quantity:60, status:'disponivel'}, auditAfter:{quantity:52, status:'disponivel'} },
  { id:'mov-r003-papel',    productId:'prod-papel',    productName:'Papel Higiênico Folha Dupla',     batchId:'batch-papel-001',    type:'saida', quantity:8,  reasonCode:'receita', reason:'Kit de Higiene Pessoal x8',       activity:'Kit de Higiene Pessoal',      performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(80), isPendingSync:false, auditBefore:{quantity:40, status:'disponivel'}, auditAfter:{quantity:32, status:'disponivel'} },

  // ── SAÍDAS POR RECEITA – Run 004: Cesta Grande x8 (dia -60) ─────────────
  { id:'mov-r004-arroz',    productId:'prod-arroz',    productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-001',    type:'saida', quantity:40, reasonCode:'receita', reason:'Cesta Básica Família Grande x8',  activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:85, status:'disponivel'}, auditAfter:{quantity:45, status:'disponivel'} },
  { id:'mov-r004-feijao',   productId:'prod-feijao',   productName:'Feijão Carioca',                  batchId:'batch-feijao-001',   type:'saida', quantity:20, reasonCode:'receita', reason:'Cesta Básica Família Grande x8',  activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:30, status:'disponivel'}, auditAfter:{quantity:10, status:'disponivel'} },
  { id:'mov-r004-oleo',     productId:'prod-oleo',     productName:'Óleo de Soja Refinado',           batchId:'batch-oleo-001',     type:'saida', quantity:8,  reasonCode:'receita', reason:'Cesta Básica Família Grande x8',  activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:23, status:'disponivel'}, auditAfter:{quantity:15, status:'disponivel'} },
  { id:'mov-r004-macarrao', productId:'prod-macarrao', productName:'Macarrão Espaguete',              batchId:'batch-macarrao-001', type:'saida', quantity:16, reasonCode:'receita', reason:'Cesta Básica Família Grande x8',  activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:66, status:'disponivel'}, auditAfter:{quantity:50, status:'disponivel'} },
  { id:'mov-r004-farinha',  productId:'prod-farinha',  productName:'Farinha de Trigo Especial',       batchId:'batch-farinha-001',  type:'saida', quantity:10, reasonCode:'receita', reason:'Cesta Básica Família Grande x8',  activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:40, status:'disponivel'}, auditAfter:{quantity:30, status:'disponivel'} },
  { id:'mov-r004-acucar',   productId:'prod-acucar',   productName:'Açúcar Cristal',                  batchId:'batch-acucar-001',   type:'saida', quantity:8,  reasonCode:'receita', reason:'Cesta Básica Família Grande x8',  activity:'Cesta Básica Família Grande', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60), isPendingSync:false, auditBefore:{quantity:33, status:'disponivel'}, auditAfter:{quantity:25, status:'disponivel'} },

  // ── SAÍDAS POR RECEITA – Run 005: Kit Escolar x12 (dia -40) ─────────────
  { id:'mov-r005-caderno',  productId:'prod-caderno',  productName:'Caderno Universitário 96 Folhas', batchId:'batch-caderno-001',  type:'saida', quantity:24, reasonCode:'receita', reason:'Kit Escolar Criança x12',         activity:'Kit Escolar Criança',         performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(40), isPendingSync:false, auditBefore:{quantity:80, status:'disponivel'}, auditAfter:{quantity:56, status:'disponivel'} },
  { id:'mov-r005-lapis',    productId:'prod-lapis',    productName:'Lápis de Cor 12 Cores',           batchId:'batch-lapis-001',    type:'saida', quantity:12, reasonCode:'receita', reason:'Kit Escolar Criança x12',         activity:'Kit Escolar Criança',         performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(40), isPendingSync:false, auditBefore:{quantity:40, status:'disponivel'}, auditAfter:{quantity:28, status:'disponivel'} },

  // ── SAÍDAS POR RECEITA – Run 006: Cesta Pequena x10 (dia -20) ────────────
  { id:'mov-r006-arroz',    productId:'prod-arroz',    productName:'Arroz Branco Tipo 1',            batchId:'batch-arroz-002',    type:'saida', quantity:20, reasonCode:'receita', reason:'Cesta Básica Família Pequena x10', activity:'Cesta Básica Família Pequena', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(20), isPendingSync:false, auditBefore:{quantity:150,status:'disponivel'}, auditAfter:{quantity:130,status:'disponivel'} },
  { id:'mov-r006-feijao',   productId:'prod-feijao',   productName:'Feijão Carioca',                  batchId:'batch-feijao-002',   type:'saida', quantity:10, reasonCode:'receita', reason:'Cesta Básica Família Pequena x10', activity:'Cesta Básica Família Pequena', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(20), isPendingSync:false, auditBefore:{quantity:100,status:'disponivel'}, auditAfter:{quantity:90, status:'disponivel'} },
  { id:'mov-r006-macarrao', productId:'prod-macarrao', productName:'Macarrão Espaguete',              batchId:'batch-macarrao-002', type:'saida', quantity:10, reasonCode:'receita', reason:'Cesta Básica Família Pequena x10', activity:'Cesta Básica Família Pequena', performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(20), isPendingSync:false, auditBefore:{quantity:150,status:'disponivel'}, auditAfter:{quantity:140,status:'disponivel'} },
];

// ═════════════════════════════════════════════════════════════════════════════
// 7. RECIPE RUNS
// ═════════════════════════════════════════════════════════════════════════════
const RECIPE_RUNS = [
  { id:'run-001', recipeId:'recipe-cesta-grande',  recipeName:'Cesta Básica Família Grande',  multiplier:10, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(150),
    movements:[{productId:'prod-arroz',productName:'Arroz Branco Tipo 1',batchId:'batch-arroz-001',consumed:50},{productId:'prod-feijao',productName:'Feijão Carioca',batchId:'batch-feijao-001',consumed:20},{productId:'prod-oleo',productName:'Óleo de Soja Refinado',batchId:'batch-oleo-001',consumed:10},{productId:'prod-macarrao',productName:'Macarrão Espaguete',batchId:'batch-macarrao-001',consumed:20},{productId:'prod-farinha',productName:'Farinha de Trigo Especial',batchId:'batch-farinha-001',consumed:10},{productId:'prod-acucar',productName:'Açúcar Cristal',batchId:'batch-acucar-001',consumed:10}] },
  { id:'run-002', recipeId:'recipe-cesta-pequena', recipeName:'Cesta Básica Família Pequena', multiplier:15, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(120),
    movements:[{productId:'prod-arroz',productName:'Arroz Branco Tipo 1',batchId:'batch-arroz-001',consumed:30},{productId:'prod-feijao',productName:'Feijão Carioca',batchId:'batch-feijao-001',consumed:15},{productId:'prod-macarrao',productName:'Macarrão Espaguete',batchId:'batch-macarrao-001',consumed:15}] },
  { id:'run-003', recipeId:'recipe-kit-higiene',   recipeName:'Kit de Higiene Pessoal',       multiplier:8,  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(80),
    movements:[{productId:'prod-sabonete',productName:'Sabonete Glicerinado',batchId:'batch-sabonete-001',consumed:16},{productId:'prod-dental',productName:'Creme Dental com Flúor',batchId:'batch-dental-001',consumed:8},{productId:'prod-papel',productName:'Papel Higiênico Folha Dupla',batchId:'batch-papel-001',consumed:8}] },
  { id:'run-004', recipeId:'recipe-cesta-grande',  recipeName:'Cesta Básica Família Grande',  multiplier:8,  performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(60),
    movements:[{productId:'prod-arroz',productName:'Arroz Branco Tipo 1',batchId:'batch-arroz-001',consumed:40},{productId:'prod-feijao',productName:'Feijão Carioca',batchId:'batch-feijao-001',consumed:16},{productId:'prod-oleo',productName:'Óleo de Soja Refinado',batchId:'batch-oleo-001',consumed:8},{productId:'prod-macarrao',productName:'Macarrão Espaguete',batchId:'batch-macarrao-001',consumed:16},{productId:'prod-farinha',productName:'Farinha de Trigo Especial',batchId:'batch-farinha-001',consumed:8},{productId:'prod-acucar',productName:'Açúcar Cristal',batchId:'batch-acucar-001',consumed:8}] },
  { id:'run-005', recipeId:'recipe-kit-escolar',   recipeName:'Kit Escolar Criança',          multiplier:12, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(40),
    movements:[{productId:'prod-caderno',productName:'Caderno Universitário 96 Folhas',batchId:'batch-caderno-001',consumed:24},{productId:'prod-lapis',productName:'Lápis de Cor 12 Cores',batchId:'batch-lapis-001',consumed:12}] },
  { id:'run-006', recipeId:'recipe-cesta-pequena', recipeName:'Cesta Básica Família Pequena', multiplier:10, performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira', performedAt:daysAgo(20),
    movements:[{productId:'prod-arroz',productName:'Arroz Branco Tipo 1',batchId:'batch-arroz-002',consumed:20},{productId:'prod-feijao',productName:'Feijão Carioca',batchId:'batch-feijao-002',consumed:10},{productId:'prod-macarrao',productName:'Macarrão Espaguete',batchId:'batch-macarrao-002',consumed:10}] },
];

// ═════════════════════════════════════════════════════════════════════════════
// 8. ALERTS
// ═════════════════════════════════════════════════════════════════════════════
const ALERTS = [
  { id:'alert-leite-critical', productId:'prod-leite', productName:'Leite em Pó Integral', batchId:'batch-leite-001', level:'critical', message:`Lote CC-LEI-001 vence em 5 dias (${daysFromNow(5).slice(0,10)}). Distribua com urgência!`, createdAt:Timestamp.now(), resolved:false },
  { id:'alert-leite-warning',  productId:'prod-leite', productName:'Leite em Pó Integral', batchId:'batch-leite-002', level:'warning',  message:`Lote CC-LEI-002 vence em 20 dias (${daysFromNow(20).slice(0,10)}). Fique atento.`,       createdAt:Timestamp.now(), resolved:false },
];

// ═════════════════════════════════════════════════════════════════════════════
// 9. ADJUSTMENT APPROVALS
// ═════════════════════════════════════════════════════════════════════════════
const APPROVALS = [
  // pending — ainda não executado
  { id:'approval-macarrao-001',
    productId:'prod-macarrao', productName:'Macarrão Espaguete',
    batchId:'batch-macarrao-001', quantity:15,
    requestedBy:UID_ESTOQUISTA, requestedByName:'João Pedro Oliveira',
    reason:'Contagem revelou 15 pacotes danificados por umidade na prateleira',
    status:'pending',
    reviewedBy:null, reviewedByName:null, reviewedAt:null,
    createdAt:daysAgo(3) },
  // approved — já executado (movimento mov-ajuste-feijao-001 corresponde)
  { id:'approval-feijao-001',
    productId:'prod-feijao', productName:'Feijão Carioca',
    batchId:'batch-feijao-001', quantity:10,
    requestedBy:UID_ESTOQUISTA, requestedByName:'João Pedro Oliveira',
    reason:'Inventário detectou 10 kg vencidos e fora das condições de consumo',
    status:'approved',
    reviewedBy:UID_ADMIN, reviewedByName:'Maria Fernanda Costa', reviewedAt:daysAgo(49),
    createdAt:daysAgo(51) },
];

// ═════════════════════════════════════════════════════════════════════════════
// 10. AUDIT LOGS
// ═════════════════════════════════════════════════════════════════════════════
const AUDIT_LOGS = [
  { id:'audit-001', collection:'users',               documentId:UID_VOL,             action:'create',          before:null, after:{role:'voluntario',isActive:true},                                  performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(120) },
  { id:'audit-002', collection:'users',               documentId:UID_CONSULTA,        action:'create',          before:null, after:{role:'consulta',isActive:true},                                    performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(90)  },
  { id:'audit-003', collection:'batches',             documentId:'batch-leite-001',   action:'entrada',         before:null, after:{quantity:100,status:'disponivel'},                                 performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(120) },
  { id:'audit-004', collection:'batches',             documentId:'batch-suco-001',    action:'saida',           before:{quantity:150,status:'disponivel'}, after:{quantity:0,status:'distribuido'},   performedBy:UID_VOL,        performedByName:'Ana Paula Santos',     performedAt:daysAgo(80)  },
  { id:'audit-005', collection:'adjustment_approvals',documentId:'approval-feijao-001', action:'approved',     before:{status:'pending'}, after:{status:'approved',reviewedBy:UID_ADMIN},             performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(49)  },
  { id:'audit-006', collection:'batches',             documentId:'batch-feijao-001',  action:'ajusteNegativo',  before:{quantity:30,status:'disponivel'}, after:{quantity:20,status:'disponivel'},    performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(50)  },
  { id:'audit-007', collection:'recipe_runs',         documentId:'run-001',           action:'recipe_run',      before:null, after:{recipeId:'recipe-cesta-grande',multiplier:10},                    performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(150) },
  { id:'audit-008', collection:'recipe_runs',         documentId:'run-003',           action:'recipe_run',      before:null, after:{recipeId:'recipe-kit-higiene',multiplier:8},                      performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(80)  },
  { id:'audit-009', collection:'recipe_runs',         documentId:'run-005',           action:'recipe_run',      before:null, after:{recipeId:'recipe-kit-escolar',multiplier:12},                     performedBy:UID_ESTOQUISTA, performedByName:'João Pedro Oliveira',  performedAt:daysAgo(40)  },
  { id:'audit-010', collection:'users',               documentId:UID_ESTOQUISTA,      action:'role_update',     before:{role:'voluntario'}, after:{role:'estoquista'},                                performedBy:UID_ADMIN,      performedByName:'Maria Fernanda Costa', performedAt:daysAgo(174) },
];

// ═════════════════════════════════════════════════════════════════════════════
// 11. SETTINGS
// ═════════════════════════════════════════════════════════════════════════════
const SETTINGS = {
  alerts: {
    criticalDays: 7,
    warningDays: 30,
    expiryEnabled: true,
    silentModeEnabled: false,
    silentFrom: null,
    silentUntil: null,
  },
  stock_rules: {
    negativeAdjustmentApprovalLimit: 10,
  },
  report_schedule: {
    enabled: true,
    recipientEmail: 'maria.fernanda@casadacrianca.org.br',
    dayOfWeek: 1,
    sendTime: '08:00',
  },
};

const SETTINGS_CATEGORIES = [
  { id:'alimento',        label:'Alimento',        isActive:true },
  { id:'bebida',          label:'Bebida',           isActive:true },
  { id:'limpeza',         label:'Limpeza',          isActive:true },
  { id:'higienePessoal',  label:'Higiene Pessoal',  isActive:true },
  { id:'escolar',         label:'Escolar',          isActive:true },
  { id:'roupas',          label:'Roupas',            isActive:true },
  { id:'outro',           label:'Outro',            isActive:true },
];

// ═════════════════════════════════════════════════════════════════════════════
// FUNÇÕES DE SEED
// ═════════════════════════════════════════════════════════════════════════════

async function seedCollection(collectionName, docs, idField = 'id', dataField = null) {
  const b = db.batch();
  for (const doc of docs) {
    const ref = db.collection(collectionName).doc(doc[idField]);
    b.set(ref, dataField ? doc[dataField] : (() => { const { id, ...rest } = doc; return rest; })());
  }
  await b.commit();
  return docs.length;
}

async function seedBatches() {
  const b = db.batch();
  for (const batch of BATCHES) {
    const { id, ...data } = batch;
    b.set(db.collection('batches').doc(id), data);
  }
  await b.commit();
  return BATCHES.length;
}

async function seedMovements() {
  // Split em 2 batches para evitar limite de 500
  const chunk1 = MOVEMENTS.slice(0, 250);
  const chunk2 = MOVEMENTS.slice(250);
  const b1 = db.batch();
  for (const m of chunk1) { const { id, ...d } = m; b1.set(db.collection('stock_movements').doc(id), d); }
  await b1.commit();
  if (chunk2.length > 0) {
    const b2 = db.batch();
    for (const m of chunk2) { const { id, ...d } = m; b2.set(db.collection('stock_movements').doc(id), d); }
    await b2.commit();
  }
  return MOVEMENTS.length;
}

async function seedRecipes() {
  const b = db.batch();
  for (const r of RECIPES) { const { id, ...d } = r; b.set(db.collection('recipes').doc(id), d); }
  await b.commit();
  return RECIPES.length;
}

async function seedRecipeRuns() {
  const b = db.batch();
  for (const r of RECIPE_RUNS) { const { id, ...d } = r; b.set(db.collection('recipe_runs').doc(id), d); }
  await b.commit();
  return RECIPE_RUNS.length;
}

async function seedSettings() {
  const b = db.batch();
  for (const [docId, data] of Object.entries(SETTINGS)) {
    b.set(db.collection('settings').doc(docId), data);
  }
  for (const cat of SETTINGS_CATEGORIES) {
    const { id, ...data } = cat;
    b.set(db.collection('settings_categories').doc(id), data);
  }
  await b.commit();
  return Object.keys(SETTINGS).length + SETTINGS_CATEGORIES.length;
}

async function seedSimple(collectionName, docs) {
  const b = db.batch();
  for (const doc of docs) { const { id, ...d } = doc; b.set(db.collection(collectionName).doc(id), d); }
  await b.commit();
  return docs.length;
}


// ═════════════════════════════════════════════════════════════════════════════
// PORTAL DO DOADOR (Sprint 5): necessidades, ponto de recebimento e regras
// ═════════════════════════════════════════════════════════════════════════════
// Date (não ISO string) vira Timestamp no Firestore, igual ao que as funções gravam.
const dateAgo = (n) => new Date(Date.now() - n * 86_400_000);
const DONATION_NEEDS = [
  { id: 'need-leite',      source: 'manual', categoryId: 'alimento',       title: 'Leite integral 1 L',  unit: 'un', priority: 'critica', priorityRank: 1, suggestedQty: 150, pledgedQty: 30, remainingQty: 120, minShelfLifeDays: 60, isActive: true, updatedAt: dateAgo(0) },
  { id: 'need-arroz',      source: 'manual', categoryId: 'alimento',       title: 'Arroz tipo 1 · 5 kg', unit: 'un', priority: 'alta',    priorityRank: 2, suggestedQty: 60,  pledgedQty: 20, remainingQty: 40,  minShelfLifeDays: 90, isActive: true, updatedAt: dateAgo(1) },
  { id: 'need-detergente', source: 'manual', categoryId: 'limpeza',        title: 'Detergente 500 mL',   unit: 'un', priority: 'alta',    priorityRank: 2, suggestedQty: 60,  pledgedQty: 0,  remainingQty: 60,  minShelfLifeDays: 0,  isActive: true, updatedAt: dateAgo(2) },
  { id: 'need-sabonete',   source: 'manual', categoryId: 'higienePessoal', title: 'Sabonete em barra',   unit: 'un', priority: 'normal',  priorityRank: 3, suggestedQty: 80,  pledgedQty: 10, remainingQty: 70,  minShelfLifeDays: 0,  isActive: true, updatedAt: dateAgo(3) },
  { id: 'need-caderno',    source: 'manual', categoryId: 'escolar',        title: 'Caderno 96 folhas',   unit: 'un', priority: 'normal',  priorityRank: 3, suggestedQty: 50,  pledgedQty: 15, remainingQty: 35,  minShelfLifeDays: 0,  isActive: true, updatedAt: dateAgo(4) },
];

// weekday segue DateTime.weekday do Dart: 1 = segunda … 7 = domingo.
const DONATION_POINTS = [
  {
    id: 'ponto-sede',
    name: 'Sede da Casa da Criança',
    address: 'Endereço da sede (ajustar antes de publicar)',
    hours: [1, 2, 3, 4, 5].map((weekday) => ({ weekday, from: '09:00', to: '17:00' })).concat([{ weekday: 6, from: '09:00', to: '12:00' }]),
    contact: 'Contato da coordenação (ajustar)',
    instructions: 'Procure a recepção e informe o protocolo da doação.',
    isActive: true,
  },
];

const DONATION_RULES = {
  minShelfLifeDays: 30,
  maxOpenPledges: 3,
  maxItems: 20,
  blockedCategories: [],
};

async function seedDonationPortal() {
  const b = db.batch();
  for (const n of DONATION_NEEDS) { const { id, ...d } = n; b.set(db.collection('donation_needs').doc(id), d); }
  for (const p of DONATION_POINTS) { const { id, ...d } = p; b.set(db.collection('donation_points').doc(id), d); }
  b.set(db.collection('settings').doc('donation_rules'), DONATION_RULES);
  await b.commit();
  return DONATION_NEEDS.length + DONATION_POINTS.length + 1;
}

// ─── Main ────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n🌱  Iniciando seed do banco de dados EducaStock...\n');

  const counts = {};

  counts.users               = await seedSimple('users',               USERS);               console.log(`✅  users               → ${counts.users} documentos`);
  counts.products            = await seedSimple('products',            PRODUCTS);            console.log(`✅  products            → ${counts.products} documentos`);
  counts.storage_locations   = await seedSimple('storage_locations',   LOCATIONS);           console.log(`✅  storage_locations   → ${counts.storage_locations} documentos`);
  counts.batches             = await seedBatches();                                           console.log(`✅  batches             → ${counts.batches} documentos`);
  counts.stock_movements     = await seedMovements();                                         console.log(`✅  stock_movements     → ${counts.stock_movements} documentos`);
  counts.recipes             = await seedRecipes();                                           console.log(`✅  recipes             → ${counts.recipes} documentos`);
  counts.recipe_runs         = await seedRecipeRuns();                                        console.log(`✅  recipe_runs         → ${counts.recipe_runs} documentos`);
  counts.alerts              = await seedSimple('alerts',              ALERTS);              console.log(`✅  alerts              → ${counts.alerts} documentos`);
  counts.adjustment_approvals= await seedSimple('adjustment_approvals',APPROVALS);           console.log(`✅  adjustment_approvals→ ${counts.adjustment_approvals} documentos`);
  counts.audit_logs          = await seedSimple('audit_logs',          AUDIT_LOGS);          console.log(`✅  audit_logs          → ${counts.audit_logs} documentos`);
  counts.settings_and_cats   = await seedSettings();                                          console.log(`✅  settings + categories → ${counts.settings_and_cats} documentos`);
  counts.donation_portal     = await seedDonationPortal();                                    console.log(`✅  portal do doador (needs, points, rules) → ${counts.donation_portal} documentos`);

  const total = Object.values(counts).reduce((a, b) => a + b, 0);

  console.log('\n──────────────────────────────────────────────────────');
  console.log(`📦  Total de documentos inseridos: ${total}`);
  console.log('──────────────────────────────────────────────────────\n');

  console.log('⚠️  ATENÇÃO: os UIDs abaixo devem ter contas criadas no Firebase Auth:');
  for (const u of USERS) {
    console.log(`   • ${u.id}  →  ${u.email}  (${u.role})`);
  }
  console.log('\n   Use o Firebase Console ou o script set_admin.mjs para cada conta.\n');
}

main().catch((err) => {
  console.error('\n❌  Erro durante o seed:', err.message, '\n');
  process.exit(1);
});
