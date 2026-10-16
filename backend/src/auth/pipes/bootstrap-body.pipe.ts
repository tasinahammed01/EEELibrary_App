import { BadRequestException, Injectable, PipeTransform } from '@nestjs/common';

@Injectable()
export class BootstrapBodyPipe implements PipeTransform<unknown, undefined> {
  transform(body: unknown): undefined {
    if (
      body === undefined ||
      (typeof body === 'object' &&
        body !== null &&
        !Array.isArray(body) &&
        Object.keys(body).length === 0)
    )
      return undefined;
    throw new BadRequestException();
  }
}
