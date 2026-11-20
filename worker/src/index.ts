import { createRemoteJWKSet, jwtVerify, type JWTPayload } from "jose";

export interface Env {
  GEMINI_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
  GEMINI_MODEL: string;
}

class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const SHELF_LIFE_SCHEMA = {
  type: "OBJECT",
  properties: {
    room_temperature: { type: "INTEGER" },
    fridge: { type: "INTEGER" },
    freezer: { type: "INTEGER" },
  },
  required: ["room_temperature", "fridge", "freezer"],
} as const;

const ANALYZE_FOOD_SCHEMA = {
  type: "OBJECT",
  properties: {
    name: { type: "STRING" },
    category: { type: "STRING" },
    confidence: { type: "NUMBER" },
    visualCondition: { type: "STRING" },
    aiNote: { type: "STRING", nullable: true },
    shelfLifeDays: SHELF_LIFE_SCHEMA,
  },
  required: [
    "name",
    "category",
    "confidence",
    "visualCondition",
    "shelfLifeDays",
  ],
} as const;

const ANALYZE_BARCODE_SCHEMA = {
  type: "OBJECT",
  properties: {
    name: { type: "STRING" },
    category: { type: "STRING" },
    brand: { type: "STRING" },
    packageSize: { type: "STRING" },
    confidence: { type: "NUMBER" },
    shelfLifeDays: SHELF_LIFE_SCHEMA,
  },
  required: ["name", "category", "shelfLifeDays"],
} as const;

const RECIPE_ITEM_SCHEMA = {
  type: "OBJECT",
  properties: {
    recipeId: { type: "STRING" },
    name: { type: "STRING" },
    description: { type: "STRING" },
    cuisine: { type: "STRING" },
    cookingTechnique: { type: "STRING" },
    cookingTimeMinutes: { type: "INTEGER" },
    ingredientsAvailable: { type: "ARRAY", items: { type: "STRING" } },
    ingredientsMissing: { type: "ARRAY", items: { type: "STRING" } },
    equipment: { type: "ARRAY", items: { type: "STRING" } },
    steps: { type: "ARRAY", items: { type: "STRING" } },
  },
  required: [
    "recipeId",
    "name",
    "description",
    "cuisine",
    "cookingTechnique",
    "cookingTimeMinutes",
    "ingredientsAvailable",
    "ingredientsMissing",
    "equipment",
    "steps",
  ],
} as const;

const GENERATE_RECIPES_SCHEMA = {
  type: "OBJECT",
  properties: {
    recipes: { type: "ARRAY", items: RECIPE_ITEM_SCHEMA },
  },
  required: ["recipes"],
} as const;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    try {
      if (request.method !== "POST") {
        throw new ApiError(404, "NOT_FOUND", "Endpoint not found");
      }

      const user = await requireFirebaseUser(request, env);
      const path = new URL(request.url).pathname;

      if (path === "/analyze-food") {
        return json(await analyzeFood(request, env));
      }
      if (path === "/analyze-barcode") {
        return json(await analyzeBarcode(request, env));
      }
      if (path === "/generate-recipes") {
        return json(await generateRecipes(request, env));
      }

      throw new ApiError(404, "NOT_FOUND", "Endpoint not found");
    } catch (error) {
      return toErrorResponse(error);
    }
  },
} satisfies ExportedHandler<Env>;

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

async function requireFirebaseUser(
  request: Request,
  env: Env,
): Promise<JWTPayload> {
  const header = request.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new ApiError(401, "UNAUTHORIZED", "Missing bearer token");
  }

  try {
    const { payload } = await jwtVerify(match[1], FIREBASE_JWKS, {
      issuer: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
      audience: env.FIREBASE_PROJECT_ID,
    });

    if (!payload.sub) {
      throw new Error("Token has no subject");
    }

    return payload;
  } catch {
    throw new ApiError(401, "UNAUTHORIZED", "Invalid or expired token");
  }
}

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

async function analyzeFood(request: Request, env: Env) {
  const body = await readJson<{
    imageBase64?: unknown;
    mimeType?: unknown;
  }>(request);

  const imageBase64 = typeof body.imageBase64 === "string" ? body.imageBase64 : "";
  const mimeType = body.mimeType === "image/png" ? "image/png" : "image/jpeg";

  if (!imageBase64 || imageBase64.length > 1_400_000) {
    throw new ApiError(400, "INVALID_INPUT", "imageBase64 is required");
  }

  const result = await geminiJson<AnalyzeFoodResult>(
    env,
    [
      {
        text:
          "Identify the single food ingredient in this photo for a pantry app. " +
          "Return the common English name, a simple category " +
          "(Fruit, Vegetable, Dairy, Meat, Seafood, Grain, Spice, Other), " +
          "a confidence from 0 to 1, a short factual visual condition, " +
          "an optional note, and estimated shelf life in days for " +
          "room temperature, fridge, and freezer. " +
          "Shelf life must be whole days >= 1 and reflect typical storage of " +
          "an unopened, fresh item. Never invent a food that is not visible.",
      },
      {
        inlineData: {
          mimeType,
          data: imageBase64,
        },
      },
    ],
    ANALYZE_FOOD_SCHEMA,
  );

  validateShelfLife(result.shelfLifeDays);
  if (!result.name || !result.category) {
    throw new ApiError(500, "AI_FAILURE", "AI returned an incomplete result");
  }

  return {
    name: result.name.trim(),
    category: result.category.trim(),
    confidence: clampConfidence(result.confidence),
    visualCondition: result.visualCondition ?? "",
    aiNote: result.aiNote ? result.aiNote.trim() : null,
    shelfLifeDays: normalizeShelfLife(result.shelfLifeDays),
  };
}

