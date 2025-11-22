// ============================================
// STRUCTURED LOGGING UTILITY
// ============================================
// Provides consistent, parseable logging for edge functions
// Optimized for manual testing and debugging

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
}

interface LogContext {
  functionName: string;
  requestId?: string;
  userId?: string;
  deviceId?: string;
  [key: string]: any;
}

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  function: string;
  message: string;
  requestId?: string;
  userId?: string;
  deviceId?: string;
  duration?: number; // milliseconds
  data?: any;
}

class Logger {
  private functionName: string;
  private requestId?: string;
  private startTime: number;
  private context: LogContext;

  constructor(functionName: string, requestId?: string, context?: Partial<LogContext>) {
    this.functionName = functionName;
    this.requestId = requestId || this.generateRequestId();
    this.startTime = Date.now();
    this.context = {
      functionName,
      requestId: this.requestId,
      ...context,
    };
  }

  private generateRequestId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private formatLog(level: LogLevel, message: string, data?: any, duration?: number): string {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      function: this.functionName,
      message,
      requestId: this.requestId,
      ...(this.context.userId && { userId: this.context.userId }),
      ...(this.context.deviceId && { deviceId: this.context.deviceId }),
      ...(duration !== undefined && { duration }),
      ...(data && { data }),
    };

    // JSON format for easy parsing
    return JSON.stringify(entry);
  }

  private log(level: LogLevel, message: string, data?: any): void {
    const duration = Date.now() - this.startTime;
    const logMessage = this.formatLog(level, message, data, duration);
    
    // Use appropriate console method based on level
    switch (level) {
      case LogLevel.ERROR:
        console.error(logMessage);
        break;
      case LogLevel.WARN:
        console.warn(logMessage);
        break;
      case LogLevel.DEBUG:
        // DEBUG logs disabled in production (too verbose)
        // For debugging, check Supabase logs or use INFO/ERROR level
        // console.log(logMessage);  // Commented out - only enable for urgent debugging
        break;
      default:
        console.log(logMessage);
    }
  }

  // Public logging methods
  debug(message: string, data?: any): void {
    this.log(LogLevel.DEBUG, message, data);
  }

  info(message: string, data?: any): void {
    this.log(LogLevel.INFO, message, data);
  }

  warn(message: string, data?: any): void {
    this.log(LogLevel.WARN, message, data);
  }

  error(message: string, error?: any): void {
    const errorData = error instanceof Error 
      ? { message: error.message, stack: error.stack }
      : error;
    this.log(LogLevel.ERROR, message, errorData);
  }

  // Step tracking (for manual testing)
  step(stepName: string, data?: any): void {
    this.debug(`[STEP] ${stepName}`, data);  // Changed to DEBUG for production
  }

  // Performance tracking
  time(label: string): void {
    this.info(`[TIMER] ${label}`, { elapsed: Date.now() - this.startTime });
  }

  // Request summary (call at end of function)
  summary(result: 'success' | 'error', data?: any): void {
    const totalDuration = Date.now() - this.startTime;
    this.info(`[SUMMARY] Request ${result}`, {
      ...data,
      totalDuration,
      requestId: this.requestId,
    });
  }

  // Get request ID for tracking
  getRequestId(): string {
    return this.requestId!;
  }

  // Update context
  setContext(context: Partial<LogContext>): void {
    this.context = { ...this.context, ...context };
  }
}

// Factory function for easy creation
export function createLogger(functionName: string, requestId?: string, context?: Partial<LogContext>): Logger {
  return new Logger(functionName, requestId, context);
}

// Helper to extract request ID from request
export function extractRequestId(req: Request): string | undefined {
  // Try to get from header
  const headerId = req.headers.get('x-request-id');
  if (headerId) return headerId;

  // Try to get from body (for POST requests)
  // Note: This requires async body parsing, so it's better to pass it explicitly
  return undefined;
}


