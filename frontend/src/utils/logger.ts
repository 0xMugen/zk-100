type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  timestamp: Date;
  level: LogLevel;
  message: string;
  data?: any;
}

class Logger {
  private logs: LogEntry[] = [];
  private maxLogs = 1000;
  private listeners: ((logs: LogEntry[]) => void)[] = [];

  private log(level: LogLevel, message: string, data?: any) {
    const entry: LogEntry = {
      timestamp: new Date(),
      level,
      message,
      data,
    };

    this.logs.push(entry);
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }

    // Console output with styling
    const styles = {
      debug: 'color: #gray; font-weight: normal;',
      info: 'color: #0066cc; font-weight: normal;',
      warn: 'color: #ff9900; font-weight: bold;',
      error: 'color: #ff0000; font-weight: bold;',
    };

    console.log(
      `%c[${entry.timestamp.toISOString()}] ${level.toUpperCase()}: ${message}`,
      styles[level]
    );
    if (data) {
      console.log(data);
    }

    this.notifyListeners();
  }

  debug(message: string, data?: any) {
    this.log('debug', message, data);
  }

  info(message: string, data?: any) {
    this.log('info', message, data);
  }

  warn(message: string, data?: any) {
    this.log('warn', message, data);
  }

  error(message: string, data?: any) {
    this.log('error', message, data);
  }

  getLogs(): LogEntry[] {
    return [...this.logs];
  }

  clearLogs() {
    this.logs = [];
    this.notifyListeners();
  }

  subscribe(listener: (logs: LogEntry[]) => void) {
    this.listeners.push(listener);
  }

  unsubscribe(listener: (logs: LogEntry[]) => void) {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  private notifyListeners() {
    this.listeners.forEach(listener => listener(this.getLogs()));
  }

  // Specific logging helpers for ZK-100
  logNodeCode(nodeId: string, code: string) {
    this.debug(`Node ${nodeId} code updated`, { nodeId, code });
  }

  logValidation(nodeId: string, errors: any[]) {
    if (errors.length > 0) {
      this.warn(`Node ${nodeId} validation errors`, { nodeId, errors });
    } else {
      this.debug(`Node ${nodeId} validation passed`, { nodeId });
    }
  }

  logExecution(request: any) {
    this.info('Executing program', { request });
  }

  logExecutionResult(result: any) {
    if (result.success) {
      this.info('Execution successful', result);
    } else {
      this.error('Execution failed', result);
    }
  }

  logCairoOutput(output: string) {
    this.info('Cairo execution output', { output });
  }

  logProverOutput(output: string) {
    this.info('Prover output', { output });
  }

  logBackendError(error: any) {
    this.error('Backend error', error);
  }
}

export const logger = new Logger();