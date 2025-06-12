# Electron Application

A basic Electron application template.

## Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Run in production mode
npm start

# Build the application
npm run build
```
denisgavriloff@Deniss-Mac-mini freepo-prompt % npm run dev

> freepo-prompt@1.0.0 dev
> NODE_ENV=development electron -r ts-node/register src/main.ts

App threw an error during load
TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".ts" for /Users/denisgavriloff/Repos/freepo-prompt/src/main.ts
    at new NodeError (node:internal/errors:406:5)
    at Object.getFileProtocolModuleFormat [as file:] (node:internal/modules/esm/get_format:100:9)
    at defaultGetFormat (node:internal/modules/esm/get_format:143:36)
    at defaultLoad (node:internal/modules/esm/load:119:20)
    at ModuleLoader.load (node:internal/modules/esm/loader:396:13)
    at ModuleLoader.moduleProvider (node:internal/modules/esm/loader:278:56)
    at new ModuleJob (node:internal/modules/esm/module_job:65:26)
    at ModuleLoader.#createModuleJob (node:internal/modules/esm/loader:290:17)
    at ModuleLoader.getJobFromResolveResult (node:internal/modules/esm/loader:248:34)
    at ModuleLoader.getModuleJob (node:internal/modules/esm/loader:229:17)
