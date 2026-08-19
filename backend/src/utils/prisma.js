const { PrismaClient } = require('@prisma/client');

const globalForPrisma = globalThis;

const prisma = globalForPrisma.__prisma ?? new PrismaClient();

globalForPrisma.__prisma = prisma;

module.exports = prisma;
