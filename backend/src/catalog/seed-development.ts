import 'dotenv/config';
import { ConfigService } from '@nestjs/config';
import { Environment, validateEnvironment } from '../config/environment';
import { PrismaService } from '../database/prisma.service';
export async function seedDevelopment(): Promise<void> {
  const config = validateEnvironment(process.env);
  if (
    config.NODE_ENV !== 'development' ||
    !['127.0.0.1', 'localhost'].includes(new URL(config.DATABASE_URL).hostname)
  )
    throw new Error('Seed requires a loopback development database');
  const db = new PrismaService(new ConfigService<Environment, true>(config));
  try {
    await db.onModuleInit();
    const names = [
      'Circuit Theory',
      'Electronics',
      'Electrical Machines',
      'Power Systems',
      'Control Systems',
      'Signals and Systems',
      'Communication',
      'Job Preparation',
    ];
    await db.$transaction(async (tx) => {
      for (const [index, name] of names.entries()) {
        const slug = 'dev-sample-' + name.toLowerCase().replace(/ /g, '-');
        // Empty updates preserve all edits; createMany skips collisions instead of relinking content.
        await tx.category.createMany({
          data: [
            {
              name,
              slug,
              description: 'Development sample category',
              sortOrder: index,
            },
          ],
          skipDuplicates: true,
        });
        const category = await tx.category.findUniqueOrThrow({
          where: { slug },
        });
        if (category.description !== 'Development sample category')
          throw new Error('Sample namespace occupied; no data changed');
        await tx.book.createMany({
          data: [
            {
              slug: slug + '-study-guide',
              title: name + ' Study Guide (Development Sample)',
              description:
                'Development sample metadata for catalog testing. No book file, purchase, or reading access is provided.',
              categoryId: category.id,
              price: index === 0 ? 0 : 120 + index * 30,
              currency: 'BDT',
              status: 'PUBLISHED',
              pageCount: 80 + index * 16,
            },
          ],
          skipDuplicates: true,
        });
      }
    });
    console.log(
      'Development catalog seed complete; existing records preserved.',
    );
  } finally {
    await db.onModuleDestroy();
  }
}
if (require.main === module)
  void seedDevelopment().catch(() => {
    console.error('Development seed failed safely');
    process.exitCode = 1;
  });
