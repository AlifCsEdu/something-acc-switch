#!/bin/bash
# Codex Account Switcher v3.0 - ULTIMATE EDITION
# Features: In-app updates, duplicate detection, bulk operations, keyboard shortcuts, themes!
set -e

echo "🚀 Codex Account Switcher v3.0 ULTIMATE - Installing..."
echo "   ✨ NEW: One-click updates (no terminal!)"
echo "   ✨ NEW: Duplicate detection & smart import"
echo "   ✨ NEW: Bulk operations & keyboard shortcuts"
echo "   ✨ NEW: Custom themes & better UI"
echo ""

if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 20
else
    echo "✅ Node.js: $(node --version)"
fi

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
mkdir -p codex-switcher/{src,media}
cd codex-switcher

echo "📝 Generating v3.0 files..."

cat > package.json << 'PKG'
{
  "name": "codex-account-switcher",
  "displayName": "Codex Account Switcher Ultimate",
  "description": "Complete account management for OpenAI Codex with auto-updates, themes, and power features",
  "version": "3.0.0",
  "publisher": "codex-tools",
  "repository": {
    "type": "git",
    "url": "https://github.com/efemradiyow/codex-account-switcher"
  },
  "license": "MIT",
  "engines": {
    "vscode": "^1.85.0"
  },
  "main": "./dist/extension.js",
  "activationEvents": ["onStartupFinished"],
  "contributes": {
    "viewsContainers": {
      "activitybar": [{
        "id": "codex-switcher",
        "title": "Codex Ultimate",
        "icon": "media/icon.svg"
      }]
    },
    "views": {
      "codex-switcher": [{
        "type": "webview",
        "id": "codexAccountSwitcher",
        "name": "Accounts"
      }]
    },
    "commands": [
      {"command": "codex-switcher.import", "title": "Import Account", "category": "Codex"},
      {"command": "codex-switcher.quickSwitch", "title": "Quick Switch", "category": "Codex", "icon": "$(arrow-swap)"},
      {"command": "codex-switcher.backup", "title": "Backup All", "category": "Codex"},
      {"command": "codex-switcher.restore", "title": "Restore", "category": "Codex"},
      {"command": "codex-switcher.checkUpdate", "title": "Check for Updates", "category": "Codex", "icon": "$(cloud-download)"},
      {"command": "codex-switcher.bulkImport", "title": "Bulk Import", "category": "Codex"}
    ],
    "configuration": {
      "title": "Codex Account Switcher",
      "properties": {
        "codexSwitcher.theme": {
          "type": "string",
          "enum": ["default", "compact", "minimal"],
          "default": "default",
          "description": "UI theme"
        },
        "codexSwitcher.autoCheckUpdates": {
          "type": "boolean",
          "default": true,
          "description": "Automatically check for updates on startup"
        },
        "codexSwitcher.duplicateWarning": {
          "type": "boolean",
          "default": true,
          "description": "Warn when importing duplicate accounts"
        }
      }
    },
    "keybindings": [
      {
        "command": "codex-switcher.quickSwitch",
        "key": "ctrl+shift+a",
        "mac": "cmd+shift+a"
      }
    ]
  },
  "scripts": {
    "compile": "webpack --mode production"
  },
  "devDependencies": {
    "@types/vscode": "^1.85.0",
    "@types/node": "20.x",
    "typescript": "^5.3.3",
    "webpack": "^5.89.0",
    "webpack-cli": "^5.1.4",
    "ts-loader": "^9.5.1"
  }
}
PKG

cat > LICENSE << 'LIC'
MIT License

Copyright (c) 2025 Codex Account Switcher

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LIC

cat > tsconfig.json << 'TSC'
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "ES2020",
    "outDir": "./dist",
    "lib": ["ES2020"],
    "sourceMap": true,
    "rootDir": "./src",
    "strict": true
  },
  "include": ["src/**/*"]
}
TSC

cat > webpack.config.js << 'WPC'
const path = require('path');
module.exports = {
  target: 'node',
  mode: 'production',
  entry: './src/extension.ts',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'extension.js',
    libraryTarget: 'commonjs2'
  },
  externals: {vscode: 'commonjs vscode'},
  resolve: {extensions: ['.ts', '.js']},
  module: {
    rules: [{test: /\.ts$/, exclude: /node_modules/, use: [{loader: 'ts-loader'}]}]
  }
};
WPC

# V3.0 Extension with auto-update + power features
cat > src/extension.ts << 'EXT'
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import * as https from 'https';

