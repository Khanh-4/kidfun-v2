const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const CATEGORIES = [
  {
    name: 'adult',
    displayName: 'Người lớn',
    description: 'Nội dung 18+, khiêu dâm',
    domains: [
      'pornhub.com', 'xvideos.com', 'xnxx.com', 'xhamster.com',
      'redtube.com', 'youporn.com', 'sexvn.com', 'phimxxx.com',
    ],
  },
  {
    name: 'gambling',
    displayName: 'Cờ bạc',
    description: 'Cá cược, bài bạc trực tuyến',
    domains: [
      'bet365.com', 'fun88.com', 'w88.com', '188bet.com',
      'dafabet.com', '12bet.com', 'casino.com',
    ],
  },
  {
    name: 'violence',
    displayName: 'Bạo lực',
    description: 'Nội dung bạo lực, máu me',
    domains: [
      'liveleak.com', 'bestgore.com', 'documentingreality.com',
    ],
  },
  {
    name: 'social_media',
    displayName: 'Mạng xã hội',
    description: 'Facebook, Instagram, TikTok,...',
    domains: [
      'facebook.com', 'instagram.com', 'tiktok.com', 'twitter.com',
      'x.com', 'snapchat.com', 'threads.net',
    ],
  },
  {
    name: 'gaming',
    displayName: 'Game online',
    description: 'Web game, gaming platforms',
    domains: [
      'y8.com', 'friv.com', 'poki.com', 'miniclip.com',
      'crazygames.com', 'kizi.com',
    ],
  },
];

async function main() {
  console.log('🌱 Seeding web categories...\n');

  for (const cat of CATEGORIES) {
    const category = await prisma.webCategory.upsert({
      where: { name: cat.name },
      update: { displayName: cat.displayName, description: cat.description },
      create: { name: cat.name, displayName: cat.displayName, description: cat.description },
    });

    for (const domain of cat.domains) {
      await prisma.webCategoryDomain.upsert({
        where: { categoryId_domain: { categoryId: category.id, domain } },
        update: {},
        create: { categoryId: category.id, domain },
      });
    }

    console.log(`✅ ${cat.displayName}: ${cat.domains.length} domains`);
  }

  console.log('\n🎉 Web categories seeded!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
