import { Transform } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
export class CreateOrderDto {
  @IsString()
  @MaxLength(280)
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  bookSlug!: string;
}
export class SubmitPaymentDto {
  @IsIn(['BKASH', 'NAGAD']) method!: 'BKASH' | 'NAGAD';
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsString()
  @Matches(/^[A-Z0-9]{3,100}$/)
  reference!: string;
}
export class RejectPaymentDto {
  // Allowlisted public reasons only; no arbitrary private admin note is echoed.
  @IsIn(['REFERENCE_NOT_FOUND', 'AMOUNT_MISMATCH', 'METHOD_MISMATCH']) reason!:
    'REFERENCE_NOT_FOUND' | 'AMOUNT_MISMATCH' | 'METHOD_MISMATCH';
}
const integer = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' && /^\d{1,5}$/.test(value) ? Number(value) : value;
export class PurchasePageDto {
  @Transform(integer) @IsInt() @Min(1) @Max(10000) page = 1;
  @Transform(integer) @IsInt() @Min(1) @Max(40) pageSize = 12;
}
export class ReviewPageDto extends PurchasePageDto {
  @IsOptional() @IsIn(['PENDING', 'APPROVED', 'REJECTED']) status?:
    'PENDING' | 'APPROVED' | 'REJECTED';
}

export class BookSlugParams {
  @IsString()
  @MaxLength(280)
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  slug!: string;
}