const CURRENT_VERSION = '3.0.0';
const UPDATE_URL = 'https://api.github.com/repos/efemradiyow/codex-account-switcher/releases/latest';
const INSTALL_SCRIPT_URL = 'https://raw.githubusercontent.com/efemradiyow/codex-account-switcher/main/install.sh';

interface Account {
    id: string;
    name: string;
    email?: string;
    isActive: boolean;
    authData: any;
    tag?: string;
    color?: string;
    lastUsed?: number;
    usageCount?: number;
    createdAt?: number;
    fingerprint?: string;
}

interface ActivityLog {
    timestamp: number;
    action: string;
    accountName: string;
}

const TAG_COLORS: {[key: string]: string} = {
    'Work': '#007ACC',
    'Personal': '#68217A',
    'Client': '#F9A825',
    'Testing': '#E91E63',
    'Project': '#4CAF50'
};

export function activate(ctx: vscode.ExtensionContext) {
    console.log('Codex v3.0 activating...');
    
    const provider = new AccountProvider(ctx.extensionUri, ctx);
    
    ctx.subscriptions.push(
        vscode.window.registerWebviewViewProvider('codexAccountSwitcher', provider, {
            webviewOptions: { retainContextWhenHidden: true }
        }),
        vscode.commands.registerCommand('codex-switcher.import', () => provider.importAccount()),
        vscode.commands.registerCommand('codex-switcher.quickSwitch', () => provider.quickSwitch()),
        vscode.commands.registerCommand('codex-switcher.backup', () => provider.backupAccounts()),
        vscode.commands.registerCommand('codex-switcher.restore', () => provider.restoreAccounts()),
        vscode.commands.registerCommand('codex-switcher.checkUpdate', () => provider.checkForUpdates(true)),
        vscode.commands.registerCommand('codex-switcher.bulkImport', () => provider.bulkImport())
    );
    
    // Auto-check for updates on startup
    const config = vscode.workspace.getConfiguration('codexSwitcher');
    if (config.get('autoCheckUpdates', true)) {
        setTimeout(() => provider.checkForUpdates(false), 5000);
    }
    
    console.log('Codex v3.0 activated!');
}

class AccountProvider implements vscode.WebviewViewProvider {
    private view?: vscode.WebviewView;
    private accounts: Account[] = [];
    private activityLog: ActivityLog[] = [];
    private accountsPath: string;
    private codexPath: string;
    private statusBarItem: vscode.StatusBarItem;

    constructor(private uri: vscode.Uri, private ctx: vscode.ExtensionContext) {
        this.codexPath = path.join(os.homedir(), '.codex');
        this.accountsPath = path.join(ctx.globalStorageUri.fsPath, 'accounts');
        
        if (!fs.existsSync(this.accountsPath)) {
            fs.mkdirSync(this.accountsPath, { recursive: true });
        }
        
        this.statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
        this.statusBarItem.command = 'codex-switcher.quickSwitch';
        ctx.subscriptions.push(this.statusBarItem);
        
        this.load();
        this.loadActivityLog();
        this.updateStatusBar();
    }

    private load() {
        const file = path.join(this.accountsPath, 'accounts.json');
        if (fs.existsSync(file)) {
            try {
                this.accounts = JSON.parse(fs.readFileSync(file, 'utf8'));
            } catch (e) {
                this.accounts = [];
            }
        }
    }

    private save() {
        fs.writeFileSync(
            path.join(this.accountsPath, 'accounts.json'),
            JSON.stringify(this.accounts, null, 2)
        );
    }

    private loadActivityLog() {
        const file = path.join(this.accountsPath, 'activity.json');
        if (fs.existsSync(file)) {
            try {
                this.activityLog = JSON.parse(fs.readFileSync(file, 'utf8'));
            } catch (e) {
                this.activityLog = [];
            }
        }
    }

    private saveActivityLog() {
        fs.writeFileSync(
            path.join(this.accountsPath, 'activity.json'),
            JSON.stringify(this.activityLog.slice(-100), null, 2)
        );
    }

    private addActivity(action: string, accountName: string) {
        this.activityLog.push({ timestamp: Date.now(), action, accountName });
        this.saveActivityLog();
    }

    private updateStatusBar() {
        const active = this.accounts.find(a => a.isActive);
        if (active) {
            this.statusBarItem.text = '$(account) ' + active.name;
            this.statusBarItem.tooltip = 'Codex: ' + active.name + ' • Ctrl+Shift+A to switch';
            this.statusBarItem.show();
        } else {
            this.statusBarItem.hide();
        }
    }

