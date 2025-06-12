// src/types/ignore.d.ts
declare module 'ignore' {
  interface Ignore {
    add(pattern: string | string[]): this;
    ignores(pathname: string): boolean;
    filter(paths: string[]): string[];
  }
  function ignore(): Ignore;
  export = ignore;
} 