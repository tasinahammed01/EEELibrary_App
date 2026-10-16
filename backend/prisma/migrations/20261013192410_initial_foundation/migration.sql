BEGIN;

-- Case-insensitive email and payment-reference uniqueness.
CREATE EXTENSION IF NOT EXISTS citext;

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'DISABLED');

-- CreateEnum
CREATE TYPE "PublicationStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('BKASH', 'NAGAD');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('PENDING_PAYMENT', 'PAYMENT_SUBMITTED', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "EntitlementStatus" AS ENUM ('ACTIVE', 'REVOKED');

-- CreateEnum
CREATE TYPE "DevicePlatform" AS ENUM ('ANDROID', 'IOS', 'WEB', 'OTHER');

-- CreateEnum
CREATE TYPE "DeviceStatus" AS ENUM ('ACTIVE', 'REVOKED');

-- CreateEnum
CREATE TYPE "AdminRole" AS ENUM ('SUPER_ADMIN', 'CONTENT_MANAGER', 'PAYMENT_REVIEWER');

-- CreateEnum
CREATE TYPE "AdminStatus" AS ENUM ('ACTIVE', 'DISABLED');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "externalAuthId" VARCHAR(128) NOT NULL,
    "email" CITEXT NOT NULL,
    "displayName" VARCHAR(120) NOT NULL,
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Category" (
    "id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "slug" VARCHAR(160) NOT NULL,
    "description" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Category_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Book" (
    "id" UUID NOT NULL,
    "title" VARCHAR(240) NOT NULL,
    "slug" VARCHAR(280) NOT NULL,
    "description" TEXT NOT NULL,
    "categoryId" UUID NOT NULL,
    "price" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'BDT',
    "status" "PublicationStatus" NOT NULL DEFAULT 'DRAFT',
    "pageCount" INTEGER,
    "previewPageCount" INTEGER NOT NULL DEFAULT 0,
    "coverObjectKey" VARCHAR(512),
    "coverAltText" VARCHAR(240),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Book_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Order" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "bookId" UUID NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'BDT',
    "status" "OrderStatus" NOT NULL DEFAULT 'PENDING_PAYMENT',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Order_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Payment" (
    "id" UUID NOT NULL,
    "orderId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "transactionReference" CITEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'BDT',
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "reviewedById" UUID,
    "reviewedAt" TIMESTAMPTZ(3),
    "rejectionReason" VARCHAR(500),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Payment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Entitlement" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "bookId" UUID NOT NULL,
    "orderId" UUID NOT NULL,
    "status" "EntitlementStatus" NOT NULL DEFAULT 'REVOKED',
    "revokedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Entitlement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Device" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "deviceIdentifier" VARCHAR(256) NOT NULL,
    "name" VARCHAR(120),
    "platform" "DevicePlatform" NOT NULL,
    "status" "DeviceStatus" NOT NULL DEFAULT 'ACTIVE',
    "lastSeenAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "deviceId" UUID NOT NULL,
    "tokenHash" CHAR(64) NOT NULL,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "revokedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReadingProgress" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "bookId" UUID NOT NULL,
    "lastPage" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "ReadingProgress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdminUser" (
    "id" UUID NOT NULL,
    "externalAuthId" VARCHAR(128) NOT NULL,
    "email" CITEXT NOT NULL,
    "displayName" VARCHAR(120) NOT NULL,
    "role" "AdminRole" NOT NULL,
    "status" "AdminStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "AdminUser_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" UUID NOT NULL,
    "adminActorId" UUID NOT NULL,
    "action" VARCHAR(100) NOT NULL,
    "targetType" VARCHAR(100) NOT NULL,
    "targetId" UUID NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_externalAuthId_key" ON "User"("externalAuthId");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_status_createdAt_idx" ON "User"("status", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Category_slug_key" ON "Category"("slug");

-- CreateIndex
CREATE INDEX "Category_isActive_sortOrder_idx" ON "Category"("isActive", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "Book_slug_key" ON "Book"("slug");

-- CreateIndex
CREATE INDEX "Book_categoryId_status_createdAt_idx" ON "Book"("categoryId", "status", "createdAt");

-- CreateIndex
CREATE INDEX "Book_status_createdAt_idx" ON "Book"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Order_userId_createdAt_idx" ON "Order"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "Order_bookId_idx" ON "Order"("bookId");

-- CreateIndex
CREATE INDEX "Order_status_createdAt_idx" ON "Order"("status", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Order_id_userId_key" ON "Order"("id", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "Order_id_userId_bookId_key" ON "Order"("id", "userId", "bookId");

-- CreateIndex
CREATE UNIQUE INDEX "Payment_transactionReference_key" ON "Payment"("transactionReference");

-- CreateIndex
CREATE INDEX "Payment_orderId_userId_idx" ON "Payment"("orderId", "userId");

-- CreateIndex
CREATE INDEX "Payment_userId_createdAt_idx" ON "Payment"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "Payment_status_createdAt_idx" ON "Payment"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Payment_reviewedById_idx" ON "Payment"("reviewedById");

-- CreateIndex
CREATE UNIQUE INDEX "Entitlement_orderId_key" ON "Entitlement"("orderId");

-- CreateIndex
CREATE INDEX "Entitlement_userId_status_createdAt_idx" ON "Entitlement"("userId", "status", "createdAt");

-- CreateIndex
CREATE INDEX "Entitlement_bookId_idx" ON "Entitlement"("bookId");

-- CreateIndex
CREATE UNIQUE INDEX "Entitlement_userId_bookId_key" ON "Entitlement"("userId", "bookId");

-- CreateIndex
CREATE INDEX "Device_userId_status_lastSeenAt_idx" ON "Device"("userId", "status", "lastSeenAt");

-- CreateIndex
CREATE UNIQUE INDEX "Device_userId_deviceIdentifier_key" ON "Device"("userId", "deviceIdentifier");

-- CreateIndex
CREATE UNIQUE INDEX "Device_id_userId_key" ON "Device"("id", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "Session_tokenHash_key" ON "Session"("tokenHash");

-- CreateIndex
CREATE INDEX "Session_deviceId_userId_idx" ON "Session"("deviceId", "userId");

-- CreateIndex
CREATE INDEX "Session_userId_revokedAt_expiresAt_idx" ON "Session"("userId", "revokedAt", "expiresAt");

-- CreateIndex
CREATE INDEX "Session_expiresAt_idx" ON "Session"("expiresAt");

-- CreateIndex
CREATE INDEX "ReadingProgress_userId_updatedAt_idx" ON "ReadingProgress"("userId", "updatedAt");

-- CreateIndex
CREATE INDEX "ReadingProgress_bookId_idx" ON "ReadingProgress"("bookId");

-- CreateIndex
CREATE UNIQUE INDEX "ReadingProgress_userId_bookId_key" ON "ReadingProgress"("userId", "bookId");

-- CreateIndex
CREATE UNIQUE INDEX "AdminUser_externalAuthId_key" ON "AdminUser"("externalAuthId");

-- CreateIndex
CREATE UNIQUE INDEX "AdminUser_email_key" ON "AdminUser"("email");

-- CreateIndex
CREATE INDEX "AdminUser_status_role_idx" ON "AdminUser"("status", "role");

-- CreateIndex
CREATE INDEX "AuditLog_adminActorId_createdAt_idx" ON "AuditLog"("adminActorId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_targetType_targetId_createdAt_idx" ON "AuditLog"("targetType", "targetId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_action_createdAt_idx" ON "AuditLog"("action", "createdAt");

-- AddForeignKey
ALTER TABLE "Book" ADD CONSTRAINT "Book_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "Category"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "Book"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_orderId_userId_fkey" FOREIGN KEY ("orderId", "userId") REFERENCES "Order"("id", "userId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "AdminUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Entitlement" ADD CONSTRAINT "Entitlement_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Entitlement" ADD CONSTRAINT "Entitlement_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "Book"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Entitlement" ADD CONSTRAINT "Entitlement_orderId_userId_bookId_fkey" FOREIGN KEY ("orderId", "userId", "bookId") REFERENCES "Order"("id", "userId", "bookId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_deviceId_userId_fkey" FOREIGN KEY ("deviceId", "userId") REFERENCES "Device"("id", "userId") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReadingProgress" ADD CONSTRAINT "ReadingProgress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReadingProgress" ADD CONSTRAINT "ReadingProgress_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "Book"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_adminActorId_fkey" FOREIGN KEY ("adminActorId") REFERENCES "AdminUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Prisma does not express PostgreSQL CHECKs or partial unique indexes.
ALTER TABLE "User" ADD CONSTRAINT "User_email_trimmed" CHECK (email::text = btrim(email::text) AND length(email::text) > 3);
ALTER TABLE "AdminUser" ADD CONSTRAINT "AdminUser_email_trimmed" CHECK (email::text = btrim(email::text) AND length(email::text) > 3);
ALTER TABLE "Book" ADD CONSTRAINT "Book_price_nonnegative" CHECK (price >= 0),
  ADD CONSTRAINT "Book_currency_bdt" CHECK (currency = 'BDT'),
  ADD CONSTRAINT "Book_page_metadata_valid" CHECK (("pageCount" IS NULL AND "previewPageCount" = 0) OR ("pageCount" > 0 AND "previewPageCount" >= 0 AND "previewPageCount" <= "pageCount"));
ALTER TABLE "Order" ADD CONSTRAINT "Order_amount_nonnegative" CHECK (amount >= 0),
  ADD CONSTRAINT "Order_currency_bdt" CHECK (currency = 'BDT');
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_amount_positive" CHECK (amount > 0),
  ADD CONSTRAINT "Payment_currency_bdt" CHECK (currency = 'BDT'),
  ADD CONSTRAINT "Payment_reference_canonical" CHECK ("transactionReference"::text ~ '^[A-Za-z0-9]{3,100}$'),
  ADD CONSTRAINT "Payment_review_consistent" CHECK (
    (status = 'PENDING' AND "reviewedAt" IS NULL AND "reviewedById" IS NULL AND "rejectionReason" IS NULL) OR
    (status = 'APPROVED' AND "reviewedAt" IS NOT NULL AND "reviewedById" IS NOT NULL AND "rejectionReason" IS NULL) OR
    (status = 'REJECTED' AND "reviewedAt" IS NOT NULL AND "reviewedById" IS NOT NULL AND length(btrim("rejectionReason")) > 0)
  );
CREATE UNIQUE INDEX "Payment_one_approved_per_order" ON "Payment" ("orderId") WHERE status = 'APPROVED';
ALTER TABLE "Entitlement" ADD CONSTRAINT "Entitlement_active_not_revoked" CHECK (status <> 'ACTIVE' OR "revokedAt" IS NULL);
ALTER TABLE "Device" ADD CONSTRAINT "Device_identifier_nonempty" CHECK (length(btrim("deviceIdentifier")) > 0);
ALTER TABLE "Session" ADD CONSTRAINT "Session_hash_digest" CHECK ("tokenHash" ~ '^[a-f0-9]{64}$'),
  ADD CONSTRAINT "Session_expiry_valid" CHECK ("expiresAt" > "createdAt");
ALTER TABLE "ReadingProgress" ADD CONSTRAINT "ReadingProgress_page_positive" CHECK ("lastPage" >= 1);

-- Audit events remain immutable even if a future writer mistakenly updates them.
CREATE FUNCTION eeelibrary_reject_audit_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Audit events are immutable';
END;
$$;
CREATE TRIGGER "AuditLog_immutable" BEFORE UPDATE OR DELETE ON "AuditLog"
FOR EACH ROW EXECUTE FUNCTION eeelibrary_reject_audit_mutation();

COMMIT;
