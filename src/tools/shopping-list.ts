import { tool } from 'ai';
import { z } from 'zod';

// --- Ingredient parsing from meal strings ---

interface ShoppingItem {
  name: string;
  quantity: string;
  category: string;
}

const CATEGORY_MAP: Record<string, string> = {
  pesce: 'Pesce',
  tonno: 'Pesce',
  salmone: 'Pesce',
  pollo: 'Carne',
  tacchino: 'Carne',
  vitella: 'Carne',
  manzo: 'Carne',
  maiale: 'Carne',
  coniglio: 'Carne',
  agnello: 'Carne',
  prosciutto: 'Affettati',
  uova: 'Uova/Latticini',
  uovo: 'Uova/Latticini',
  mozzarella: 'Uova/Latticini',
  ricotta: 'Uova/Latticini',
  philadelphia: 'Uova/Latticini',
  robiola: 'Uova/Latticini',
  fiocchi: 'Uova/Latticini',
  yogurt: 'Uova/Latticini',
  latte: 'Uova/Latticini',
  kefir: 'Uova/Latticini',
  parmareggio: 'Uova/Latticini',
  pasta: 'Dispensa',
  riso: 'Dispensa',
  farro: 'Dispensa',
  quinoa: 'Dispensa',
  cous: 'Dispensa',
  pane: 'Dispensa',
  fette: 'Dispensa',
  olio: 'Dispensa',
  ceci: 'Dispensa',
  fagioli: 'Dispensa',
  lenticchie: 'Dispensa',
  nocciole: 'Frutta secca',
  noci: 'Frutta secca',
  mandorle: 'Frutta secca',
  macadamia: 'Frutta secca',
  avocado: 'Frutta/Verdura',
  frutta: 'Frutta/Verdura',
  mela: 'Frutta/Verdura',
  pera: 'Frutta/Verdura',
  melone: 'Frutta/Verdura',
  kiwi: 'Frutta/Verdura',
  arancia: 'Frutta/Verdura',
  verdura: 'Frutta/Verdura',
  minestrone: 'Frutta/Verdura',
  cavolfiore: 'Frutta/Verdura',
  spinaci: 'Frutta/Verdura',
  finocchi: 'Frutta/Verdura',
};

function categorize(name: string): string {
  const lower = name.toLowerCase();
  for (const [keyword, cat] of Object.entries(CATEGORY_MAP)) {
    if (lower.includes(keyword)) return cat;
  }
  return 'Altro';
}

function parseMealIngredients(meal: string): ShoppingItem[] {
  const items: ShoppingItem[] = [];
  // Split by + and | separators
  const parts = meal.split(/[+|]/).map((s) => s.trim());

  for (const part of parts) {
    if (!part) continue;
    // Match "150g pollo" or "2 uova" or "60g pasta kamut"
    const qtyMatch = part.match(/^(\d+\w*)\s+(.+)/);
    if (qtyMatch) {
      items.push({
        name: qtyMatch[2].trim(),
        quantity: qtyMatch[1],
        category: categorize(qtyMatch[2]),
      });
    } else {
      items.push({
        name: part,
        quantity: '',
        category: categorize(part),
      });
    }
  }
  return items;
}

interface AggregatedItem {
  name: string;
  totalQuantity: string;
  category: string;
  occurrences: number;
}

function aggregateItems(
  allItems: ShoppingItem[],
): AggregatedItem[] {
  const map = new Map<string, AggregatedItem>();

  for (const item of allItems) {
    const key = item.name.toLowerCase().replace(/\s+/g, ' ');
    const existing = map.get(key);
    if (existing) {
      existing.occurrences++;
      if (item.quantity) {
        existing.totalQuantity = mergeQuantities(
          existing.totalQuantity,
          item.quantity,
        );
      }
    } else {
      map.set(key, {
        name: item.name,
        totalQuantity: item.quantity,
        category: item.category,
        occurrences: 1,
      });
    }
  }

  return Array.from(map.values()).sort((a, b) =>
    a.category.localeCompare(b.category),
  );
}

function mergeQuantities(a: string, b: string): string {
  const numA = parseInt(a, 10);
  const numB = parseInt(b, 10);
  if (!isNaN(numA) && !isNaN(numB)) {
    const unitA = a.replace(/^\d+/, '');
    const unitB = b.replace(/^\d+/, '');
    if (unitA === unitB) return `${numA + numB}${unitA}`;
  }
  return a && b ? `${a} + ${b}` : a || b;
}

// --- Exported Tool ---

interface MealPlanDay {
  meals: {
    colazione: string;
    spuntino: string;
    pranzo: string;
    merenda: string;
    cena: string;
  };
}

export const generateShoppingList = tool({
  description:
    'Generate a shopping list from a weekly meal plan. ' +
    'Takes the plan output from planWeeklyMeals and extracts ' +
    'all ingredients, aggregated by category for Apple Reminders.',
  inputSchema: z.object({
    days: z
      .array(
        z.object({
          meals: z.object({
            colazione: z.string(),
            spuntino: z.string(),
            pranzo: z.string(),
            merenda: z.string(),
            cena: z.string(),
          }),
        }),
      )
      .describe('The days array from planWeeklyMeals output'),
    listName: z
      .string()
      .default('Spesa settimanale')
      .describe('Name for the shopping list'),
  }),
  execute: async ({ days, listName }) => {
    try {
      const allItems: ShoppingItem[] = [];

      for (const day of days as MealPlanDay[]) {
        const { colazione, spuntino, pranzo, merenda, cena } =
          day.meals;
        allItems.push(...parseMealIngredients(colazione));
        allItems.push(...parseMealIngredients(spuntino));
        allItems.push(...parseMealIngredients(pranzo));
        allItems.push(...parseMealIngredients(merenda));
        allItems.push(...parseMealIngredients(cena));
      }

      const aggregated = aggregateItems(allItems);

      // Group by category for display
      const byCategory = new Map<string, AggregatedItem[]>();
      for (const item of aggregated) {
        const list = byCategory.get(item.category) || [];
        list.push(item);
        byCategory.set(item.category, list);
      }

      const categories = Array.from(byCategory.entries()).map(
        ([category, items]) => ({
          category,
          items: items.map((i) => ({
            name: i.name,
            quantity: i.totalQuantity,
            count: i.occurrences,
          })),
        }),
      );

      return {
        success: true,
        listName,
        totalItems: aggregated.length,
        categories,
        // Flat list for Apple Reminders integration
        flatItems: aggregated.map((i) => ({
          title: i.totalQuantity
            ? `${i.totalQuantity} ${i.name}`
            : i.name,
          notes: `${i.category} (x${i.occurrences})`,
        })),
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});