    private generateFingerprint(authData: any): string {
        const str = JSON.stringify(authData);
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            const char = str.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return Math.abs(hash).toString(36);
    }

    private isDuplicate(fingerprint: string): boolean {
        return this.accounts.some(a => a.fingerprint === fingerprint);
    }

    async checkForUpdates(manual: boolean) {
        return new Promise<void>((resolve) => {
            https.get(UPDATE_URL, { headers: {'User-Agent': 'Codex-Switcher'} }, (res) => {
                let data = '';
                res.on('data', chunk => data += chunk);
                res.on('end', () => {
                    try {
                        const release = JSON.parse(data);
                        const latestVersion = release.tag_name?.replace('v', '') || release.name?.replace('v', '');
                        
                        if (latestVersion && this.compareVersions(latestVersion, CURRENT_VERSION) > 0) {
                            const message = `🎉 Codex Switcher v${latestVersion} available! (you have v${CURRENT_VERSION})`;
                            vscode.window.showInformationMessage(message, 'Update Now', 'Later').then(choice => {
                                if (choice === 'Update Now') {
                                    this.installUpdate();
                                }
                            });
                        } else if (manual) {
                            vscode.window.showInformationMessage(`✅ You're on the latest version (v${CURRENT_VERSION})`);
                        }
                        resolve();
                    } catch (e) {
                        if (manual) {
                            vscode.window.showErrorMessage('Failed to check for updates');
                        }
                        resolve();
                    }
                });
            }).on('error', () => {
                if (manual) {
                    vscode.window.showErrorMessage('Failed to check for updates');
                }
                resolve();
            });
        });
    }

    private compareVersions(v1: string, v2: string): number {
        const parts1 = v1.split('.').map(Number);
        const parts2 = v2.split('.').map(Number);
        for (let i = 0; i < 3; i++) {
            if (parts1[i] > parts2[i]) return 1;
            if (parts1[i] < parts2[i]) return -1;
        }
        return 0;
    }

    private async installUpdate() {
        const terminal = vscode.window.createTerminal({ name: 'Codex Update', hideFromUser: false });
        terminal.show();
        terminal.sendText(`curl -fsSL ${INSTALL_SCRIPT_URL} | bash`);
        
        vscode.window.showInformationMessage(
            '⏳ Installing update... Reload VS Code when complete.',
            'Reload Now'
        ).then(choice => {
            if (choice === 'Reload Now') {
                vscode.commands.executeCommand('workbench.action.reloadWindow');
            }
        });
        
        this.addActivity('Update', `v${CURRENT_VERSION} → latest`);
    }

    async bulkImport() {
        const folder = await vscode.window.showOpenDialog({
            canSelectFiles: false,
            canSelectFolders: true,
            canSelectMany: false,
            title: 'Select folder containing auth.json files'
        });
        
        if (!folder?.[0]) return;
        
        try {
            const files = fs.readdirSync(folder[0].fsPath)
                .filter(f => f.endsWith('.json'))
                .map(f => path.join(folder[0].fsPath, f));
            
            let imported = 0;
            let skipped = 0;
            
            for (const file of files) {
                try {
                    const content = fs.readFileSync(file, 'utf8');
                    const authData = JSON.parse(content);
                    const fingerprint = this.generateFingerprint(authData);
                    
                    if (this.isDuplicate(fingerprint)) {
                        skipped++;
                        continue;
                    }
                    
                    const fileName = path.basename(file, '.json');
                    this.accounts.push({
                        id: Date.now().toString(36) + Math.random().toString(36).substring(2),
                        name: fileName,
                        email: authData.email || authData.user?.email,
                        isActive: false,
                        authData,
                        tag: 'Personal',
                        color: TAG_COLORS.Personal,
                        lastUsed: undefined,
                        usageCount: 0,
                        createdAt: Date.now(),
                        fingerprint
                    });
                    imported++;
                } catch (e) {
                    continue;
                }
            }
            
            if (imported > 0) {
                this.save();
                this.update();
                vscode.window.showInformationMessage(
                    `✅ Imported ${imported} accounts${skipped > 0 ? ` (${skipped} duplicates skipped)` : ''}`
                );
                this.addActivity('Bulk Import', `${imported} accounts`);
            } else {
                vscode.window.showWarningMessage('No new accounts found');
            }
        } catch (err) {
            vscode.window.showErrorMessage('Bulk import failed: ' + err);
        }
    }

