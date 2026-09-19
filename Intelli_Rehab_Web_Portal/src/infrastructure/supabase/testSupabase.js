import { supabase } from "./supabaseClient";

export async function testSupabaseConnection() {
  const { data, error } = await supabase
    .from("test")
    .select("*");

  if (error) {
    console.error("Supabase error:", error);
    return;
  }

  console.log("Supabase connected:", data);
}