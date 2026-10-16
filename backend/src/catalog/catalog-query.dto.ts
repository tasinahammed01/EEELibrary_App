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
const integer = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' && /^\d{1,7}$/.test(value) ? Number(value) : value;
export class CatalogQueryDto {
  @Transform(integer) @IsInt() @Min(1) @Max(10000) page = 1;
  @Transform(integer) @IsInt() @Min(1) @Max(40) pageSize = 12;
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsString()
  @MaxLength(120)
  search?: string;
  @IsOptional()
  @IsString()
  @MaxLength(160)
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  category?: string;
  @IsIn(['newest', 'title', 'price-asc', 'price-desc']) sort:
    'newest' | 'title' | 'price-asc' | 'price-desc' = 'newest';
}
