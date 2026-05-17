// ========== FILE: scripts/seed_demo_data.js ==========
require('dotenv').config();
const { randomUUID } = require('crypto');
const { supabase } = require('../supabaseClient');

async function main() {
    const demoDeviceId = 'demo-device-001';
    const demoUserId = randomUUID();

    console.log('[1/8] Creating demo registry...');
    const eventDate = new Date(Date.now() + 90 * 86400000).toISOString().slice(0, 10);

    const { data: registry, error: regErr } = await supabase
        .from('registries')
        .insert([
            {
                user_id: demoUserId,
                event_type: 'Wedding',
                event_date: eventDate,
                event_location: "Jordan & Alex's Wedding",
                is_public: true,
                budget: 3000,
                theme: 'Modern Classic'
            }
        ])
        .select()
        .single();
    if (regErr) throw regErr;
    console.log('  ✅ Registry created:', registry.id);

    console.log('[2/8] Fetching first 20 products...');
    const { data: products, error: pErr } = await supabase.from('products').select('id, price, category, name').order('id', { ascending: true }).limit(20);
    if (pErr) throw pErr;
    if (!products || products.length < 8) throw new Error('Not enough products in DB to seed demo (need at least 8).');
    console.log('  ✅ Products fetched:', products.length);

    console.log('[3/8] Creating 8 registry items...');
    const chosen = products.slice(0, 8);
    const mostWantedIds = new Set([chosen[1].id, chosen[4].id]);
    const partialReceivedIds = new Set([chosen[0].id, chosen[3].id, chosen[6].id]);

    const registryItemsPayload = chosen.map((p, idx) => ({
        registry_id: registry.id,
        product_id: p.id,
        quantity_requested: idx % 3 === 0 ? 2 : 1,
        quantity_received: partialReceivedIds.has(p.id) ? 1 : 0,
        is_most_wanted: mostWantedIds.has(p.id),
        price_snapshot: Number(p.price || 0),
        ai_reason: `Chosen for demo as a strong ${p.category || 'home'} essential.`
    }));

    const { data: registryItems, error: riErr } = await supabase.from('registry_items').insert(registryItemsPayload).select();
    if (riErr) throw riErr;
    console.log('  ✅ Registry items created:', registryItems.length);

    const itemByProductId = new Map((registryItems || []).map((ri) => [ri.product_id, ri]));

    console.log('[4/8] Adding 3 contributions across 2 items...');
    const contribTargets = [chosen[1], chosen[3]].map((p) => itemByProductId.get(p.id)).filter(Boolean);
    if (contribTargets.length < 2) throw new Error('Could not resolve contribution targets.');

    const contributionsPayload = [
        { registry_item_id: contribTargets[0].id, contributor_name: 'Taylor', amount: 50, message: 'So happy for you both!' },
        { registry_item_id: contribTargets[0].id, contributor_name: 'Morgan', amount: 75, message: 'Can’t wait for the big day — cheers!' },
        { registry_item_id: contribTargets[1].id, contributor_name: 'Casey', amount: 40, message: 'A little something for your new home.' }
    ];
    const { data: contributions, error: cErr } = await supabase.from('registry_contributions').insert(contributionsPayload).select();
    if (cErr) throw cErr;
    console.log('  ✅ Contributions added:', contributions.length);

    console.log('[5/8] Adding 1 collaborator...');
    const { data: collab, error: colErr } = await supabase
        .from('registry_collaborators')
        .insert([{ registry_id: registry.id, email: 'partner@example.com', role: 'editor' }])
        .select()
        .single();
    if (colErr) throw colErr;
    console.log('  ✅ Collaborator added:', collab.email);

    console.log('[6/8] Seeding cart with 3 cookware-ish items (user_id-based cart)...');
    const cookware = products.filter((p) => String(p.category || '').toLowerCase().includes('cook')).slice(0, 3);
    const cartItems = (cookware.length ? cookware : products.slice(0, 3)).map((p, idx) => ({
        user_id: demoUserId,
        product_id: p.id,
        quantity: idx + 1
    }));
    const { data: cart, error: cartErr } = await supabase.from('cart_items').insert(cartItems).select();
    if (cartErr) throw cartErr;
    console.log('  ✅ Cart items added:', cart.length, '(user_id:', demoUserId, ')');

    console.log('[7/8] Seeding 3 save-for-later items (device_id-based)...');
    const savedCandidates = products.slice(8, 11);
    const savePayload = savedCandidates.map((p) => ({ device_id: demoDeviceId, product_id: p.id }));
    const { data: saved, error: sErr } = await supabase.from('save_for_later').upsert(savePayload, { onConflict: 'device_id,product_id' }).select();
    if (sErr) throw sErr;
    console.log('  ✅ Save-for-later items added:', saved.length, '(device_id:', demoDeviceId, ')');

    console.log('[8/8] Seeding demo browsing/search behavior...');
    await supabase.from('recent_searches').insert([
        { query: 'wedding registry', device_id: demoDeviceId },
        { query: 'cookware set', device_id: demoDeviceId },
        { query: 'serveware', device_id: demoDeviceId }
    ]);
    await supabase.from('user_events').insert(
        chosen.slice(0, 5).map((p) => ({ device_id: demoDeviceId, product_id: p.id, event_type: 'view' }))
    );
    console.log('  ✅ User events + searches added');

    console.log('\nDONE ✅');
    console.log('Registry ID:', registry.id);
    console.log('Share token:', registry.share_token);
    console.log('Demo device_id:', demoDeviceId);
    console.log('Demo cart user_id (uuid):', demoUserId);
}

main().catch((e) => {
    console.error('Seed failed:', e.message);
    process.exit(1);
});

