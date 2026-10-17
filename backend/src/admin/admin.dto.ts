import { PartialType } from './partial-type';
import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  ValidateIf,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { PurchasePageDto } from '../purchases/purchase.dto';
export class AdminQuery extends PurchasePageDto {
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsString()
  @MaxLength(100)
  @Matches(/^[^\p{Cc}]*$/u)
  search?: string;
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsIn([
    'ACTIVE',
    'DISABLED',
    'SUSPENDED',
    'DRAFT',
    'PUBLISHED',
    'ARCHIVED',
    'PENDING_PAYMENT',
    'PAYMENT_SUBMITTED',
    'COMPLETED',
    'CANCELLED',
    'REVOKED',
  ])
  status?: string;
}
const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;
export class CategoryDto {
  @Transform(trim) @IsString() @Length(1, 100) name!: string;
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsString()
  @MaxLength(4000)
  description?: string;
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsBoolean()
  isActive?: boolean;
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsInt()
  @Min(0)
  @Max(100000)
  sortOrder?: number;
}
export class CategoryPatch extends PartialType(CategoryDto) {}
export class BookDto {
  @Transform(trim) @IsString() @Length(1, 240) title!: string;
  @IsString() @Length(1, 20000) description!: string;
  @IsUUID() categoryId!: string;
  @IsString() @Matches(/^(?:0|[1-9]\d{0,9})(?:\.\d{1,2})?$/) price!: string;
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsIn(['BDT'])
  currency?: 'BDT';
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsIn(['DRAFT', 'PUBLISHED', 'ARCHIVED'])
  status?: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
  @ValidateIf((_object: unknown, value: unknown) => value !== undefined)
  @IsInt()
  @Min(1)
  @Max(100000)
  pageCount?: number;
}
export class BookPatch extends PartialType(BookDto) {}
export class UserStatusDto {
  @IsIn(['ACTIVE', 'DISABLED', 'SUSPENDED']) status!:
    'ACTIVE' | 'DISABLED' | 'SUSPENDED';
}
