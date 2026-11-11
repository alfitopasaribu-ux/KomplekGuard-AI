/// Panduan keselamatan lokal tanpa panggilan API maupun konsumsi token.
/// Ini bukan evaluasi risiko langsung atau hasil analisis AI generatif.
class SafetyQuickGuide {
  const SafetyQuickGuide({
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final List<String> steps;

  static const guides = <SafetyQuickGuide>[
    SafetyQuickGuide(
      title: 'Tercium bau gas',
      subtitle: 'Panduan awal keselamatan tanpa koneksi AI',
      steps: [
        'Jauhi sumber bau gas dan ajak orang di sekitar menjauh ke tempat terbuka.',
        'Jangan menyalakan atau mematikan sakelar listrik, api, atau alat yang dapat menimbulkan percikan.',
        'Jika aman, tinggalkan bangunan dan hubungi petugas darurat atau penyedia gas dari lokasi yang aman.',
        'Jangan masuk kembali sebelum dinyatakan aman oleh petugas.',
      ],
    ),
    SafetyQuickGuide(
      title: 'Terjadi kebakaran',
      subtitle: 'Panduan evakuasi singkat',
      steps: [
        'Segera evakuasi menuju tempat aman; jangan kembali mengambil barang.',
        'Peringatkan warga di sekitar tanpa menempatkan diri dalam bahaya.',
        'Hubungi pemadam kebakaran atau layanan darurat setempat dari tempat aman.',
        'Jauhi asap dan jangan masuk kembali sebelum petugas memberi izin.',
      ],
    ),
    SafetyQuickGuide(
      title: 'Ada orang mencurigakan',
      subtitle: 'Langkah yang mengutamakan keselamatan',
      steps: [
        'Jangan mendekati, mengejar, atau menghadang orang tersebut.',
        'Pergi ke tempat ramai atau lokasi yang aman.',
        'Hubungi pengurus lingkungan, keamanan, atau kepolisian bila ada ancaman.',
        'Laporkan informasi yang kamu lihat sendiri tanpa menyebarkan tuduhan yang belum terverifikasi.',
      ],
    ),
    SafetyQuickGuide(
      title: 'Gempa bumi',
      subtitle: 'Perlindungan awal saat guncangan',
      steps: [
        'Saat berada di dalam ruangan: merunduk, berlindung di bawah meja kuat, dan berpegangan sampai guncangan berhenti.',
        'Jauhi kaca, lemari tinggi, serta benda yang dapat jatuh.',
        'Setelah guncangan berhenti, evakuasi melalui jalur aman dan jangan gunakan lift.',
        'Ikuti informasi dari otoritas resmi terkait gempa susulan dan ancaman lainnya.',
      ],
    ),
    SafetyQuickGuide(
      title: 'Banjir atau genangan',
      subtitle: 'Langkah awal sebelum kondisi memburuk',
      steps: [
        'Jauhi aliran air deras, saluran terbuka, dan jalan yang terendam.',
        'Jangan menerobos banjir dengan kendaraan atau berjalan kaki.',
        'Jika aman, pindah ke tempat lebih tinggi dan ikuti arahan evakuasi petugas.',
        'Hindari peralatan listrik yang terkena air dan mintalah bantuan dari tempat aman.',
      ],
    ),
  ];
}
