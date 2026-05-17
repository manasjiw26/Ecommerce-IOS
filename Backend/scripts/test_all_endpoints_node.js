// ========== FILE: scripts/test_all_endpoints_node.js ==========
// Cross-platform (Windows-friendly) E2E smoke tests.
// Usage:
//   node scripts/test_all_endpoints_node.js
// Env:
//   BASE_URL=http://localhost:3000
//   REGISTRY_ID=... (optional)
//   DEVICE_ID=demo-device-001 (optional)

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const DEVICE_ID = process.env.DEVICE_ID || 'demo-device-001';
let REGISTRY_ID = process.env.REGISTRY_ID || '';

let token = '';
let userId = '00000000-0000-0000-0000-000000000001';

function fail(name, msg) {
    console.error(`FAIL: ${name}${msg ? ` — ${msg}` : ''}`);
    process.exitCode = 1;
}
function pass(name) {
    console.log(`PASS: ${name}`);
}

async function getJson(path) {
    const headers = {};
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    const r = await fetch(`${BASE_URL}${path}`, { headers });
    const t = await r.text();
    let j = null;
    try { j = JSON.parse(t); } catch (_) {}
    return { ok: r.ok, status: r.status, json: j, text: t };
}

async function postJson(path, body) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    const r = await fetch(`${BASE_URL}${path}`, {
        method: 'POST',
        headers,
        body: JSON.stringify(body)
    });
    const t = await r.text();
    let j = null;
    try { j = JSON.parse(t); } catch (_) {}
    return { ok: r.ok, status: r.status, json: j, text: t };
}

async function delJson(path, body) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    const r = await fetch(`${BASE_URL}${path}`, {
        method: 'DELETE',
        headers,
        body: JSON.stringify(body)
    });
    const t = await r.text();
    let j = null;
    try { j = JSON.parse(t); } catch (_) {}
    return { ok: r.ok, status: r.status, json: j, text: t };
}

