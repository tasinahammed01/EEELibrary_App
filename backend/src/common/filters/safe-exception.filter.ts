import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  Logger,
} from '@nestjs/common';
import { STATUS_CODES } from 'node:http';
import { Response } from 'express';

@Catch()
export class SafeExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(SafeExceptionFilter.name);
  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : this.parserStatus(exception);
    if (status >= 500)
      this.logger.error('Request failed with an internal server error');
    // Never serialize arbitrary exception messages, SQL, credentials or stacks.
    response.status(status).json({
      statusCode: status,
      message: STATUS_CODES[status] ?? 'Internal Server Error',
    });
  }
  private parserStatus(error: unknown): number {
    if (typeof error === 'object' && error !== null && 'type' in error) {
      if (error.type === 'entity.too.large') return 413;
      if (error.type === 'entity.parse.failed') return 400;
    }
    return 500;
  }
}
