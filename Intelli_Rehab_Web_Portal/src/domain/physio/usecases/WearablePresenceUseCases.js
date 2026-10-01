import { supabase } from "../../../infrastructure/supabase/supabaseClient";

const REALTIME_DEBOUNCE_MS = 1500;

// Live wearable connectivity (see supabase_wearable_presence.sql).
// "Live" is decided by the database - reported connected AND heard from in
// the last 45 s - so a phone that vanishes without saying so expires by
// itself, and no browser clock is involved.
const WearablePresenceUseCases = {
  // Map of patientId -> { live, lastSeenAt } for the caller's clinic (RLS).
  async getPresence() {
    const { data, error } = await supabase.rpc("get_wearable_presence");
    if (error) throw error;
    return new Map(
      (data ?? []).map((r) => [r.patient_id, { live: Boolean(r.is_live), lastSeenAt: r.last_seen_at }])
    );
  },

  // Calls onChange (debounced) whenever any visible wearable row changes.
  // Returns an unsubscribe function.
  subscribe(onChange) {
    let timer = null;
    const channel = supabase
      .channel("wearable-presence")
      .on("postgres_changes", { event: "*", schema: "public", table: "wearable_devices" }, () => {
        clearTimeout(timer);
        timer = setTimeout(onChange, REALTIME_DEBOUNCE_MS);
      })
      .subscribe();
    return () => {
      clearTimeout(timer);
      supabase.removeChannel(channel);
    };
  },
};

export default WearablePresenceUseCases;
