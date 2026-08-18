// Variables de entorno para configuración dinámica
const DEEPWIKI_RETRY_DELAY = parseInt(process.env.DEEPWIKI_RETRY_DELAY || '250', 10);
const DEEPWIKI_MAX_RETRIES = parseInt(process.env.DEEPWIKI_MAX_RETRIES || '3', 10);
const JITTER_MAX = 100; // Milisegundos máximos de fluctuación aleatoria

export async function withExponentialBackoff<T>(
  operation: () => Promise<T>,
  retries = DEEPWIKI_MAX_RETRIES,
  attempt = 0
): Promise<T> {
  try {
    return await operation();
  } catch (error: any) {
    const status = error.status;
    // Reintentar si hay límite de tasa, error de servidor, o si es un error de red puro (sin status HTTP y no es un SyntaxError)
    const isRetryable = status === 429 || (status >= 502 && status <= 504) || (!status && !(error instanceof SyntaxError));

    if (isRetryable && attempt < retries) {
      // Fórmula matemática de retraso: Retraso Base * (2^N)
      const baseDelay = DEEPWIKI_RETRY_DELAY * Math.pow(2, attempt);
      
      // Inyección de fluctuación (Jitter): random(0, Jitter_Max)
      const jitter = Math.floor(Math.random() * JITTER_MAX);
      
      const finalDelay = baseDelay + jitter;
      
      console.warn(`[Limitador de Tasa / Timeout] Intento ${attempt + 1} fallido (HTTP ${status || 'Red'}). Reintentando en ${finalDelay}ms...`);
      
      // Pausar la promesa asíncrona
      await new Promise(resolve => setTimeout(resolve, finalDelay));
      
      // Llamada recursiva incrementando el contador de intentos
      return withExponentialBackoff(operation, retries, attempt + 1);
    }
    
    // Descarte definitivo: Límite superado o error fatal no reintentable
    throw error;
  }
}
