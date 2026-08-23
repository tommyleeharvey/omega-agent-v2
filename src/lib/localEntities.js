// Minimal localStorage-backed replacement for base44.entities

const readAll = (name) => {
  try {
    return JSON.parse(localStorage.getItem(`omega_${name}`) || "[]");
  } catch {
    return [];
  }
};

const writeAll = (name, arr) => {
  localStorage.setItem(`omega_${name}`, JSON.stringify(arr));
};

const uid = () => Math.random().toString(36).slice(2) + Date.now().toString(36);

const makeEntity = (name) => ({
  list: async (sort, limit) => {
    let items = readAll(name);
    if (sort) {
      const desc = sort.startsWith("-");
      const key = desc ? sort.slice(1) : sort;
      items = [...items].sort((a, b) => {
        const av = a[key], bv = b[key];
        if (av === bv) return 0;
        return desc ? (av < bv ? 1 : -1) : (av > bv ? 1 : -1);
      });
    }
    return limit ? items.slice(0, limit) : items;
  },
  filter: async (query = {}, sort, limit) => {
    let items = readAll(name).filter((item) =>
      Object.entries(query).every(([k, v]) => item[k] === v)
    );
    if (sort) {
      const desc = sort.startsWith("-");
      const key = desc ? sort.slice(1) : sort;
      items = [...items].sort((a, b) => {
        const av = a[key], bv = b[key];
        if (av === bv) return 0;
        return desc ? (av < bv ? 1 : -1) : (av > bv ? 1 : -1);
      });
    }
    return limit ? items.slice(0, limit) : items;
  },
  create: async (data) => {
    const items = readAll(name);
    const record = { id: uid(), created_date: new Date().toISOString(), ...data };
    items.push(record);
    writeAll(name, items);
    return record;
  },
  bulkCreate: async (dataArr) => {
    const items = readAll(name);
    const created = dataArr.map((data) => ({
      id: uid(),
      created_date: new Date().toISOString(),
      ...data,
    }));
    writeAll(name, [...items, ...created]);
    return created;
  },
  update: async (id, updates) => {
    const items = readAll(name);
    const idx = items.findIndex((i) => i.id === id);
    if (idx === -1) throw new Error(`${name} record not found: ${id}`);
    items[idx] = { ...items[idx], ...updates };
    writeAll(name, items);
    return items[idx];
  },
  delete: async (id) => {
    const items = readAll(name).filter((i) => i.id !== id);
    writeAll(name, items);
    return { success: true };
  },
  subscribe: (callback) => {
    return () => {};
  },
});

export const entities = new Proxy({}, {
  get: (_target, name) => makeEntity(name),
});

// --- Real backend call, replacing the old direct-from-browser Groq call ---
// No API key here — the key lives only on the server now (chat_server.py).
const PRIMARY_BACKEND_URL = import.meta.env.VITE_AGENT_BACKEND_URL || "https://omegavmchat.share.zrok.io";
const FALLBACK_BACKEND_URL = "https://omega-agent-backend-v2.onrender.com";
const HEALTH_TIMEOUT_MS = 8000;

let cachedBackendUrl = null;
let cachedAt = 0;
const CACHE_TTL_MS = 30000; // re-check health every 30s, not on every message

const pickBackendUrl = async () => {
  const now = Date.now();
  if (cachedBackendUrl && (now - cachedAt) < CACHE_TTL_MS) {
    console.log("[omega-backend] using cached:", cachedBackendUrl);
    return cachedBackendUrl;
  }
  console.log("[omega-backend] checking primary:", PRIMARY_BACKEND_URL);
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), HEALTH_TIMEOUT_MS);
    const res = await fetch(`${PRIMARY_BACKEND_URL}/api/health`, { signal: ctrl.signal });
    clearTimeout(timer);
    console.log("[omega-backend] primary health status:", res.status, res.ok);
    if (res.ok) {
      cachedBackendUrl = PRIMARY_BACKEND_URL;
      cachedAt = now;
      console.log("[omega-backend] SELECTED PRIMARY:", cachedBackendUrl);
      return cachedBackendUrl;
    }
  } catch (err) {
    console.log("[omega-backend] primary FAILED:", err.name, err.message);
  }
  cachedBackendUrl = FALLBACK_BACKEND_URL;
  cachedAt = now;
  console.log("[omega-backend] SELECTED FALLBACK:", cachedBackendUrl);
  return cachedBackendUrl;
};