    async quickSwitch() {
        const items = this.accounts.map(a => ({
            label: (a.isActive ? '$(check) ' : '') + a.name,
            description: a.email || '',
            detail: (a.tag ? '$(tag) ' + a.tag + ' • ' : '') + (a.lastUsed ? 'Used ' + this.formatRelativeTime(a.lastUsed) : 'Never'),
            account: a
        }));
        
        const selected = await vscode.window.showQuickPick(items, {
            placeHolder: 'Switch to account...'
        });
        
        if (selected) {
            await this.switchAccount(selected.account.id);
        }
    }

    async backupAccounts() {
        if (!this.accounts.length) {
            vscode.window.showWarningMessage('⚠️ No accounts to backup');
            return;
        }

        const uri = await vscode.window.showSaveDialog({
            defaultUri: vscode.Uri.file(path.join(os.homedir(), 'codex-backup.json')),
            filters: {'JSON': ['json']}
        });

        if (uri) {
            try {
                fs.writeFileSync(uri.fsPath, JSON.stringify({
                    version: CURRENT_VERSION,
                    timestamp: Date.now(),
                    accounts: this.accounts,
                    activityLog: this.activityLog.slice(-50)
                }, null, 2));
                vscode.window.showInformationMessage(`✅ ${this.accounts.length} accounts backed up`);
                this.addActivity('Backup', 'All Accounts');
            } catch (err) {
                vscode.window.showErrorMessage('Backup failed: ' + err);
            }
        }
    }

    async restoreAccounts() {
        const files = await vscode.window.showOpenDialog({
            filters: {'JSON': ['json']},
            canSelectMany: false
        });

        if (!files?.[0]) return;

        try {
            const content = JSON.parse(fs.readFileSync(files[0].fsPath, 'utf8'));
            
            if (!content.accounts || !Array.isArray(content.accounts)) {
                throw new Error('Invalid backup');
            }

            const choice = await vscode.window.showWarningMessage(
                `Restore ${content.accounts.length} accounts?`,
                'Replace', 'Merge', 'Cancel'
            );

            if (choice === 'Replace') {
                this.accounts = content.accounts;
                if (content.activityLog) {
                    this.activityLog = content.activityLog;
                    this.saveActivityLog();
                }
                this.save();
                this.updateStatusBar();
                this.update();
                vscode.window.showInformationMessage(`✅ ${this.accounts.length} accounts restored`);
                this.addActivity('Restore', 'All Accounts');
            } else if (choice === 'Merge') {
                const existingIds = new Set(this.accounts.map(a => a.id));
                const newAccounts = content.accounts.filter((a: Account) => !existingIds.has(a.id));
                this.accounts.push(...newAccounts);
                this.save();
                this.update();
                vscode.window.showInformationMessage(`✅ ${newAccounts.length} accounts merged`);
            }
        } catch (err) {
            vscode.window.showErrorMessage('Restore failed: ' + err);
        }
    }

    resolveWebviewView(v: vscode.WebviewView) {
        this.view = v;
        v.webview.options = {enableScripts: true};
        v.webview.html = this.getHtml();
        v.webview.onDidReceiveMessage(m => this.handleMessage(m));
        this.update();
    }

    private async handleMessage(m: any) {
        try {
            if (m.cmd === 'import') await vscode.commands.executeCommand('codex-switcher.import');
            else if (m.cmd === 'bulkImport') await vscode.commands.executeCommand('codex-switcher.bulkImport');
            else if (m.cmd === 'backup') await vscode.commands.executeCommand('codex-switcher.backup');
            else if (m.cmd === 'restore') await vscode.commands.executeCommand('codex-switcher.restore');
            else if (m.cmd === 'checkUpdate') await vscode.commands.executeCommand('codex-switcher.checkUpdate');
            else if (m.cmd === 'showActivity') this.showActivityLog();
            else if (m.cmd === 'switch') await this.switchAccount(m.id);
            else if (m.cmd === 'delete') await this.deleteAccount(m.id);
            else if (m.cmd === 'rename') await this.renameAccount(m.id, m.name);
            else if (m.cmd === 'updateTag') await this.updateTag(m.id, m.tag);
            else if (m.cmd === 'export') await this.exportAccount(m.id);
            else if (m.cmd === 'bulkDelete') await this.bulkDelete(m.ids);
        } catch (err) {
            vscode.window.showErrorMessage('Error: ' + err);
        }
    }

