import type { IElectronAPI, PathNode } from './types';

declare global {
    interface Window {
        electron: IElectronAPI;
    }
}

function debounce<F extends (...args: any[]) => any>(func: F, waitFor: number) {
    let timeout: ReturnType<typeof setTimeout> | null = null;

    const debounced = (...args: Parameters<F>): void => {
        if (timeout !== null) {
            clearTimeout(timeout);
            timeout = null;
        }
        timeout = setTimeout(() => func(...args), waitFor);
    };

    return debounced;
}

let currentPaths: PathNode[] = [];

function getSelectedPaths(nodes: PathNode[], selected: string[] = []): string[] {
    for (const node of nodes) {
        if (node.enabled) {
            selected.push(node.path);
        }
        if (node.children) {
            getSelectedPaths(node.children, selected);
        }
    }
    return selected;
}

const debouncedUpdateSelectionDisplay = debounce(updateSelectionDisplay, 300);

function updateSelectionDisplay() {
    const textContainer = document.getElementById('text-container');
    if (textContainer) {
        const selectedPaths = getSelectedPaths(currentPaths);
        if (selectedPaths.length > 0) {
            textContainer.innerHTML = `<strong>Selected Paths:</strong><pre>${selectedPaths.join('\n')}</pre>`;
        } else {
            textContainer.innerHTML = '<em>No items selected.</em>';
        }
    }
}

function updateChildren(node: PathNode, enabled: boolean) {
    node.enabled = enabled;
    node.children.forEach(child => updateChildren(child, enabled));
}

function renderNode(node: PathNode): HTMLElement {
    const li = document.createElement('li');
    li.className = 'path-list-item';
    li.title = node.path;

    const container = document.createElement('div');
    container.className = 'path-item-container';

    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.checked = node.enabled;
    checkbox.addEventListener('click', (e) => {
        e.stopPropagation();
        updateChildren(node, checkbox.checked);
        render(currentPaths); // Re-render to show updated state
        updateRemoveButtonState();
        updateGenerateButtonState();
    });

    const span = document.createElement('span');
    span.className = 'path-text';
    span.textContent = node.name;

    container.appendChild(checkbox);
    container.appendChild(span);

    if (node.type === 'directory') {
        const arrow = document.createElement('span');
        arrow.className = `arrow ${node.expanded ? 'expanded' : ''}`;
        arrow.innerHTML = '›';
        container.appendChild(arrow);

        const childrenContainer = document.createElement('ul');
        childrenContainer.className = 'path-list';
        if (node.expanded) {
            node.children.forEach(child => {
                childrenContainer.appendChild(renderNode(child));
            });
        }
        li.appendChild(container);
        li.appendChild(childrenContainer);

        container.addEventListener('click', () => {
            node.expanded = !node.expanded;
            render(currentPaths); // Re-render the entire tree
        });

    } else {
        li.appendChild(container);
    }
    
    return li;
}

function render(nodes: PathNode[]) {
    const pathList = document.getElementById('path-list');
    if (pathList) {
        pathList.innerHTML = '';
        nodes.forEach(node => {
            pathList.appendChild(renderNode(node));
        });
    }
}

function hasSelectedRootPaths(nodes: PathNode[]): boolean {
    return nodes.some(node => node.enabled);
}

function updateRemoveButtonState() {
    const removeButton = document.querySelector('.remove-button') as HTMLButtonElement;
    if (removeButton) {
        removeButton.disabled = !hasSelectedRootPaths(currentPaths);
    }
}

function updateGenerateButtonState() {
    const generateButton = document.querySelector('.generate-button') as HTMLButtonElement;
    if (generateButton) {
        generateButton.disabled = getSelectedPaths(currentPaths).length === 0;
    }
}

function removeSelectedPaths() {
    currentPaths = currentPaths.filter(node => !node.enabled);
    window.electron.updatePaths(currentPaths);
    render(currentPaths);
    updateRemoveButtonState();
    updateGenerateButtonState();
}

