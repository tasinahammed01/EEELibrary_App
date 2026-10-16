import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Environment } from '../config/environment';
@Injectable()
export class ManualPaymentOptions {
  constructor(private readonly config: ConfigService<Environment, true>) {}
  list() {
    const development =
      this.config.get('NODE_ENV', { infer: true }) === 'development' &&
      this.config.get('MANUAL_PAYMENT_DEVELOPMENT_MODE', { infer: true });
    return (['BKASH', 'NAGAD'] as const).flatMap((method) => {
      const instructions = this.config.get(
        method === 'BKASH'
          ? 'MANUAL_PAYMENT_BKASH_INSTRUCTIONS'
          : 'MANUAL_PAYMENT_NAGAD_INSTRUCTIONS',
        { infer: true },
      );
      if (instructions) return [{ method, instructions, development: false }];
      return development
        ? [
            {
              method,
              instructions:
                'DEVELOPMENT ONLY. Do not transfer money. Use a test reference for local workflow testing.',
              development: true,
            },
          ]
        : [];
    });
  }
  require(method?: string): void {
    const options = this.list();
    if (
      !options.length ||
      (method !== undefined &&
        !options.some((option) => option.method === method))
    )
      throw new ServiceUnavailableException();
  }
}
