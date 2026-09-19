import { useState, useEffect } from "react";
import { clinicApi } from "../../infrastructure/admin/api";

export default function usePatients() {
  const [list, setList] = useState([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    (async () => {
      setLoading(true);
      const { data } = await clinicApi.from("patients").select();
      setList(data);
      setLoading(false);
    })();
  }, []);
  return { list, loading };
}
