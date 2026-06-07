const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const prisma = new PrismaClient();

async function main() {
  // Seed categories
  const categories = [
    // Keamanan
    { name: 'Pencurian', type: 'KEAMANAN', icon: '🔓', color: '#FF5252', priorityLevel: 3 },
    { name: 'Perampokan', type: 'KEAMANAN', icon: '🔪', color: '#FF1744', priorityLevel: 4 },
    { name: 'Orang Mencurigakan', type: 'KEAMANAN', icon: '👤', color: '#FF6D00', priorityLevel: 2 },
    { name: 'Kekerasan Fisik', type: 'KEAMANAN', icon: '👊', color: '#FF1744', priorityLevel: 4 },
    { name: 'Pelecehan', type: 'KEAMANAN', icon: '⚠️', color: '#FF5252', priorityLevel: 3 },
    { name: 'Keributan Warga', type: 'KEAMANAN', icon: '📢', color: '#FF9100', priorityLevel: 2 },
    { name: 'Anak Hilang', type: 'KEAMANAN', icon: '🧒', color: '#FF1744', priorityLevel: 4 },
    { name: 'Kendaraan Mencurigakan', type: 'KEAMANAN', icon: '🚗', color: '#FF6D00', priorityLevel: 2 },
    { name: 'Pengerusakan Fasilitas', type: 'KEAMANAN', icon: '🔨', color: '#FF5252', priorityLevel: 2 },
    // Bencana
    { name: 'Kebakaran', type: 'BENCANA', icon: '🔥', color: '#FF1744', priorityLevel: 4 },
    { name: 'Banjir', type: 'BENCANA', icon: '🌊', color: '#1565C0', priorityLevel: 4 },
    { name: 'Gempa', type: 'BENCANA', icon: '🌍', color: '#FF6D00', priorityLevel: 4 },
    { name: 'Pohon Tumbang', type: 'BENCANA', icon: '🌳', color: '#2E7D32', priorityLevel: 3 },
    { name: 'Angin Kencang', type: 'BENCANA', icon: '🌬️', color: '#1565C0', priorityLevel: 3 },
    { name: 'Kabel Listrik Jatuh', type: 'BENCANA', icon: '⚡', color: '#FF6D00', priorityLevel: 4 },
    { name: 'Kebocoran Gas', type: 'BENCANA', icon: '💨', color: '#FF1744', priorityLevel: 4 },
    // Medis
    { name: 'Orang Pingsan', type: 'MEDIS', icon: '🏥', color: '#C62828', priorityLevel: 3 },
    { name: 'Lansia Jatuh', type: 'MEDIS', icon: '🧓', color: '#E53935', priorityLevel: 3 },
    { name: 'Anak Sakit Mendadak', type: 'MEDIS', icon: '🤒', color: '#E53935', priorityLevel: 3 },
    { name: 'Kecelakaan Motor', type: 'MEDIS', icon: '🏍️', color: '#FF1744', priorityLevel: 4 },
    { name: 'Serangan Hewan', type: 'MEDIS', icon: '🐕', color: '#FF5252', priorityLevel: 3 },
    { name: 'Medis Darurat', type: 'MEDIS', icon: '🚑', color: '#FF1744', priorityLevel: 4 },
    // Fasilitas
    { name: 'Lampu Jalan Mati', type: 'FASILITAS', icon: '💡', color: '#F9A825', priorityLevel: 1 },
    { name: 'Jalan Rusak', type: 'FASILITAS', icon: '🚧', color: '#FF6D00', priorityLevel: 2 },
    { name: 'Saluran Air Tersumbat', type: 'FASILITAS', icon: '🚰', color: '#1565C0', priorityLevel: 2 },
    { name: 'Sampah Menumpuk', type: 'FASILITAS', icon: '🗑️', color: '#558B2F', priorityLevel: 1 },
    { name: 'Gerbang Rusak', type: 'FASILITAS', icon: '🚪', color: '#FF6D00', priorityLevel: 2 },
    { name: 'CCTV Mati', type: 'FASILITAS', icon: '📷', color: '#FF5252', priorityLevel: 2 },
    // Lainnya
    { name: 'Lainnya', type: 'LAINNYA', icon: '📝', color: '#757575', priorityLevel: 1 },
  ];

  for (const cat of categories) {
    await prisma.alertCategory.upsert({
      where: { id: cat.name },
      update: {},
      create: cat,
    });
  }

  // Seed admin user
  const adminPassword = await bcrypt.hash('admin123', 10);
  await prisma.user.upsert({
    where: { email: 'admin@komplekguard.id' },
    update: {},
    create: {
      name: 'Admin KomplekGuard',
      email: 'admin@komplekguard.id',
      passwordHash: adminPassword,
      phone: '081234567890',
      role: 'ADMIN',
      address: 'Gang Taruna, Denpasar, Bali',
      latitude: -8.65,
      longitude: 115.216667,
    },
  });

  // Seed emergency contacts
  const contacts = [
    { name: 'Polisi', phone: '110', type: 'POLISI', description: 'Hubungi untuk kejadian kriminal' },
    { name: 'Pemadam Kebakaran', phone: '113', type: 'DAMKAR', description: 'Hubungi untuk kebakaran' },
    { name: 'Ambulans / BNPB', phone: '119', type: 'MEDIS', description: 'Hubungi untuk darurat medis' },
    { name: 'PLN', phone: '123', type: 'PLN', description: 'Hubungi untuk gangguan listrik' },
    { name: 'SAR Nasional', phone: '115', type: 'SAR', description: 'Hubungi untuk bencana alam' },
  ];

  for (const contact of contacts) {
    await prisma.emergencyContact.upsert({
      where: { id: contact.name },
      update: {},
      create: contact,
    });
  }

  console.log('✅ Seed berhasil!');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());