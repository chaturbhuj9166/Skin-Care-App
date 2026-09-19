// Seeds the database with demo data: 1 admin, 4 doctors, 3 users, 1 active
// question flow, and 3 cases covering different points in the case status
// flow (PENDING -> ASSIGNED -> ... -> SOLVED).
//
// Run with: npm run prisma:seed  (requires a live PostgreSQL DATABASE_URL)
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();
const SALT_ROUNDS = 10;

const QUESTIONS = [
  {
    id: 'q1',
    text: 'What is your main skin concern?',
    type: 'single_choice',
    options: ['Acne', 'Dark Spots', 'Dry Skin', 'Oily Skin', 'Redness', 'Other'],
  },
  {
    id: 'q2',
    text: 'How long have you had this concern?',
    type: 'single_choice',
    options: ['Less than a week', '1-4 weeks', '1-6 months', 'More than 6 months'],
  },
  {
    id: 'q3',
    text: 'Are you currently using any skincare products or medication for it?',
    type: 'text',
  },
  {
    id: 'q4',
    text: 'Do you have any known allergies?',
    type: 'text',
  },
  {
    id: 'q5',
    text: 'Please upload 1-3 clear photos of the affected area',
    type: 'photo_upload',
  },
];

async function main() {
  console.log('Seeding database...');

  // ---- Admin ---------------------------------------------------------
  const adminPassword = await bcrypt.hash('Admin@123', SALT_ROUNDS);
  const admin = await prisma.admin.upsert({
    where: { email: 'admin@skincareapp.com' },
    update: {},
    create: {
      name: 'Super Admin',
      email: 'admin@skincareapp.com',
      password: adminPassword,
    },
  });
  console.log(`  Admin ready: ${admin.email} (password: Admin@123)`);

  // ---- Doctors ---------------------------------------------------------
  // No password: doctors log in with phone+OTP, same as Users.
  const doctorSeeds = [
    {
      name: 'Dr. Ayesha Khan',
      email: 'ayesha.khan@skincareapp.com',
      phone: '+919810000001',
      specialization: 'Cosmetic Dermatology',
      experience: 8,
    },
    {
      name: 'Dr. Rohan Mehta',
      email: 'rohan.mehta@skincareapp.com',
      phone: '+919810000002',
      specialization: 'Clinical Dermatology',
      experience: 12,
    },
    {
      name: 'Dr. Priya Sharma',
      email: 'priya.sharma@skincareapp.com',
      phone: '+919810000003',
      specialization: 'Pediatric Dermatology',
      experience: 6,
    },
    {
      name: 'Dr. Karan Verma',
      email: 'karan.verma@skincareapp.com',
      phone: '+919810000004',
      specialization: 'Acne & Scar Treatment',
      experience: 10,
    },
  ];

  const doctors = [];
  for (const seed of doctorSeeds) {
    const doctor = await prisma.doctor.upsert({
      where: { email: seed.email },
      update: {},
      create: seed,
    });
    doctors.push(doctor);
  }
  console.log(`  ${doctors.length} doctors ready (login via phone, any 6-digit OTP)`);

  // ---- Users ---------------------------------------------------------
  const userSeeds = [
    { name: 'Simran Kaur', phone: '+919820000001', email: 'simran.kaur@example.com', gender: 'Female', age: 27 },
    { name: 'Arjun Nair', phone: '+919820000002', email: 'arjun.nair@example.com', gender: 'Male', age: 34 },
    { name: 'Neha Gupta', phone: '+919820000003', email: 'neha.gupta@example.com', gender: 'Female', age: 22 },
  ];

  const users = [];
  for (const seed of userSeeds) {
    const user = await prisma.user.upsert({
      where: { phone: seed.phone },
      update: {},
      create: seed,
    });
    users.push(user);
  }
  console.log(`  ${users.length} demo users ready (login via phone, any 6-digit OTP)`);

  // ---- Question flow ---------------------------------------------------------
  let flow = await prisma.questionFlow.findFirst({ where: { title: 'Skin Consultation Intake' } });
  if (flow) {
    flow = await prisma.questionFlow.update({
      where: { id: flow.id },
      data: { questions: QUESTIONS, isActive: true },
    });
  } else {
    flow = await prisma.questionFlow.create({
      data: { title: 'Skin Consultation Intake', questions: QUESTIONS, isActive: true },
    });
  }
  console.log(`  Active question flow ready: "${flow.title}"`);

  // ---- Demo cases (only seeded once, to keep re-running the seed script safe) ----
  const existingCaseCount = await prisma.case.count();
  if (existingCaseCount > 0) {
    console.log('  Cases already exist, skipping demo case/message/solution seeding.');
  } else {
    // Case 1: brand new, unassigned submission.
    const case1 = await prisma.case.create({
      data: {
        userId: users[0].id,
        questionFlowId: flow.id,
        answers: {
          q1: 'Acne',
          q2: '1-4 weeks',
          q3: 'None currently',
          q4: 'No known allergies',
        },
        photos: [],
        status: 'PENDING',
      },
    });

    // Case 2: assigned to a doctor, conversation in progress.
    const case2 = await prisma.case.create({
      data: {
        userId: users[1].id,
        doctorId: doctors[0].id,
        questionFlowId: flow.id,
        answers: {
          q1: 'Oily Skin',
          q2: '1-6 months',
          q3: 'Salicylic acid cleanser twice a day',
          q4: 'No known allergies',
        },
        photos: [],
        status: 'ASSIGNED',
      },
    });

    await prisma.message.createMany({
      data: [
        {
          caseId: case2.id,
          senderId: users[1].id,
          senderType: 'USER',
          text: 'Hi doctor, thank you for taking my case. My oily skin has gotten worse over the last month.',
        },
        {
          caseId: case2.id,
          senderId: doctors[0].id,
          senderType: 'DOCTOR',
          text: 'Hello Arjun! Thanks for the details and photos. Could you tell me what cleanser and moisturizer you currently use?',
        },
      ],
    });

    // Case 3: fully solved, with a solution and a scheduled follow-up.
    const case3 = await prisma.case.create({
      data: {
        userId: users[2].id,
        doctorId: doctors[1].id,
        questionFlowId: flow.id,
        answers: {
          q1: 'Dark Spots',
          q2: 'More than 6 months',
          q3: 'Vitamin C serum in the mornings',
          q4: 'None',
        },
        photos: [],
        status: 'SOLVED',
      },
    });

    await prisma.solution.create({
      data: {
        caseId: case3.id,
        doctorId: doctors[1].id,
        text: 'Based on your history and photos, this looks like post-inflammatory hyperpigmentation. Start a nightly retinoid and continue daily SPF 50 sunscreen. Avoid direct sun exposure between 11am-3pm.',
        prescription: {
          medications: [
            { name: 'Adapalene 0.1% gel', dosage: 'Apply a pea-sized amount nightly', duration: '8 weeks' },
            { name: 'Broad-spectrum SPF 50 sunscreen', dosage: 'Apply every morning', duration: 'Ongoing' },
          ],
          instructions: 'Avoid harsh scrubs. Reassess in follow-up appointment.',
        },
        followUpDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    console.log(`  3 demo cases created: PENDING, ASSIGNED (with messages), SOLVED (with solution)`);
  }

  console.log('Seeding complete.');
}

main()
  .catch((err) => {
    console.error('Seeding failed:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