async function analyzeBarcode(request: Request, env: Env) {
  const body = await readJson<{ barcode?: unknown }>(request);
  const barcode = typeof body.barcode === "string" ? body.barcode.trim() : "";

  if (!/^\d{8,14}$/.test(barcode)) {
    throw new ApiError(400, "INVALID_INPUT", "barcode must be 8-14 digits");
  }

  // Langkah 1: lookup produk dari katalog gratis Open Food Facts.
  let product: OpenFoodFactsProduct | null = null;
  try {
    const response = await fetch(
      `https://world.openfoodfacts.org/api/v2/product/${barcode}.json` +
        "?fields=product_name,brands,categories,quantity",
      {
        headers: { "User-Agent": "Optimeal/1.0 (competition project)" },
        signal: AbortSignal.timeout(15_000),
      },
    );
    if (response.ok) {
      const data = (await response.json()) as {
        status?: number;
        product?: OpenFoodFactsProduct;
      };
      if (data.status === 1 && data.product?.product_name) {
        product = data.product;
      }
    }
  } catch {
    // Lookup gagal karena jaringan; lanjut ke pesan 500 di bawah.
  }

  if (!product) {
    throw new ApiError(404, "NOT_FOUND", "Product not recognized");
  }

  // Langkah 2: minta Gemini mengklasifikasikan kategori dan estimasi masa simpan.
  const details = [
    `Product name: ${product.product_name}`,
    product.brands ? `Brand: ${product.brands}` : null,
    product.categories ? `Categories: ${product.categories}` : null,
    product.quantity ? `Package size: ${product.quantity}` : null,
  ]
    .filter(Boolean)
    .join("\n");

  const result = await geminiJson<AnalyzeBarcodeResult>(
    env,
    [
      {
        text:
          "You classify packaged food products for a pantry app. " +
          "Based on the product details below, return the common English " +
          "product name, one simple category (Dairy, Snack, Beverage, Grain, " +
          "Canned, Frozen, Spice, Other), brand, package size, a confidence " +
          "from 0 to 1, and estimated shelf life in days for room " +
          "temperature, fridge, and freezer. Shelf life is for an unopened " +
          "package and must be whole days >= 1.\n\n" +
          details,
      },
    ],
    ANALYZE_BARCODE_SCHEMA,
  );

  validateShelfLife(result.shelfLifeDays);

  return {
    name: (result.name || product.product_name || "").trim(),
    category: (result.category || "Other").trim(),
    brand: (result.brand || product.brands || "").trim(),
    packageSize: (result.packageSize || product.quantity || "").trim(),
    confidence: clampConfidence(result.confidence),
    shelfLifeDays: normalizeShelfLife(result.shelfLifeDays),
  };
}

async function generateRecipes(request: Request, env: Env) {
  const body = await readJson<{
    ingredients?: unknown;
    filters?: unknown;
    excludeRecipeIds?: unknown;
  }>(request);

  const ingredients = Array.isArray(body.ingredients)
    ? body.ingredients.filter(isIngredient)
    : [];

  if (ingredients.length === 0) {
    throw new ApiError(422, "EMPTY_INGREDIENTS", "Ingredient list is empty");
  }

  const filters =
    body.filters && typeof body.filters === "object"
      ? (body.filters as { cuisine?: unknown })
      : {};
  const cuisine =
    typeof filters.cuisine === "string" && filters.cuisine.trim()
      ? filters.cuisine.trim()
      : null;

  const excluded = Array.isArray(body.excludeRecipeIds)
    ? body.excludeRecipeIds.filter((id): id is string => typeof id === "string")
    : [];

  const ingredientLines = ingredients.map((item) => {
    const amount = [item.quantity ?? "", item.unit ?? ""].join(" ").trim();
    const location = item.storageLocation
      ? ` (stored in ${item.storageLocation})`
      : "";
    return `- ${item.name}${amount ? `: ${amount}` : ""}${location}`;
  });

  const result = await geminiJson<GenerateRecipesResult>(
    env,
    [
      {
        text:
          "You are a recipe assistant for a pantry app. Suggest 3 recipes " +
          "using the available ingredients below. Only these ingredients may " +
          "be listed in ingredientsAvailable; anything extra goes in " +
          "ingredientsMissing. " +
          (cuisine
            ? `All recipes must use ${cuisine} cuisine. `
            : "Use a mix of cuisines. ") +
          (excluded.length
            ? `Do not reuse these recipe ids: ${excluded.join(", ")}. `
            : "") +
          "Return an id that starts with r_ and is unique, cooking time in " +
          "whole minutes, and clear numbered steps. Do not claim the food is " +
          "safe to eat.\n\nAvailable ingredients:\n" +
          ingredientLines.join("\n"),
      },
    ],
    GENERATE_RECIPES_SCHEMA,
  );

  if (!Array.isArray(result.recipes) || result.recipes.length === 0) {
    throw new ApiError(500, "AI_FAILURE", "AI returned no recipes");
  }

  return {
    recipes: result.recipes.map((recipe) => ({
      ...recipe,
      recipeId: recipe.recipeId || `r_${crypto.randomUUID()}`,
      cookingTimeMinutes: Math.max(1, Math.round(recipe.cookingTimeMinutes)),
    })),
  };
}

