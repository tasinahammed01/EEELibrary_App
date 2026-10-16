BEGIN;

-- SQL CHECK accepts NULL: explicitly distinguish unknown page counts/reasons.
ALTER TABLE "Book" DROP CONSTRAINT "Book_page_metadata_valid",
  ADD CONSTRAINT "Book_page_metadata_valid" CHECK (
    ("pageCount" IS NULL AND "previewPageCount" = 0) OR
    ("pageCount" IS NOT NULL AND "pageCount" > 0 AND "previewPageCount" >= 0 AND "previewPageCount" <= "pageCount")
  );
ALTER TABLE "Payment" DROP CONSTRAINT "Payment_review_consistent",
  ADD CONSTRAINT "Payment_review_consistent" CHECK (
    (status = 'PENDING' AND "reviewedAt" IS NULL AND "reviewedById" IS NULL AND "rejectionReason" IS NULL) OR
    (status = 'APPROVED' AND "reviewedAt" IS NOT NULL AND "reviewedById" IS NOT NULL AND "rejectionReason" IS NULL) OR
    (status = 'REJECTED' AND "reviewedAt" IS NOT NULL AND "reviewedById" IS NOT NULL AND "rejectionReason" IS NOT NULL AND length(btrim("rejectionReason")) > 0)
  );

COMMIT;