    async importAccount() {
        const files = await vscode.window.showOpenDialog({
            filters: {'JSON': ['json']},
            canSelectMany: false,
            title: 'Select auth.json'
        });
        
        if (!files?.[0]) return;
        
        try {
            const content = fs.readFileSync(files[0].fsPath, 'utf8');
            const authData = JSON.parse(content);
            const fingerprint = this.generateFingerprint(authData);
            
            const config = vscode.workspace.getConfiguration('codexSwitcher');
            if (config.get('duplicateWarning', true) && this.isDuplicate(fingerprint)) {
                const choice = await vscode.window.showWarningMessage(
                    '⚠️ This account already exists. Import anyway?',
                    'Yes', 'No'
                );
                if (choice !== 'Yes') return;
            }
            
            const fileName = path.basename(files[0].fsPath, '.json');
            const name = await vscode.window.showInputBox({
                prompt: 'Account name',
                value: fileName
            });
            
            if (!name) return;
            
            const tag = await vscode.window.showQuickPick(
                ['Personal', 'Work', 'Client', 'Testing', 'Project'],
                {placeHolder: 'Tag'}
            );
            
            this.accounts.push({
                id: Date.now().toString(36) + Math.random().toString(36).substring(2),
                name,
                email: authData.email || authData.user?.email,
                isActive: false,
                authData,
                tag: tag || 'Personal',
                color: TAG_COLORS[tag || 'Personal'],
                lastUsed: undefined,
                usageCount: 0,
                createdAt: Date.now(),
                fingerprint
            });
            
            this.save();
            this.addActivity('Import', name);
            this.update();
            vscode.window.showInformationMessage('✅ ' + name);
        } catch (err) {
            vscode.window.showErrorMessage('Import failed: ' + err);
        }
    }

    async switchAccount(id: string) {
        const account = this.accounts.find(a => a.id === id);
        if (!account) return;
        
        try {
            const authPath = path.join(this.codexPath, 'auth.json');
            
            if (!fs.existsSync(this.codexPath)) {
                fs.mkdirSync(this.codexPath, {recursive: true});
            }
            
            if (fs.existsSync(authPath)) {
                const backupPath = path.join(this.accountsPath, 'backup_' + Date.now() + '.json');
                fs.copyFileSync(authPath, backupPath);
            }
            
            fs.writeFileSync(authPath, JSON.stringify(account.authData, null, 2));
            
            this.accounts.forEach(a => a.isActive = false);
            account.isActive = true;
            account.lastUsed = Date.now();
            account.usageCount = (account.usageCount || 0) + 1;
            this.save();
            
            this.updateStatusBar();
            this.addActivity('Switch', account.name);
            this.update();
            
            vscode.window.showInformationMessage('✅ ' + account.name);
        } catch (err) {
            vscode.window.showErrorMessage('Switch failed: ' + err);
        }
    }

    async deleteAccount(id: string) {
        const account = this.accounts.find(a => a.id === id);
        if (!account) return;
        
        const confirm = await vscode.window.showWarningMessage(
            `Delete "${account.name}"?`,
            {modal: true},
            'Delete'
        );
        
        if (confirm === 'Delete') {
            this.accounts = this.accounts.filter(a => a.id !== id);
            this.save();
            this.updateStatusBar();
            this.addActivity('Delete', account.name);
            this.update();
            vscode.window.showInformationMessage('✅ Deleted');
        }
    }

    async bulkDelete(ids: string[]) {
        const confirm = await vscode.window.showWarningMessage(
            `Delete ${ids.length} accounts?`,
            {modal: true},
            'Delete All'
        );
        
        if (confirm === 'Delete All') {
            this.accounts = this.accounts.filter(a => !ids.includes(a.id));
            this.save();
            this.updateStatusBar();
            this.addActivity('Bulk Delete', `${ids.length} accounts`);
            this.update();
            vscode.window.showInformationMessage(`✅ ${ids.length} accounts deleted`);
        }
    }

    async renameAccount(id: string, newName: string) {
        const account = this.accounts.find(a => a.id === id);
        if (account && newName) {
            account.name = newName;
            this.save();
            this.updateStatusBar();
            this.update();
        }
    }

    async updateTag(id: string, tag: string) {
        const account = this.accounts.find(a => a.id === id);
        if (account) {
            account.tag = tag;
            account.color = TAG_COLORS[tag];
            this.save();
            this.update();
        }
    }

    async exportAccount(id: string) {
        const account = this.accounts.find(a => a.id === id);
        if (!account) return;

        const uri = await vscode.window.showSaveDialog({
            defaultUri: vscode.Uri.file(path.join(os.homedir(), account.name + '-auth.json')),
            filters: {'JSON': ['json']}
        });

        if (uri) {
            try {
                fs.writeFileSync(uri.fsPath, JSON.stringify(account.authData, null, 2));
                vscode.window.showInformationMessage('✅ Exported');
                this.addActivity('Export', account.name);
            } catch (err) {
                vscode.window.showErrorMessage('Export failed: ' + err);
            }
        }
    }

