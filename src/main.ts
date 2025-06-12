import { app, BrowserWindow, dialog, ipcMain } from 'electron';
import * as path from 'path';
import * as fs from 'fs';
import { exec } from 'child_process';
import { tmpdir } from 'os';
import ignore, { Ignore } from 'ignore';
import { savePaths, loadPaths } from './storage';
import { PathNode } from './types';

async function buildTreeForRoot(rootPath: string): Promise<PathNode | null> {
    let stat;
    try {
        stat = await fs.promises.stat(rootPath);
    } catch (e) {
        console.error(`Could not stat path: ${rootPath}`, e);
        return null; // Path likely doesn't exist
    }

    const baseDir = stat.isDirectory() ? rootPath : path.dirname(rootPath);
    const ig: Ignore = ignore();

    // Add global ignore rules from the app's directory
    const globalRepoignorePath = path.join(app.getAppPath(), '.repoignore');
    if (fs.existsSync(globalRepoignorePath)) {
        ig.add(fs.readFileSync(globalRepoignorePath, 'utf-8'));
    }

    // Add local ignore rules from the selected directory
    const localRepoignorePath = path.join(baseDir, '.repoignore');
    if (fs.existsSync(localRepoignorePath)) {
        ig.add(fs.readFileSync(localRepoignorePath, 'utf-8'));
    }

    async function buildRecursive(currentPath: string): Promise<PathNode | null> {
        const stats = await fs.promises.stat(currentPath);
        
        // Only check paths that are children of the base directory.
        if (currentPath !== baseDir) {
            let relativeToRoot = path.relative(baseDir, currentPath);

            // Ensure directory-specific patterns are matched correctly.
            if (stats.isDirectory()) {
                relativeToRoot += '/';
            }

            if (ig.ignores(relativeToRoot)) {
                return null;
            }
        }

        const name = path.basename(currentPath);

        if (stats.isDirectory()) {
            const children = await fs.promises.readdir(currentPath);
            const childNodes = await Promise.all(
                children.map(child => buildRecursive(path.join(currentPath, child)))
            );
            return {
                name,
                path: currentPath,
                type: 'directory',
                enabled: false,
                expanded: false,
                children: childNodes.filter(Boolean) as PathNode[],
            };
        } else {
            return {
                name,
                path: currentPath,
                type: 'file',
                enabled: false,
                expanded: false,
                children: [],
            };
        }
    }

    return buildRecursive(rootPath);
}

process.stdout.write('Main process starting\n');

function createWindow() {
  process.stdout.write('Creating window\n');
  const mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  mainWindow.webContents.on('did-finish-load', async () => {
    const paths = loadPaths();
    const tree = await Promise.all(paths.map(buildTreeForRoot));
    mainWindow.webContents.send('paths-updated', tree.filter(Boolean));
  });

  process.stdout.write('Loading index.html\n');
  mainWindow.loadFile(path.join(__dirname, '../index.html'));
  
  // Open DevTools in development
  if (process.env.NODE_ENV === 'development') {
    process.stdout.write('Opening DevTools\n');
    mainWindow.webContents.openDevTools();
  }
}

ipcMain.handle('load-initial-paths', async () => {
    const paths = loadPaths();
    const tree = await Promise.all(paths.map(buildTreeForRoot));
    return tree.filter(Boolean);
});

// Handle file picker dialog
ipcMain.handle('open-file-picker', async (event) => {
  process.stdout.write('Main: open-file-picker called\n');
  try {
    const result = await dialog.showOpenDialog({
      properties: ['openFile', 'openDirectory', 'multiSelections']
    });
    
    process.stdout.write(`Main: dialog result: ${JSON.stringify(result)}\n`);
    if (!result.canceled && result.filePaths.length > 0) {
      const existingPaths = loadPaths();
      const newPaths = result.filePaths;
      const updatedPaths = [...new Set([...existingPaths, ...newPaths])];
      savePaths(updatedPaths);
      
      const tree = await Promise.all(updatedPaths.map(buildTreeForRoot));
      event.sender.send('paths-updated', tree.filter(Boolean));
    }
    return null;
  } catch (error) {
    process.stdout.write(`Main: Error in open-file-picker: ${error}\n`);
    throw error;
  }
});

// Handle logs from renderer
ipcMain.on('log', (_, message) => {
  process.stdout.write(`Renderer: ${message}\n`);
});

// Handle path updates from renderer
ipcMain.on('update-paths', async (event, paths: PathNode[]) => {
  const rootPaths = paths.map(node => node.path);
  savePaths(rootPaths);
  event.sender.send('paths-updated', paths);
});

ipcMain.handle('generate-report', async (_, paths: string[]) => {
    try {
        // Create a temporary file for the C++ generator
        const tempFilePath = path.join(tmpdir(), `freepo-paths-${Date.now()}.txt`);
        await fs.promises.writeFile(tempFilePath, paths.join('\n'));
        
        // Get the path to the generate_report executable
        const isDev = process.env.NODE_ENV === 'development';
        const generateReportPath = isDev 
            ? path.join(__dirname, '..', 'generate_report')
            : path.join(process.resourcesPath, 'generate_report');
        
        // Run the C++ generator
        const result = await new Promise<string>((resolve, reject) => {
            exec(`"${generateReportPath}" "${tempFilePath}"`, (error, stdout, stderr) => {
                if (error) {
                    reject(`Error: ${error.message}`);
                    return;
                }
                if (stderr) {
                    reject(`Error: ${stderr}`);
                    return;
                }
                resolve(stdout);
            });
        });

        // Clean up the temporary file
        await fs.promises.unlink(tempFilePath);
        
        return result;
    } catch (error) {
        console.error('Error generating report:', error);
        throw error;
    }
});

app.whenReady().then(() => {
  process.stdout.write('App ready\n');
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
}); 