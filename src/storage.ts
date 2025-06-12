import { app } from 'electron';
import * as fs from 'fs';
import * as path from 'path';

const storagePath = path.join(app.getPath('userData'), 'user-data.json');

export interface IStorageData {
    paths: string[];
}

export function savePaths(paths: string[]): void {
    const data: IStorageData = { paths };
    fs.writeFileSync(storagePath, JSON.stringify(data, null, 2));
}

export function loadPaths(): string[] {
    try {
        if (fs.existsSync(storagePath)) {
            const data = fs.readFileSync(storagePath, 'utf-8');
            const parsedData: IStorageData = JSON.parse(data);
            return parsedData.paths || [];
        }
    } catch (error) {
        console.error('Error loading paths:', error);
    }
    return [];
} 