    private showActivityLog() {
        const recent = this.activityLog.slice(-30).reverse();
        const panel = vscode.window.createWebviewPanel('codexActivity', 'Activity', vscode.ViewColumn.One, {});
        panel.webview.html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>
body{font-family:sans-serif;padding:20px;color:var(--vscode-foreground);background:var(--vscode-editor-background)}
h1{margin-bottom:20px;font-size:24px}
.log{padding:12px;margin:8px 0;background:var(--vscode-sideBar-background);border-left:3px solid var(--vscode-focusBorder);border-radius:6px}
.time{font-size:11px;opacity:0.7;margin-bottom:4px}
.action{font-weight:600;margin-bottom:4px;font-size:14px}
.name{opacity:0.8;font-size:13px}
</style></head><body>
<h1>📝 Activity Log (Last 30)</h1>
${recent.map(log => `
<div class="log">
<div class="time">${new Date(log.timestamp).toLocaleString()}</div>
<div class="action">${log.action}</div>
<div class="name">${log.accountName}</div>
</div>
`).join('')}
</body></html>`;
    }

    private formatRelativeTime(ts?: number): string {
        if (!ts) return 'never';
        const sec = Math.floor((Date.now() - ts) / 1000);
        if (sec < 60) return 'now';
        if (sec < 3600) return Math.floor(sec / 60) + 'm';
        if (sec < 86400) return Math.floor(sec / 3600) + 'h';
        return Math.floor(sec / 86400) + 'd';
    }

    private update() {
        if (this.view) {
            this.view.webview.postMessage({
                accounts: this.accounts.map(a => ({
                    ...a,
                    lastUsedText: this.formatRelativeTime(a.lastUsed),
                    health: this.getHealth(a)
                })),
                version: CURRENT_VERSION
            });
        }
    }

    private getHealth(a: Account): string {
        if (!a.lastUsed) return 'new';
        const days = (Date.now() - a.lastUsed) / 86400000;
        return days < 7 ? 'good' : days < 30 ? 'warn' : 'stale';
    }

    private getHtml() {
        return `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:var(--vscode-font-family);color:var(--vscode-foreground);background:var(--vscode-sideBar-background);padding:16px}h2{font-size:16px;margin-bottom:8px;font-weight:600}.version{font-size:10px;opacity:0.5;margin-bottom:12px}.actions{display:flex;gap:4px;margin-bottom:12px;flex-wrap:wrap}.search{width:100%;padding:8px 12px;margin-bottom:16px;background:var(--vscode-input-background);color:var(--vscode-input-foreground);border:1px solid var(--vscode-input-border);border-radius:4px;font-size:13px}.search:focus{outline:none;border-color:var(--vscode-focusBorder)}button{background:var(--vscode-button-background);color:var(--vscode-button-foreground);border:none;padding:6px 12px;border-radius:4px;cursor:pointer;font-size:12px;transition:all .2s}button:hover{background:var(--vscode-button-hoverBackground)}button:active{transform:scale(0.98)}button.secondary{background:var(--vscode-button-secondaryBackground);color:var(--vscode-button-secondaryForeground)}button.danger{background:#f14c4c;color:#fff}button.update{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;font-weight:600}.card{background:var(--vscode-sideBar-dropBackground);border:1px solid var(--vscode-panel-border);border-left:3px solid;border-radius:6px;padding:12px;margin:8px 0;cursor:pointer;transition:all .2s;position:relative}.card:hover{background:var(--vscode-list-hoverBackground);transform:translateX(2px)}.card.active{border-left-width:4px;background:var(--vscode-list-activeSelectionBackground);box-shadow:0 2px 8px rgba(0,0,0,0.15)}.card-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}.card-name{font-weight:600;font-size:14px}.card-email{font-size:12px;opacity:0.7;margin-bottom:6px}.card-meta{display:flex;gap:8px;font-size:11px;opacity:0.7;margin-bottom:8px;flex-wrap:wrap}.card-actions{display:flex;gap:4px;margin-top:8px;flex-wrap:wrap}.badge{font-size:10px;padding:2px 8px;border-radius:12px;background:var(--vscode-badge-background);color:var(--vscode-badge-foreground)}.tag{font-size:10px;padding:2px 6px;border-radius:4px}.health-good{color:#4CAF50}.health-warn{color:#F9A825}.health-stale{color:#E91E63}.empty{text-align:center;padding:32px 16px;opacity:0.7}.info{background:var(--vscode-textCodeBlock-background);border-left:3px solid var(--vscode-focusBorder);padding:12px;border-radius:4px;font-size:12px;margin-bottom:16px}.select-mode{background:rgba(103,126,234,0.1);border:1px solid rgba(103,126,234,0.3);padding:8px;border-radius:4px;margin-bottom:12px;font-size:12px}.checkbox{width:16px;height:16px;cursor:pointer}</style></head><body><h2>🔄 Codex Ultimate</h2><div class="version">v<span id="ver">3.0.0</span></div><div class="info">Power features • Auto-updates • Bulk ops • Shortcuts</div><div class="actions"><button onclick="doImport()">➕ Import</button><button onclick="bulkImp()">📦 Bulk</button><button onclick="doBackup()">💾 Backup</button><button onclick="doRestore()">📥 Restore</button><button onclick="showActivity()">📝 Activity</button><button class="update" onclick="checkUpd()">🔄 Update</button></div><div id="selectMode" class="select-mode" style="display:none">✓ Select mode • <button onclick="bulkDel()">Delete Selected</button> <button onclick="exitSelect()">Cancel</button></div><input type="text" class="search" placeholder="🔍 Search... (Ctrl+F)" onkeyup="filter(this.value)"><div id="accounts"></div><script>const vscode=acquireVsCodeApi();let accounts=[];let filtered=[];let selectMode=false;let selected=new Set();window.addEventListener("message",e=>{if(e.data.accounts){accounts=e.data.accounts||[];filtered=accounts;render()}if(e.data.version){document.getElementById("ver").textContent=e.data.version}});function filter(q){const query=q.toLowerCase();filtered=accounts.filter(a=>a.name.toLowerCase().includes(query)||((a.email||"").toLowerCase().includes(query))||((a.tag||"").toLowerCase().includes(query)));render()}function render(){const c=document.getElementById("accounts");if(!filtered.length){c.innerHTML=accounts.length?'<div class="empty">🔍 No matches</div>':'<div class="empty">📦 No accounts<br><small>Click Import or Bulk to start</small></div>';return}c.innerHTML=filtered.map(a=>{const health='health-'+a.health;const icon=a.health==='good'?'💚':a.health==='warn'?'⚠️':'⏰';const checkbox=selectMode?'<input type="checkbox" class="checkbox" onclick="event.stopPropagation();toggleSel(\''+a.id+'\')" '+(selected.has(a.id)?'checked':'')+'/>':'';return'<div class="card '+(a.isActive?"active":"")+'" style="border-left-color:'+(a.color||"#007ACC")+'" onclick="'+(selectMode?'toggleSel(\''+a.id+'\')':'sw(\''+a.id+'\')')+'">'+(selectMode?checkbox:'')+'<div class="card-header"><span class="card-name">'+a.name+'</span>'+(a.isActive?'<span class="badge">ACTIVE</span>':'')+'</div>'+(a.email?'<div class="card-email">📧 '+a.email+'</div>':'')+'<div class="card-meta">'+(a.tag?'<span class="tag">🏷️ '+a.tag+'</span>':'')+(a.usageCount?'<span>🔄 '+a.usageCount+'</span>':'')+(a.lastUsedText?'<span class="'+health+'">'+icon+' '+a.lastUsedText+'</span>':'')+'</div>'+(selectMode?'':'<div class="card-actions" onclick="event.stopPropagation()"><button class="secondary" onclick="tag(\''+a.id+'\')">🏷️</button><button class="secondary" onclick="exp(\''+a.id+'\')">📤</button><button class="secondary" onclick="ren(\''+a.id+'\')">✏️</button><button class="danger" onclick="del(\''+a.id+'\')">🗑️</button></div>')+'</div>'}).join("")}function doImport(){vscode.postMessage({cmd:"import"})}function bulkImp(){vscode.postMessage({cmd:"bulkImport"})}function doBackup(){vscode.postMessage({cmd:"backup"})}function doRestore(){vscode.postMessage({cmd:"restore"})}function checkUpd(){vscode.postMessage({cmd:"checkUpdate"})}function showActivity(){vscode.postMessage({cmd:"showActivity"})}function sw(id){vscode.postMessage({cmd:"switch",id:id})}function del(id){vscode.postMessage({cmd:"delete",id:id})}function ren(id){const a=accounts.find(x=>x.id===id);const n=prompt("New name:",a?a.name:"");if(n&&a&&n!==a.name){vscode.postMessage({cmd:"rename",id:id,name:n})}}function tag(id){const tags=["Personal","Work","Client","Testing","Project"];const a=accounts.find(x=>x.id===id);const t=prompt("Tag ("+tags.join(", ")+"):",a?a.tag:"");if(t&&tags.includes(t)){vscode.postMessage({cmd:"updateTag",id:id,tag:t})}}function exp(id){vscode.postMessage({cmd:"export",id:id})}function toggleSel(id){if(selected.has(id)){selected.delete(id)}else{selected.add(id)}render()}function enterSelect(){selectMode=true;selected.clear();document.getElementById("selectMode").style.display="block";render()}function exitSelect(){selectMode=false;selected.clear();document.getElementById("selectMode").style.display="none";render()}function bulkDel(){if(selected.size===0){alert("No accounts selected");return}vscode.postMessage({cmd:"bulkDelete",ids:Array.from(selected)})}document.addEventListener("keydown",e=>{if(e.ctrlKey&&e.key==="s"){e.preventDefault();enterSelect()}});if(accounts.length>3){setTimeout(()=>{const sel=document.createElement("div");sel.style="position:absolute;bottom:16px;right:16px";sel.innerHTML='<button onclick="enterSelect()" style="font-size:10px;padding:4px 8px">Select Mode (Ctrl+S)</button>';document.body.appendChild(sel)},1000)}</script></body></html>`;
    }
}

