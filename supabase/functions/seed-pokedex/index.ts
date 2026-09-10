// seed-pokedex — popula a tabela `pokedex` (national dex 1..1025) a partir da PokéAPI.
//
// Roda sob demanda (idealmente 1×). Idempotente: faz upsert por national_dex_id,
// então pode ser reexecutado por faixa se algum lote falhar.
//
// Uso:
//   POST /functions/v1/seed-pokedex            -> faixa completa (1..1025)
//   POST /functions/v1/seed-pokedex?start=1&end=300
//
// region_id / generation saem do cruzamento com a tabela `regions` (faixas de
// national dex já populadas), não da PokéAPI.
//
// Requer Authorization: Bearer <service_role_key> (verify_jwt = true no deploy).

import { createClient } from "jsr:@supabase/supabase-js@2";

const POKEAPI = "https://pokeapi.co/api/v2";
const MAX_DEX = 1025;
const BATCH = 25; // requisições concorrentes por lote

type Region = { id: string; dex_start: number; dex_end: number; generation: number };

function regionFor(regions: Region[], dexId: number): Region | undefined {
  return regions.find((r) => dexId >= r.dex_start && dexId <= r.dex_end);
}

async function fetchPokemon(id: number) {
  const res = await fetch(`${POKEAPI}/pokemon/${id}`, {
    headers: { "Accept": "application/json" },
  });
  if (!res.ok) throw new Error(`pokeapi ${id} -> ${res.status}`);
  const j = await res.json();
  const types: string[] = (j.types ?? [])
    .sort((a: any, b: any) => a.slot - b.slot)
    .map((t: any) => t.type.name);
  const sprite: string | null =
    j.sprites?.other?.["official-artwork"]?.front_default ??
    j.sprites?.front_default ??
    null;
  return { national_dex_id: j.id as number, name: j.name as string, types, sprite_url: sprite };
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const start = Math.max(1, Number(url.searchParams.get("start") ?? 1));
  const end = Math.min(MAX_DEX, Number(url.searchParams.get("end") ?? MAX_DEX));

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const run = await supabase
    .from("sync_runs")
    .insert({ job: "seed-pokedex", detail: { start, end } })
    .select("id")
    .single();
  const runId = run.data?.id;

  const { data: regions, error: regErr } = await supabase
    .from("regions")
    .select("id, dex_start, dex_end, generation");
  if (regErr || !regions) {
    return new Response(JSON.stringify({ error: "sem regions", detail: regErr }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }

  let upserted = 0;
  let errors = 0;
  const failedIds: number[] = [];

  for (let lo = start; lo <= end; lo += BATCH) {
    const hi = Math.min(end, lo + BATCH - 1);
    const ids = Array.from({ length: hi - lo + 1 }, (_, i) => lo + i);
    const results = await Promise.allSettled(ids.map(fetchPokemon));

    const rows = [];
    for (let i = 0; i < results.length; i++) {
      const r = results[i];
      if (r.status !== "fulfilled") {
        errors++;
        failedIds.push(ids[i]);
        continue;
      }
      const p = r.value;
      const region = regionFor(regions as Region[], p.national_dex_id);
      rows.push({
        national_dex_id: p.national_dex_id,
        name: p.name,
        types: p.types,
        sprite_url: p.sprite_url,
        region_id: region?.id ?? null,
        generation: region?.generation ?? null,
        updated_at: new Date().toISOString(),
      });
    }

    if (rows.length) {
      const { error } = await supabase
        .from("pokedex")
        .upsert(rows, { onConflict: "national_dex_id" });
      if (error) {
        errors += rows.length;
        failedIds.push(...rows.map((x) => x.national_dex_id));
      } else {
        upserted += rows.length;
      }
    }
  }

  if (runId) {
    await supabase
      .from("sync_runs")
      .update({
        finished_at: new Date().toISOString(),
        rows_upserted: upserted,
        errors,
        detail: { start, end, failedIds },
      })
      .eq("id", runId);
  }

  return new Response(
    JSON.stringify({ start, end, upserted, errors, failedIds }),
    { headers: { "Content-Type": "application/json" } },
  );
});