function escapeHtml(unsafe: string): string {
    return unsafe
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function estimateTokenCount(text: string): number {
    // Split by whitespace and count words
    const words = text.trim().split(/\s+/);
    let count = words.length;
    
    // Add extra tokens for special characters and punctuation
    const specialChars = text.match(/[.,!?;:()[\]{}"'`]/g) || [];
    count += specialChars.length;
    
    // Add tokens for XML tags
    const xmlTags = text.match(/<[^>]+>/g) || [];
    count += xmlTags.length;
    
    return count;
}

async function generateReport() {
    const generateButton = document.querySelector('.generate-button') as HTMLButtonElement;
    const textContainer = document.getElementById('text-container');
    const copyButton = document.getElementById('copy-button');
    if (!generateButton || !textContainer || !copyButton) return;

    generateButton.disabled = true;
    textContainer.innerHTML = '<em>Generating report...</em>';
    copyButton.style.display = 'none';

    try {
        const selectedPaths = getSelectedPaths(currentPaths);
        const report = await window.electron.generateReport(selectedPaths);
        textContainer.innerHTML = `<pre>${escapeHtml(report)}</pre>`;
        copyButton.style.display = 'flex';
        
        // Update token count
        const tokenCount = estimateTokenCount(report);
        copyButton.innerHTML = `<span class="copy-icon">📋</span> Copy to Clipboard (${tokenCount.toLocaleString()} tokens)`;
    } catch (error) {
        textContainer.innerHTML = `<strong>Error generating report:</strong><pre>${error}</pre>`;
        copyButton.style.display = 'none';
    } finally {
        updateGenerateButtonState();
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    const addButton = document.querySelector('.add-button');
    const removeButton = document.querySelector('.remove-button');
    const generateButton = document.querySelector('.generate-button');
    const copyButton = document.getElementById('copy-button');
    const textContainer = document.getElementById('text-container');
    
    if (textContainer) {
        textContainer.innerHTML = '<em>Select files and click "Generate" to create a report.</em>';
    }
    
    addButton?.addEventListener('click', () => window.electron.openFilePicker());
    removeButton?.addEventListener('click', removeSelectedPaths);
    generateButton?.addEventListener('click', generateReport);
    copyButton?.addEventListener('click', () => {
        const pre = textContainer?.querySelector('pre');
        if (pre) {
            const text = pre.textContent || '';
            navigator.clipboard.writeText(text)
                .then(() => {
                    const tokenCount = estimateTokenCount(text);
                    copyButton.innerHTML = `<span class="copy-icon">✓</span> Copied! (${tokenCount.toLocaleString()} tokens)`;
                    setTimeout(() => {
                        copyButton.innerHTML = `<span class="copy-icon">📋</span> Copy to Clipboard (${tokenCount.toLocaleString()} tokens)`;
                    }, 2000);
                })
                .catch(err => {
                    console.error('Failed to copy text: ', err);
                });
        }
    });

    window.electron.onPathsUpdated(newPaths => {
        currentPaths = newPaths;
        render(currentPaths);
        updateRemoveButtonState();
        updateGenerateButtonState();
    });

    const initialPaths = await window.electron.loadInitialPaths();
    currentPaths = initialPaths;
    render(currentPaths);
    updateRemoveButtonState();
    updateGenerateButtonState();

    const sidebar = document.querySelector('.sidebar') as HTMLElement;
    const resizeHandle = document.querySelector('.resize-handle') as HTMLElement;

    const onMouseMove = (e: MouseEvent) => {
        const minWidth = 250;
        const maxWidth = window.innerWidth / 3;
        let newWidth = e.clientX;

        if (newWidth < minWidth) newWidth = minWidth;
        if (newWidth > maxWidth) newWidth = maxWidth;

        sidebar.style.width = `${newWidth}px`;
    };

    const onMouseUp = () => {
        window.removeEventListener('mousemove', onMouseMove);
        window.removeEventListener('mouseup', onMouseUp);
    };

    resizeHandle.addEventListener('mousedown', (e) => {
        e.preventDefault();
        window.addEventListener('mousemove', onMouseMove);
        window.addEventListener('mouseup', onMouseUp);
    });
}); 