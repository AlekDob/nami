import { tool } from 'ai';
import { z } from 'zod';

// --- Nutritionist Diet Data (Doctor C Fertility for Roberta) ---
const COLAZIONE_OPTIONS = [
  'Te deteinato/caffe decaffeinato/tisana/150ml latte p.scremato zymil/150ml kefir + 3 fette biscottate fibrextra misura con composta PROBIOS/crema nocciole 100%',
  'Pancake (20g farina nocciole, 100ml albume, yogurt greco 2%)',
  '1 uovo cotto + 100g avocado',
  'Yogurt greco 5% bianco con granella nocciola/mandorle',
] as const;

const SPUNTINO_OPTIONS = [
  '20g parmareggio',
  '5 noci',
  '10 nocciole',
  '10 mandorle',
  '8 macadamia',
  '120g frutta (mela/pera/melone bianco/kiwi/arancia) + noci',
  '125g yogurt intero bianco',
] as const;

interface ProteinOption {
  name: string;
  tag: string;
}

const PROTEINS_FULL: ProteinOption[] = [
  { name: '180g pesce azzurro', tag: 'pesce' },
  { name: '100g tonno', tag: 'pesce' },
  { name: '100g salmone', tag: 'pesce' },
  { name: '2 uova cotte', tag: 'uova' },
  { name: '150g vitella', tag: 'carne_rossa' },
  { name: '150g manzo', tag: 'carne_rossa' },
  { name: '150g maiale', tag: 'carne_bianca' },
  { name: '150g pollo', tag: 'carne_bianca' },
  { name: '150g tacchino', tag: 'carne_bianca' },
  { name: '150g coniglio', tag: 'carne_bianca' },
  { name: '150g agnello', tag: 'carne_rossa' },
  { name: '100g prosciutto cotto', tag: 'affettato' },
  { name: '150g philadelphia/robiola', tag: 'latticini' },
  { name: '200g ricotta/fiocchi di latte', tag: 'latticini' },
  { name: '200g mozzarella', tag: 'latticini' },
];

const PROTEINS_HALF: ProteinOption[] = [
  { name: '100g pesce azzurro', tag: 'pesce' },
  { name: '60g tonno', tag: 'pesce' },
  { name: '60g salmone', tag: 'pesce' },
  { name: '1 uovo cotto', tag: 'uova' },
  { name: '80g pollo', tag: 'carne_bianca' },
  { name: '80g tacchino', tag: 'carne_bianca' },
  { name: '80g vitella', tag: 'carne_rossa' },
  { name: '100g ricotta', tag: 'latticini' },
  { name: '100g mozzarella', tag: 'latticini' },
];

const PRIMO_OPTIONS = [
  '60g pasta kamut',
  '60g pasta integrale',
  '60g riso venere',
  '60g farro',
  '60g quinoa',
  '60g cous cous',
] as const;

const LEGUME_OPTIONS = [
  '220g ceci cotti',
  '220g fagioli cotti',
  '220g lenticchie cotte',
] as const;

const CONDIMENTO = '2 cucchiai olio EVO';
// --- Frequency tracking types ---

interface WeeklyCounters {
  carneRossa: number;
  pesce: number;
  uova: number;
}

const MAX_WEEKLY: Readonly<WeeklyCounters> = {
  carneRossa: 2,
  pesce: 4,
  uova: 3,
};

const MIN_WEEKLY = { pesce: 3 } as const;

// --- Helper functions ---
function pickRandom<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function shuffled<T>(arr: readonly T[]): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function pickVerdura(recipes: string[]): string {
  if (recipes.length === 0) return 'Verdura cotta di stagione';
  return pickRandom(recipes);
}

function isProteinAllowed(
  tag: string,
  counters: WeeklyCounters,
): boolean {
  if (tag === 'carne_rossa') return counters.carneRossa < MAX_WEEKLY.carneRossa;
  if (tag === 'pesce') return counters.pesce < MAX_WEEKLY.pesce;
  if (tag === 'uova') return counters.uova < MAX_WEEKLY.uova;
  return true;
}

function trackProtein(tag: string, counters: WeeklyCounters): void {
  if (tag === 'carne_rossa') counters.carneRossa++;
  if (tag === 'pesce') counters.pesce++;
  if (tag === 'uova') counters.uova++;
}

function pickProtein(
  pool: ProteinOption[],
  counters: WeeklyCounters,
  preferPesce: boolean,
): ProteinOption {
  if (preferPesce) {
    const fish = pool.filter(
      (p) => p.tag === 'pesce' && isProteinAllowed(p.tag, counters),
    );
    if (fish.length > 0) return pickRandom(fish);
  }
  const allowed = pool.filter((p) => isProteinAllowed(p.tag, counters));
  if (allowed.length === 0) {
    // Fallback to latticini/carne_bianca (unlimited)
    const safe = pool.filter(
      (p) => p.tag === 'latticini' || p.tag === 'carne_bianca',
    );
    return pickRandom(safe.length > 0 ? safe : pool);
  }
  return pickRandom(allowed);
}

// --- Meal generation types ---
interface DayMeal {
  colazione: string;
  spuntino: string;
  pranzo: string;
  merenda: string;
  cena: string;
}