// ---------------------------------------------------------------------------
// Gemini
// ---------------------------------------------------------------------------

async function geminiJson<T>(
  env: Env,
  parts: unknown[],
  schema: unknown,
): Promise<T> {
  let response: Response;
  try {
    response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_MODEL}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": env.GEMINI_API_KEY,
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts }],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: "application/json",
            responseSchema: schema,
          },
        }),
        signal: AbortSignal.timeout(55_000),
      },
    );
  } catch (error) {
    if (error instanceof Error && error.name === "TimeoutError") {
      throw new ApiError(504, "TIMEOUT", "AI request timed out");
    }
    throw new ApiError(500, "AI_FAILURE", "AI request failed");
  }

  if (response.status === 429) {
    throw new ApiError(429, "RATE_LIMITED", "AI quota reached");
  }
  if (!response.ok) {
    // Detail hanya masuk log Worker, tidak pernah dikirim ke client.
    const detail = await response.text().catch(() => "");
    console.error("Gemini failure", response.status, detail.slice(0, 500));
    throw new ApiError(500, "AI_FAILURE", "AI request failed");
  }

  const data = (await response.json()) as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
      finishReason?: string;
    }>;
  };

  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new ApiError(500, "AI_FAILURE", "AI returned an empty response");
  }

  try {
    return JSON.parse(text) as T;
  } catch {
    throw new ApiError(500, "AI_FAILURE", "AI returned invalid JSON");
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface IngredientInput {
  name: string;
  quantity?: number | null;
  unit?: string | null;
  storageLocation?: string | null;
}

interface ShelfLife {
  room_temperature: number;
  fridge: number;
  freezer: number;
}

interface AnalyzeFoodResult {
  name: string;
  category: string;
  confidence: number;
  visualCondition: string;
  aiNote?: string | null;
  shelfLifeDays: ShelfLife;
}

interface AnalyzeBarcodeResult {
  name: string;
  category: string;
  brand?: string;
  packageSize?: string;
  confidence: number;
  shelfLifeDays: ShelfLife;
}

interface GenerateRecipesResult {
  recipes: Array<{
    recipeId: string;
    name: string;
    description: string;
    cuisine: string;
    cookingTechnique: string;
    cookingTimeMinutes: number;
    ingredientsAvailable: string[];
    ingredientsMissing: string[];
    equipment: string[];
    steps: string[];
  }>;
}

interface OpenFoodFactsProduct {
  product_name?: string;
  brands?: string;
  categories?: string;
  quantity?: string;
}

function isIngredient(value: unknown): value is IngredientInput {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as { name?: unknown }).name === "string" &&
    (value as { name: string }).name.trim().length > 0
  );
}

async function readJson<T>(request: Request): Promise<T> {
  try {
    return (await request.json()) as T;
  } catch {
    throw new ApiError(400, "INVALID_INPUT", "Request body must be JSON");
  }
}

function validateShelfLife(value: ShelfLife | undefined): void {
  if (
    !value ||
    !Number.isInteger(value.room_temperature) ||
    !Number.isInteger(value.fridge) ||
    !Number.isInteger(value.freezer) ||
    value.room_temperature < 1 ||
    value.fridge < 1 ||
    value.freezer < 1
  ) {
    throw new ApiError(500, "AI_FAILURE", "AI returned invalid shelf life");
  }
}

function normalizeShelfLife(value: ShelfLife): ShelfLife {
  return {
    room_temperature: Math.round(value.room_temperature),
    fridge: Math.round(value.fridge),
    freezer: Math.round(value.freezer),
  };
}

function clampConfidence(value: unknown): number {
  const number = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.min(1, Math.max(0, number));
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}

function toErrorResponse(error: unknown): Response {
  if (error instanceof ApiError) {
    return json(
      { error: { code: error.code, message: error.message } },
      error.status,
    );
  }
  return json(
    { error: { code: "AI_FAILURE", message: "Unexpected server error" } },
    500,
  );
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}