const POLL_INTERVAL_MS = 3000;
const MAX_POLL_ATTEMPTS = 60; // 60 * 3s = 3 minutes ceiling

const callAgentBackend = async ({ prompt, images = [], onProgress }) => {
  try {
    const backendUrl = await pickBackendUrl();

    onProgress?.({ status: "starting" });

    const startRes = await fetch(`${backendUrl}/api/job/start`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: prompt, images }),
    });

    if (!startRes.ok) {
      const err = await startRes.text();
      return { data: { error: `Agent backend error (${backendUrl}): ${err}` } };
    }

    const { job_id } = await startRes.json();
    onProgress?.({ status: "queued", job_id });

    for (let attempt = 0; attempt < MAX_POLL_ATTEMPTS; attempt++) {
      await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));

      const pollRes = await fetch(`${backendUrl}/api/job/${job_id}`);
      if (!pollRes.ok) continue; // transient — keep polling

      const job = await pollRes.json();
      const lastStep = job.transcript?.[job.transcript.length - 1];
      const toolName = lastStep?.tool_calls?.[0]?.function?.name;

      onProgress?.({
        status: job.status,
        job_id,
        step: job.transcript?.length ?? 0,
        current_tool: toolName,
      });

      if (job.status === "done" || job.status === "failed") {
        return _finishJob(job);
      }
    }

    return { data: { error: `Job ${job_id} did not complete within the poll window.` } };
  } catch (e) {
    return { data: { error: `Agent backend exception: ${e.message}` } };
  }
};

const _finishJob = (job) => {
  if (job.status === "failed" || job.error) {
    return { data: { error: job.message || job.error || "Job failed." } };
  }
  return { data: { result: job.response, transcript: job.transcript } };
};

// Live-streaming path — uses the job/start + job/stream SSE pipeline so the
// caller gets each transcript step as it happens (for driving WorkspacePanel
// in real time) instead of waiting for the whole task to finish.
const streamAgentBackend = ({ prompt, images = [], onStep }) => {
  return new Promise(async (resolve) => {
    try {
      const backendUrl = await pickBackendUrl();
      const startRes = await fetch(`${backendUrl}/api/job/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: prompt, images }),
      });
      if (!startRes.ok) {
        const err = await startRes.text();
        resolve({ data: { error: `Agent backend error: ${err}` } });
        return;
      }
      const { job_id } = await startRes.json();
      if (!job_id) {
        resolve({ data: { error: "Agent backend did not return a job_id" } });
        return;
      }

      const transcript = [];
      const es = new EventSource(`${backendUrl}/api/job/stream/${job_id}`);

      es.onmessage = (event) => {
        const step = JSON.parse(event.data);
        if (step.done) {
          es.close();
          const finalEntry = [...transcript].reverse().find((e) => e.final && typeof e.content === "string");
          const finalText = step.response || finalEntry?.content ||
            (step.error ? `Agent job failed: ${step.error}` : "Omega completed without a final response. Review the live transcript for details.");
          resolve({ data: { result: finalText, transcript, error: step.error || null } });
          return;
        }
        transcript.push(step);
        if (onStep) onStep(step);
      };

      es.onerror = () => {
        es.close();
        resolve({ data: { error: "Lost connection to agent backend stream." } });
      };
    } catch (e) {
      resolve({ data: { error: `Could not reach agent backend at ${backendUrl}: ${e.message}` } });
    }
  });
};

export const functions = {
  invoke: async (fnName, payload) => {
    if (fnName === "groqComplete") {
      const p = payload || {};
      if (p.onStep) {
        const { onStep, ...rest } = p;
        return streamAgentBackend({ ...rest, onStep });
      }
      return callAgentBackend(p);
    }
    console.warn(`[local mode] functions.invoke("${fnName}") skipped — no backend connected.`);
    return { data: { error: `Function "${fnName}" is not available in local mode.` } };
  },
};