interface WeeklyPlan {
  weekStartDate: string;
  days: Array<{ dayName: string; date: string; meals: DayMeal }>;
  constraints: string[];
  counters: WeeklyCounters;
}

// --- Day name helper ---
const DAY_NAMES = [
  'Lunedi', 'Martedi', 'Mercoledi',
  'Giovedi', 'Venerdi', 'Sabato', 'Domenica',
] as const;

function addDays(dateStr: string, n: number): string {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + n);
  return d.toISOString().split('T')[0];
}

function getDayName(dateStr: string): string {
  const d = new Date(dateStr + 'T00:00:00');
  return DAY_NAMES[d.getDay() === 0 ? 6 : d.getDay() - 1];
}

// --- Pranzo builders (each under 20 lines) ---

function buildPranzoProteinOnly(
  counters: WeeklyCounters,
  veggies: string[],
  preferPesce: boolean,
): string {
  const protein = pickProtein(PROTEINS_FULL, counters, preferPesce);
  trackProtein(protein.tag, counters);
  const verdura = pickVerdura(veggies);
  return `${protein.name} + ${verdura} + 50g pane integrale | ${CONDIMENTO}`;
}

function buildPranzoPrimo(
  counters: WeeklyCounters,
  veggies: string[],
  preferPesce: boolean,
): string {
  const roll = Math.random();
  if (roll < 0.5) {
    const primo = pickRandom(PRIMO_OPTIONS);
    const verdura = pickVerdura(veggies);
    const protein = pickProtein(PROTEINS_HALF, counters, preferPesce);
    trackProtein(protein.tag, counters);
    return `${primo} con ${verdura} + ${protein.name} | ${CONDIMENTO}`;
  }
  if (roll < 0.75) {
    const verdura = pickVerdura(veggies);
    const protein = pickProtein(PROTEINS_HALF, counters, preferPesce);
    trackProtein(protein.tag, counters);
    return `250g minestrone/passato ${verdura} (no patate) + ${protein.name} + 50g pane integrale | ${CONDIMENTO}`;
  }
  return `Zuppa ${pickRandom(LEGUME_OPTIONS)} (no patate/pasta) | ${CONDIMENTO}`;
}

// --- Main plan generator ---
function generateWeeklyPlan(
  weekStartDate: string,
  veggies: string[],
): WeeklyPlan {
  const counters: WeeklyCounters = { carneRossa: 0, pesce: 0, uova: 0 };
  const proteinOnlyDays = new Set(shuffled([0, 1, 2, 3, 4, 5, 6]).slice(0, 2));
  const days: WeeklyPlan['days'] = [];

  for (let i = 0; i < 7; i++) {
    const date = addDays(weekStartDate, i);
    const needMoreFish = counters.pesce < MIN_WEEKLY.pesce && (6 - i) <= (MIN_WEEKLY.pesce - counters.pesce);

    const pranzo = proteinOnlyDays.has(i)
      ? buildPranzoProteinOnly(counters, veggies, needMoreFish)
      : buildPranzoPrimo(counters, veggies, needMoreFish);

    const cena = buildPranzoProteinOnly(counters, veggies, needMoreFish);

    days.push({
      dayName: getDayName(date),
      date,
      meals: {
        colazione: pickRandom(COLAZIONE_OPTIONS),
        spuntino: pickRandom(SPUNTINO_OPTIONS),
        pranzo,
        merenda: pickRandom(SPUNTINO_OPTIONS),
        cena,
      },
    });
  }

  return {
    weekStartDate,
    days,
    constraints: buildConstraintReminders(),
    counters,
  };
}

function buildConstraintReminders(): string[] {
  return [
    'Verdure DEVONO essere cotte o ben lavate + amuchina 15 min',
    'Limitate: patate, carote, barbabietole. Funghi max 150g',
    'VIETATI: curcuma, zafferano, zenzero',
    'VIETATI: formaggi molli (gorgonzola, brie, feta, taleggio, tomini)',
    'VIETATI: pate (anche vegetali)',
    'VIETATI: cibi crudi/semicrudi',
    'VIETATI: prodotti a base di fegato',
    'Pesce 3-4x/settimana (azzurro). NO molluschi/crostacei, NO tonno/pesce spada frequente',
    'Carne rossa max 2x/settimana',
    'Uova 2-3x/settimana, sempre cotte',
    'NO: dolci, alcol, aceto balsamico',
    'Cottura: piastra, forno, lessare',
    'Frutta max 1x/giorno, yogurt max 1x/giorno',
  ];
}

// --- Exported Tool ---

export const planWeeklyMeals = tool({
  description:
    'Generate a 7-day meal plan for Roberta (pregnant) following ' +
    'the Doctor C Fertility nutritionist diet. Optionally integrates ' +
    'Planter vegetable/side dish recipes as "verdura libera". ' +
    'Returns a structured weekly plan for review before shopping list.',
  inputSchema: z.object({
    weekStartDate: z
      .string()
      .describe('Start date of the week in YYYY-MM-DD format'),
    planterVegetableRecipes: z
      .array(z.string())
      .default([])
      .describe(
        'Optional list of Planter veggie recipe names to use as side dishes',
      ),
  }),
  execute: async ({ weekStartDate, planterVegetableRecipes }) => {
    try {
      const plan = generateWeeklyPlan(weekStartDate, planterVegetableRecipes);
      return { success: true, plan };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});