async function main() {
    console.log(`Base URL: ${BASE_URL}`);

    // /health
    {
        const r = await getJson('/health');
        if (!r.ok || r.json?.status !== 'ok') return fail('/health', r.text);
        pass('/health');
    }

    // AUTH SIGNUP / LOGIN TEST to obtain authentic Supabase token
    {
        const testEmail = `test_${Date.now()}_${Math.floor(Math.random() * 10000)}@example.com`;
        const signupRes = await postJson('/auth/signup', {
            email: testEmail,
            password: 'Password123!',
            name: 'E2E Test Runner User'
        });
        if (signupRes.ok && signupRes.json?.access_token) {
            token = signupRes.json.access_token;
            userId = signupRes.json.user.id;
            pass(`Auth Signup & Session Retrieval: Successful (User ID: ${userId})`);
        } else {
            console.warn('⚠️ Signup failed or did not return token immediately, attempting login fallback...');
            const loginRes = await postJson('/auth/login', {
                email: 'test@example.com',
                password: 'Password123!'
            });
            if (loginRes.ok && loginRes.json?.access_token) {
                token = loginRes.json.access_token;
                userId = loginRes.json.user.id;
                pass(`Auth Login Fallback: Successful (User ID: ${userId})`);
            } else {
                return fail('Auth / JWT token retrieval failed', `Signup: ${signupRes.text}. Login: ${loginRes.text}`);
            }
        }
    }

    // /products
    const productsRes = await getJson('/products');
    if (!productsRes.ok || !Array.isArray(productsRes.json) || !productsRes.json.length) return fail('/products', productsRes.text);
    pass('/products');
    const productId = productsRes.json[0].id;
    if (!productId) return fail('productId', 'missing');

    // Create registry if not provided
    if (!REGISTRY_ID) {
        const create = await postJson('/registry', {
            event_type: 'Wedding',
            event_date: '2030-01-01',
            event_location: 'Test Registry',
            is_public: true
        });
        if (!create.ok || !create.json?.id) return fail('POST /registry (Authenticated)', create.text);
        REGISTRY_ID = create.json.id;
    }
    pass(`registry id ready (${REGISTRY_ID})`);

    // Add item to registry
    let registryItemId = null;
    {
        const add = await postJson(`/registry/${REGISTRY_ID}/items`, {
            product_id: productId,
            quantity_requested: 1,
            is_most_wanted: true,
            ai_reason: 'Seeded by node test'
        });
        if (!add.ok || !add.json?.id) return fail('POST /registry/:id/items', add.text);
        registryItemId = add.json.id;
        pass('POST /registry/:id/items');
    }

    // Dashboard
    {
        const dash = await getJson(`/registry/${REGISTRY_ID}/dashboard`);
        if (!dash.ok || !dash.json?.registry || !dash.json?.stats || !Array.isArray(dash.json?.items)) return fail('GET /registry/:id/dashboard', dash.text);
        pass('GET /registry/:id/dashboard');
    }

    // Budget
    {
        const b = await postJson(`/registry/${REGISTRY_ID}/budget`, { budget: 2500 });
        if (!b.ok || typeof b.json?.budget !== 'number') return fail('POST /registry/:id/budget', b.text);
        pass('POST /registry/:id/budget');
    }

    // Contribute
    if (registryItemId) {
        const c = await postJson(`/registry/${REGISTRY_ID}/contribute`, {
            registry_item_id: registryItemId,
            contributor_name: 'Taylor',
            amount: 50,
            message: 'Congrats!'
        });
        if (!c.ok || !c.json?.contribution) return fail('POST /registry/:id/contribute', c.text);
        pass('POST /registry/:id/contribute');
    }

    // Collaborators
    {
        const addC = await postJson(`/registry/${REGISTRY_ID}/collaborators`, { email: 'partner@example.com', role: 'editor' });
        if (!addC.ok || !addC.json?.collaborator) return fail('POST /registry/:id/collaborators', addC.text);
        pass('POST /registry/:id/collaborators');

        const list = await getJson(`/registry/${REGISTRY_ID}/collaborators`);
        if (!list.ok || !Array.isArray(list.json)) return fail('GET /registry/:id/collaborators', list.text);
        pass('GET /registry/:id/collaborators');
    }

    // Share link
    {
        const s = await getJson(`/registry/${REGISTRY_ID}/share-link`);
        if (!s.ok || !s.json?.share_token) return fail('GET /registry/:id/share-link', s.text);
        pass('GET /registry/:id/share-link');
    }

    // Save for later + saved list + move to registry
    {
        const save = await postJson('/cart/save-for-later', { device_id: DEVICE_ID, product_id: productId });
        if (!save.ok || !save.json?.id) return fail('POST /cart/save-for-later', save.text);
        pass('POST /cart/save-for-later');

        const saved = await getJson(`/cart/saved/${DEVICE_ID}`);
        if (!saved.ok || !Array.isArray(saved.json)) return fail('GET /cart/saved/:deviceId', saved.text);
        pass('GET /cart/saved/:deviceId');

        const move = await postJson('/cart/move-to-registry', { device_id: DEVICE_ID, product_id: productId, registry_id: REGISTRY_ID, quantity_requested: 1 });
        if (!move.ok || !move.json?.success) return fail('POST /cart/move-to-registry', move.text);
        pass('POST /cart/move-to-registry');

        const del = await delJson('/cart/save-for-later', { device_id: DEVICE_ID, product_id: productId });
        if (!del.ok || !del.json?.success) return fail('DELETE /cart/save-for-later', del.text);
        pass('DELETE /cart/save-for-later');
    }

    // No-Gemini aesthetic matching
    {
        const a = await postJson('/ai/aesthetic-match', {
            palette_hex: ['#111827', '#F5F0E8'],
            materials: ['stainless steel'],
            finish_keywords: ['brushed'],
            mood_keywords: ['minimal'],
            categories: ['Dinnerware'],
            desired_items: ['cutlery'],
            budget: 200
        });
        if (!a.ok || !Array.isArray(a.json?.suggestions)) return fail('POST /ai/aesthetic-match', a.text);
        pass('POST /ai/aesthetic-match');
    }

    console.log('ALL NODE TESTS PASSED ✅');
}

main().catch((e) => {
    console.error('FAIL: runner error —', e.message);
    process.exit(1);
});
