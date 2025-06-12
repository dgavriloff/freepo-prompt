export interface IElectronAPI {
    log: (message: string) => void;
    openFilePicker: () => Promise<void>;
    loadInitialPaths: () => Promise<PathNode[]>;
    onPathsUpdated: (callback: (newPaths: PathNode[]) => void) => void;
    updatePaths: (paths: PathNode[]) => void;
    generateReport: (paths: string[]) => Promise<string>;
}

export interface PathNode {
    name: string;
    path: string;
    type: 'file' | 'directory';
    enabled: boolean;
    expanded: boolean;
    children: PathNode[];
}

declare global {
    interface Window {
        electron: IElectronAPI;
    }
} 