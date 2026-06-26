const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

exports.handler = async (event) => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Content-Type': 'application/json'
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers, body: JSON.stringify({ error: 'Method not allowed' }) };
  }

  // Verify the user JWT from the Authorization header
  const authHeader = event.headers.authorization || '';
  const token = authHeader.replace('Bearer ', '').trim();
  if (!token) {
    return { statusCode: 401, headers, body: JSON.stringify({ error: 'No auth token' }) };
  }

  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return { statusCode: 401, headers, body: JSON.stringify({ error: 'Invalid token' }) };
  }

  const userId = user.id;
  let body;
  try { body = JSON.parse(event.body); }
  catch { return { statusCode: 400, headers, body: JSON.stringify({ error: 'Invalid JSON' }) }; }

  const { action, payload } = body;

  try {
    // ---- BUY BOX ----
    if (action === 'get_buy_box') {
      const { data, error } = await supabase
        .from('buy_box_profiles')
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', { ascending: false })
        .limit(1)
        .single();
      if (error && error.code !== 'PGRST116') throw error;
      return { statusCode: 200, headers, body: JSON.stringify({ data: data || null }) };
    }

    if (action === 'save_buy_box') {
      const { data: existing } = await supabase
        .from('buy_box_profiles')
        .select('id')
        .eq('user_id', userId)
        .limit(1)
        .single();

      const record = { user_id: userId, ...payload };
      let result;
      if (existing?.id) {
        result = await supabase.from('buy_box_profiles').update(record).eq('id', existing.id).select().single();
      } else {
        result = await supabase.from('buy_box_profiles').insert(record).select().single();
      }
      if (result.error) throw result.error;
      return { statusCode: 200, headers, body: JSON.stringify({ data: result.data }) };
    }

    // ---- LEADS ----
    if (action === 'get_leads') {
      const { data, error } = await supabase
        .from('leads')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return { statusCode: 200, headers, body: JSON.stringify({ data: data || [] }) };
    }

    if (action === 'upsert_leads') {
      // payload.leads = array of lead objects
      const records = (payload.leads || []).map(l => ({
        user_id:             userId,
        local_id:            l.id,
        address:             l.address || null,
        city:                l.city || null,
        state:               l.state || null,
        zip:                 l.zip || null,
        value:               l.value || null,
        equity_pct:          l.equityPct || null,
        owner:               l.owner || null,
        years_owned:         l.yearsOwned || null,
        beds:                l.beds || null,
        baths:               l.baths || null,
        sqft:                l.sqft || null,
        prop_type:           l.propType || null,
        signals:             l.signals || [],
        buy_box_label:       l.buyBoxLabel || null,
        buy_box_score:       l.buyBoxScore || null,
        buy_box_hard_fails:  l.buyBoxHardFails || [],
        buy_box_near_misses: l.buyBoxNearMisses || [],
        source:              l.source || 'csv'
      }));
      const { error } = await supabase.from('leads').insert(records);
      if (error) throw error;
      return { statusCode: 200, headers, body: JSON.stringify({ ok: true, count: records.length }) };
    }

    if (action === 'update_lead') {
      const { leadId, updates } = payload;
      const { error } = await supabase
        .from('leads')
        .update(updates)
        .eq('id', leadId)
        .eq('user_id', userId);
      if (error) throw error;
      return { statusCode: 200, headers, body: JSON.stringify({ ok: true }) };
    }

    if (action === 'delete_leads') {
      const { error } = await supabase
        .from('leads')
        .delete()
        .eq('user_id', userId);
      if (error) throw error;
      return { statusCode: 200, headers, body: JSON.stringify({ ok: true }) };
    }

    // ---- DEAL ANALYSES ----
    if (action === 'save_analysis') {
      const record = { user_id: userId, ...payload };
      const { data, error } = await supabase
        .from('deal_analyses')
        .insert(record)
        .select()
        .single();
      if (error) throw error;
      return { statusCode: 200, headers, body: JSON.stringify({ data }) };
    }

    if (action === 'get_analyses') {
      const { data, error } = await supabase
        .from('deal_analyses')
        .select('id, address, price, ai_grade, ai_recommendation, monthly_cash_flow, coc_return, cap_rate, created_at, lead_id')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(50);
      if (error) throw error;
      return { statusCode: 200, headers, body: JSON.stringify({ data: data || [] }) };
    }

    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Unknown action: ' + action }) };

  } catch (err) {
    console.error('supabase-data error:', err);
    return { statusCode: 500, headers, body: JSON.stringify({ error: err.message }) };
  }
};
