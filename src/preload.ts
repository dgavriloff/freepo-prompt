import { contextBridge, ipcRenderer } from 'electron';
import type { IElectronAPI, PathNode } from './types';

console.log('Preload script running');

const electronApi: IElectronAPI = {
    log: (message: string) => ipcRenderer.send('log', message),
    openFilePicker: async () => {
        await ipcRenderer.invoke('open-file-picker');
    },
    loadInitialPaths: (): Promise<PathNode[]> => ipcRenderer.invoke('load-initial-paths'),
    onPathsUpdated: (callback: (newPaths: PathNode[]) => void) => {
        ipcRenderer.on('paths-updated', (_, newPaths) => callback(newPaths));
    },
    updatePaths: (paths: PathNode[]) => {
        ipcRenderer.send('update-paths', paths);
    },
    generateReport: (paths: string[]): Promise<string> => {
        return ipcRenderer.invoke('generate-report', paths);
    }
};

contextBridge.exposeInMainWorld('electron', electronApi); 