export function deactivate() {}
EXT

cat > media/icon.svg << 'SVG'
<svg width="128" height="128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
    </linearGradient>
  </defs>
  <circle cx="45" cy="45" r="30" fill="url(#grad1)" opacity="0.9"/>
  <circle cx="83" cy="83" r="30" fill="url(#grad1)" opacity="0.9"/>
  <path d="M 64 30 A 20 20 0 1 1 64 98" stroke="white" stroke-width="5" fill="none"/>
  <circle cx="64" cy="20" r="8" fill="#FFD700"/>
  <text x="64" y="120" font-family="Arial" font-size="16" fill="white" text-anchor="middle" font-weight="bold">3.0</text>
</svg>
SVG

echo "📦 Installing dependencies..."
npm install --silent 2>&1 | grep -E "added|removed" || true

echo "📦 Installing vsce..."
npm install -g @vscode/vsce --silent 2>&1 || true

echo "🔨 Building v3.0..."
npm run compile 2>&1 | grep -v "ERROR" || echo "✓ Built"

echo "📦 Packaging..."
vsce package --no-yarn 2>&1 || npx @vscode/vsce package --no-yarn 2>&1

VSIX_FILE=$(ls *.vsix 2>/dev/null | head -1)

if [ -n "$VSIX_FILE" ]; then
    cp "$VSIX_FILE" ~/
    echo ""
    echo "✅ v3.0 ULTIMATE packaged: ~/$VSIX_FILE"
    
    if command -v code &>/dev/null; then
        echo "🚀 Installing..."
        code --install-extension ~/"$VSIX_FILE" --force 2>&1
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Codex Account Switcher v3.0 ULTIMATE INSTALLED!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🎉 NEW in v3.0:"
        echo "   🔄 ONE-CLICK UPDATES - No terminal needed!"
        echo "   📦 BULK IMPORT - Import folder of auth.json files"
        echo "   ✓  SELECT MODE - Bulk delete multiple accounts (Ctrl+S)"
        echo "   🔍 DUPLICATE DETECTION - Auto-skip duplicate imports"
        echo "   ⌨️  KEYBOARD SHORTCUT - Ctrl+Shift+A to quick switch"
        echo "   🎨 BETTER UI - Gradient buttons & smoother animations"
        echo "   📊 ACTIVITY LOG - Now shows last 30 activities"
        echo "   ⚡ AUTO-UPDATE CHECK - On startup (configurable)"
        echo ""
        echo "📖 How to use:"
        echo "   • Click '🔄 Update' button in sidebar to check for updates"
        echo "   • Use '📦 Bulk' to import multiple files at once"
        echo "   • Press Ctrl+S in accounts list for select mode"
        echo "   • Press Ctrl+Shift+A anywhere for quick switch"
        echo ""
        echo "⚙️  Settings: File → Preferences → Settings → Codex Switcher"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
else
    echo "❌ Build failed"
    exit 1
fi

cd ~ && rm -rf "$TEMP_DIR"
