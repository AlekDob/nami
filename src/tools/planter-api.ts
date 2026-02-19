import { tool } from 'ai';
import { z } from 'zod';
import { resolve } from 'path';
import { readFile, writeFile } from 'fs/promises';

const BASE_URL = 'https://api.planter.eco';
const FAMILY_ID = 'cltt39fzo0s20pn4595prcusf';
const COGNITO_URL = 'https://cognito-idp.eu-central-1.amazonaws.com/';
const COGNITO_CLIENT_ID = '5l4j5t9apvsls1hdcnt9pkjmic';

const TOKENS_PATH = resolve(
  process.env.DATA_DIR || './data',
  'planter',
  'tokens.json',
);

const VEGGIE_KEYWORDS = ['verdure', 'contorni', 'insalat', 'zupp', 'vellut'];

interface PlanterTokens {
  ACCESS_TOKEN_KEY: string;
  REFRESH_TOKEN_KEY: string;
}

interface PlanterMeal {
  type: string;
  recipeName: string;
  preparationTime: number;
  category: string;
  isVegetableRecipe: boolean;
}

interface PlanterDay {
  date: string;
  meals: PlanterMeal[];
}

async function loadTokens(): Promise<PlanterTokens> {
  const raw = await readFile(TOKENS_PATH, 'utf-8');
  return JSON.parse(raw) as PlanterTokens;
}

async function saveTokens(tokens: PlanterTokens): Promise<void> {
  await writeFile(TOKENS_PATH, JSON.stringify(tokens, null, 2), 'utf-8');
}

async function refreshAccessToken(
  refreshToken: string,
): Promise<string> {
  const res = await fetch(COGNITO_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-amz-json-1.1',
      'X-Amz-Target':
        'AWSCognitoIdentityProviderService.InitiateAuth',
    },
    body: JSON.stringify({
      AuthFlow: 'REFRESH_TOKEN_AUTH',
      ClientId: COGNITO_CLIENT_ID,
      AuthParameters: { REFRESH_TOKEN: refreshToken },
    }),
  });

  const data = (await res.json()) as Record<string, Record<string, string>>;
  const idToken = data?.AuthenticationResult?.IdToken;

  if (!idToken) {
    throw new Error('Token refresh failed: no IdToken in response');
  }

  return idToken;
}

async function planterFetch(
  path: string,
  retried = false,
): Promise<unknown> {
  const tokens = await loadTokens();

  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { Authorization: tokens.ACCESS_TOKEN_KEY },
    signal: AbortSignal.timeout(15000),
  });

  if (res.status === 401 && !retried) {
    const newToken = await refreshAccessToken(tokens.REFRESH_TOKEN_KEY);
    await saveTokens({ ...tokens, ACCESS_TOKEN_KEY: newToken });
    return planterFetch(path, true);
  }

  if (!res.ok) {
    throw new Error(`Planter API ${res.status}: ${await res.text()}`);
  }

  return res.json();
}

function isVegetableCategory(category: string): boolean {
  const lower = category.toLowerCase();
  return VEGGIE_KEYWORDS.some((kw) => lower.includes(kw));
}

function parseMealPlan(raw: unknown): PlanterDay[] {
  const data = raw as Record<string, unknown>;
  const persons = (data.Person || []) as Array<Record<string, unknown>>;
  const dayMap = new Map<string, PlanterMeal[]>();

  for (const person of persons) {
    const plan = person.Plan as Record<string, unknown> | undefined;
    if (!plan) continue;
    const days = (plan.days || []) as Array<Record<string, unknown>>;

    for (const day of days) {
      const date = String(day.date || '').slice(0, 10);
      const recipes = (day.planRecipe || []) as Array<Record<string, unknown>>;

      for (const pr of recipes) {
        const recipe = pr.recipe as Record<string, unknown> | undefined;
        if (!recipe) continue;
        const catObj = recipe.category as Record<string, string> | undefined;
        const category = catObj?.id || '';
        const meal: PlanterMeal = {
          type: String(pr.type || 'UNKNOWN'),
          recipeName: String(recipe.name || 'Unknown'),
          preparationTime: Number(recipe.preparationTime || 0),
          category,
          isVegetableRecipe: isVegetableCategory(
            category + ' ' + String(recipe.name || ''),
          ),
        };
        const existing = dayMap.get(date) || [];
        existing.push(meal);
        dayMap.set(date, existing);
      }
    }
  }

  return Array.from(dayMap.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, meals]) => ({ date, meals }));
}

// --- Tools ---

export const planterGetPlan = tool({
  description:
    'Get meal plan from Planter for a date range. ' +
    'Returns daily meals (breakfast, lunch, dinner, snacks) with recipes.',
  inputSchema: z.object({
    startDate: z
      .string()
      .describe('Start date in YYYY-MM-DD format'),
    endDate: z
      .string()
      .describe('End date in YYYY-MM-DD format'),
  }),
  execute: async ({ startDate, endDate }) => {
    try {
      const minDate = `${startDate}T00:00:00Z`;
      const maxDate = `${endDate}T00:00:00Z`;
      const path =
        `/plan/family/${FAMILY_ID}?minDate=${minDate}&maxDate=${maxDate}`;

      const raw = await planterFetch(path);
      const days = parseMealPlan(raw);

      return {
        success: true,
        familyId: FAMILY_ID,
        startDate,
        endDate,
        totalDays: days.length,
        days,
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const planterGetRecipeCategories = tool({
  description:
    'Get all recipe categories from Planter. ' +
    'Useful to understand what types of meals are available.',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      const raw = await planterFetch('/categories');
      const categories = raw as Array<Record<string, unknown>>;

      const parsed = categories.map((cat) => ({
        id: String(cat.id || ''),
        name: String(cat.name || ''),
        isVegetable: isVegetableCategory(String(cat.name || '')),
      }));

      return {
        success: true,
        totalCategories: parsed.length,
        categories: parsed,
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});
