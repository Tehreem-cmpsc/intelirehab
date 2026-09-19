const wait = (ms) => new Promise((res) => setTimeout(res, ms));

export const MOCK_DB = {
  clinic: {
    name: "Abbottabad Medical Complex",
    address: "Mandian Road, Abbottabad, KP",
    phone: "+92 992 405 566",
    email: "frontdesk@abbottabadmedical.pk",
  },
  admin: { name: "Nadia Hameed", role: "Clinic Administrator" },
  physiotherapists: [
    { id: "DR-AHMED-001", name: "Dr. Ahmed Khan", specialization: "Orthopedic Rehab", license: "PMC-22910", patients: 12, status: "Active", password: "rehab123" },
    { id: "DR-SARA-002", name: "Dr. Sara Malik", specialization: "Sports Injury", license: "PMC-22874", patients: 8, status: "Active", password: "rehab123" },
    { id: "DR-BILAL-003", name: "Dr. Bilal Hussain", specialization: "Post-Surgical Rehab", license: "PMC-23051", patients: 5, status: "Active", password: "rehab123" },
  ],
  patients: [
    { id: "P-1", name: "Kashmala Zeb", physio: "Dr. Ahmed Khan", joint: "Elbow \u2014 Post-Surgery Rehab", recovery: 70, trend: "Improving", lastSession: "2 days ago" },
    { id: "P-2", name: "Waqas Tariq", physio: "Dr. Sara Malik", joint: "Shoulder \u2014 Sports Injury", recovery: 55, trend: "Improving", lastSession: "Today" },
    { id: "P-3", name: "Ayesha Noor", physio: "Dr. Bilal Hussain", joint: "Elbow \u2014 Post-Surgery", recovery: 40, trend: "Plateaued", lastSession: "5 days ago" },
    { id: "P-4", name: "Hamza Farooq", physio: "Dr. Ahmed Khan", joint: "Wrist \u2014 Post-Surgery", recovery: 82, trend: "Improving", lastSession: "Yesterday" },
  ],
  activity: [
    { id: 1, text: "Dr. Ahmed Khan onboarded a new patient, Hamza Farooq.", time: "Yesterday" },
    { id: 2, text: "Kashmala Zeb reached 70% ROM recovery on her elbow protocol.", time: "2 days ago" },
    { id: 3, text: "Dr. Sara Malik adjusted Waqas Tariq's exercise intensity.", time: "3 days ago" },
    { id: 4, text: "Dr. Bilal Hussain flagged a plateaued recovery for review.", time: "5 days ago" },
  ],
};

export const clinicApi = {
  auth: {
    signIn: async (emailOrId, password, role = "admin") => {
      await wait(650);

      if (role === "physio") {
        const physio = MOCK_DB.physiotherapists.find(
          (p) => p.id === emailOrId
        );

        if (!physio || physio.password !== password) {
          throw new Error("Unrecognised physiotherapist ID or password.");
        }

        return {
          user: {
            name: physio.name,
            role: "Physiotherapist",
            authRole: "physio",
            id: physio.id,
            specialization: physio.specialization,
            license: physio.license,
          },
          clinic: MOCK_DB.clinic,
        };
      }

      const adminEmail = "admin@abbottabadmedical.pk";
      const adminPassword = "demo123";

      if (emailOrId !== adminEmail || password !== adminPassword) {
        throw new Error("Invalid admin email or password.");
      }

      return {
        user: {
          ...MOCK_DB.admin,
          authRole: "admin",
        },
        clinic: MOCK_DB.clinic,
      };
    },
  },
  from: (table) => ({
    select: async () => {
      await wait(500);
      return { data: MOCK_DB[table] ?? [] };
    },
    insert: async (record) => {
      await wait(600);
      MOCK_DB[table] = [record, ...(MOCK_DB[table] ?? [])];
      return { data: record };
    },
    update: async (record) => {
      await wait(500);
      MOCK_DB.clinic = { ...MOCK_DB.clinic, ...record };
      return { data: MOCK_DB.clinic };
    },
    delete: async (key) => {
      await wait(600);
      MOCK_DB[table] = (MOCK_DB[table] ?? []).filter((item) => item.id !== key);
      return { data: null };
    },
  }),
  dashboardStats: async () => {
    await wait(500);
    const physios = MOCK_DB.physiotherapists.length;
    const patients = MOCK_DB.patients.length;
    const avgRom = Math.round(MOCK_DB.patients.reduce((a, p) => a + p.recovery, 0) / patients);
    return { physios, patients, sessionsToday: 6, avgRom };
  },
};
