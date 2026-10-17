import { getMetadataStorage, ValidateIf } from 'class-validator';
export function PartialType<T extends object>(
  Base: new () => T,
): new () => Partial<T> {
  class Patch extends Base {}
  const fields = new Set(
    getMetadataStorage()
      .getTargetValidationMetadatas(Base, '', false, false)
      .map((m) => m.propertyName),
  );
  for (const field of fields)
    ValidateIf((_object: unknown, value: unknown) => value !== undefined)(
      Patch.prototype,
      field,
    );
  return Patch;
}
