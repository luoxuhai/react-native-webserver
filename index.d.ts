export interface Request {
  url: string;
  method: "GET" | "POST" | "DELETE" | "PUT" | "OPTIONS" | "HEAD" | "PATCH";
  headers: Record<string, string>;
  query: Record<string, string>;
  body?: Record<string, any>;
  file?: {
    filename: string;
    mimeType: string;
    path: string;
  };
}

export interface Response {
  send: (status?: number, contentType?: string, content?: string) => void;
  sendFile: (path: string) => void;
}

export declare class HttpServer {
  static isRunning: boolean;
  static start(
    port: number,
    name: string,
    callback: (request: Request, response: Response) => void
  ): Promise<any>;
  static stop(): Promise<void>;
}
