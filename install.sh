#!/bin/bash
# Codex Account Switcher v2.0 - One-Command Installer
# New Features: Status bar, tags, search, timestamps, quick commands!
set -e

echo "🚀 Codex Account Switcher v2.0 - Installing..."
echo "   ✨ New: Status bar • Tags • Search • Timestamps"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js via nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 20
else
    echo "✅ Node.js found: $(node --version)"
fi

# Work in temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
mkdir -p codex-switcher/{src,media}
cd codex-switcher

echo "📝 Generating extension files..."

# Enhanced Package.json with new commands
cat > package.json << 'PKG'
{
  "name": "codex-account-switcher",
  "displayName": "Codex Account Switcher",
  "description": "Manage and switch between multiple ChatGPT Plus accounts for OpenAI Codex with tags, search, and quick commands",
  "version": "2.0.0",
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
  "activationEvents": [],
  "contributes": {
    "viewsContainers": {
      "activitybar": [
        {
          "id": "codex-switcher",
          "title": "Codex Switcher",
          "icon": "media/icon.svg"
        }
      ]
    },
    "views": {
      "codex-switcher": [
        {
          "type": "webview",
          "id": "codexAccountSwitcher",
          "name": "Accounts"
        }
      ]
    },
    "commands": [
      {
        "command": "codex-switcher.import",
        "title": "Import Account",
        "category": "Codex"
      },
      {
        "command": "codex-switcher.quickSwitch",
        "title": "Quick Switch Account",
        "category": "Codex"
      },
      {
        "command": "codex-switcher.showInStatusBar",
        "title": "Show Active Account in Status Bar",
        "category": "Codex"
      }
    ],
    "configuration": {
      "title": "Codex Account Switcher",
      "properties": {
        "codexSwitcher.showStatusBar": {
          "type": "boolean",
          "default": true,
          "description": "Show active account in status bar"
        },
        "codexSwitcher.defaultTag": {
          "type": "string",
          "default": "Personal",
          "description": "Default tag for new accounts"
        }
      }
    }
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

# Create LICENSE
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

# TypeScript config
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

# Webpack config
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
  externals: {
    vscode: 'commonjs vscode'
  },
  resolve: {
    extensions: ['.ts', '.js']
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        exclude: /node_modules/,
        use: [{
          loader: 'ts-loader'
        }]
      }
    ]
  }
};
WPC

# Enhanced Extension code with v2.0 features
cat > src/extension.ts << 'EXT'
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

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
}

const TAG_COLORS: {[key: string]: string} = {
    'Work': '#007ACC',
    'Personal': '#68217A',
    'Client': '#F9A825',
    'Testing': '#E91E63',
    'Project': '#4CAF50'
};

export function activate(ctx: vscode.ExtensionContext) {
    const provider = new AccountProvider(ctx.extensionUri, ctx);
    
    ctx.subscriptions.push(
        vscode.window.registerWebviewViewProvider('codexAccountSwitcher', provider)
    );
    
    ctx.subscriptions.push(
        vscode.commands.registerCommand('codex-switcher.import', () => provider.importAccount())
    );
    
    ctx.subscriptions.push(
        vscode.commands.registerCommand('codex-switcher.quickSwitch', () => provider.quickSwitch())
    );
    
    ctx.subscriptions.push(
        vscode.commands.registerCommand('codex-switcher.showInStatusBar', () => provider.toggleStatusBar())
    );
}

class AccountProvider implements vscode.WebviewViewProvider {
    private view?: vscode.WebviewView;
    private accounts: Account[] = [];
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
        this.updateStatusBar();
    }

    private load() {
        const file = path.join(this.accountsPath, 'accounts.json');
        if (fs.existsSync(file)) {
            this.accounts = JSON.parse(fs.readFileSync(file, 'utf8'));
        }
    }

    private save() {
        fs.writeFileSync(
            path.join(this.accountsPath, 'accounts.json'), 
            JSON.stringify(this.accounts, null, 2)
        );
    }

    private updateStatusBar() {
        const active = this.accounts.find(a => a.isActive);
        if (active) {
            this.statusBarItem.text = '$(account) ' + active.name;
            this.statusBarItem.tooltip = 'Active Codex Account: ' + (active.email || active.name);
            this.statusBarItem.show();
        } else {
            this.statusBarItem.hide();
        }
    }

    private toggleStatusBar() {
        const config = vscode.workspace.getConfiguration('codexSwitcher');
        const current = config.get('showStatusBar', true);
        config.update('showStatusBar', !current, vscode.ConfigurationTarget.Global);
    }

    async quickSwitch() {
        const items = this.accounts.map(a => ({
            label: a.name,
            description: a.email || '',
            detail: a.tag ? '$(tag) ' + a.tag : undefined,
            account: a
        }));
        
        const selected = await vscode.window.showQuickPick(items, {
            placeHolder: 'Select account to switch to'
        });
        
        if (selected) {
            await this.switchAccount(selected.account.id);
        }
    }

    resolveWebviewView(v: vscode.WebviewView) {
        this.view = v;
        v.webview.options = { enableScripts: true };
        v.webview.html = this.getHtml();
        v.webview.onDidReceiveMessage(m => this.handleMessage(m));
        this.update();
    }

    private async handleMessage(m: any) {
        if (m.cmd === 'import') {
            await this.importAccount();
        } else if (m.cmd === 'switch') {
            await this.switchAccount(m.id);
        } else if (m.cmd === 'delete') {
            await this.deleteAccount(m.id);
        } else if (m.cmd === 'rename') {
            await this.renameAccount(m.id, m.name);
        } else if (m.cmd === 'updateTag') {
            await this.updateTag(m.id, m.tag);
        } else if (m.cmd === 'updateColor') {
            await this.updateColor(m.id, m.color);
        }
    }

    async importAccount() {
        const files = await vscode.window.showOpenDialog({ 
            filters: { 'JSON': ['json'] },
            canSelectMany: false
        });
        if (!files?.[0]) return;
        
        try {
            const content = fs.readFileSync(files[0].fsPath, 'utf8');
            const authData = JSON.parse(content);
            const fileName = path.basename(files[0].fsPath, '.json');
            const name = await vscode.window.showInputBox({ 
                prompt: 'Account name', 
                value: fileName 
            });
            
            if (name) {
                const tag = await vscode.window.showQuickPick(
                    ['Work', 'Personal', 'Client', 'Testing', 'Project', 'Other'],
                    { placeHolder: 'Select a tag (optional)' }
                );
                
                this.accounts.push({
                    id: Date.now().toString(36) + Math.random().toString(36).substr(2),
                    name,
                    email: authData.email || authData.user?.email || authData.account?.email,
                    isActive: false,
                    authData,
                    tag: tag || 'Personal',
                    color: TAG_COLORS[tag || 'Personal'],
                    lastUsed: undefined,
                    usageCount: 0
                });
                this.save();
                vscode.window.showInformationMessage('✅ Account "' + name + '" imported!');
                this.update();
            }
        } catch (err) {
            vscode.window.showErrorMessage('❌ Failed to import: ' + err);
        }
    }

    async switchAccount(id: string) {
        const account = this.accounts.find(a => a.id === id);
        if (!account) return;
        
        try {
            const authPath = path.join(this.codexPath, 'auth.json');
            
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
            vscode.window.showInformationMessage('✅ Switched to: ' + account.name);
            this.update();
        } catch (err) {
            vscode.window.showErrorMessage('❌ Failed to switch: ' + err);
        }
    }

    async deleteAccount(id: string) {
        const account = this.accounts.find(a => a.id === id);
        const confirm = await vscode.window.showWarningMessage(
            'Delete "' + (account?.name || 'account') + '"?',
            'Delete', 'Cancel'
        );
        
        if (confirm === 'Delete') {
            this.accounts = this.accounts.filter(a => a.id !== id);
            this.save();
            this.updateStatusBar();
            vscode.window.showInformationMessage('✅ Account deleted');
            this.update();
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

    async updateColor(id: string, color: string) {
        const account = this.accounts.find(a => a.id === id);
        if (account) {
            account.color = color;
            this.save();
            this.update();
        }
    }

    private formatRelativeTime(timestamp?: number): string {
        if (!timestamp) return 'Never used';
        const seconds = Math.floor((Date.now() - timestamp) / 1000);
        if (seconds < 60) return 'Just now';
        if (seconds < 3600) return Math.floor(seconds / 60) + 'm ago';
        if (seconds < 86400) return Math.floor(seconds / 3600) + 'h ago';
        return Math.floor(seconds / 86400) + 'd ago';
    }

    private update() {
        if (this.view) {
            this.view.webview.postMessage({ 
                accounts: this.accounts.map(a => ({
                    ...a,
                    lastUsedText: this.formatRelativeTime(a.lastUsed)
                }))
            });
        }
    }

    private getHtml() {
        return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:var(--vscode-font-family);color:var(--vscode-foreground);background:var(--vscode-sideBar-background);padding:16px}h2{font-size:16px;margin-bottom:12px;font-weight:600}.search-box{width:100%;padding:8px 12px;margin-bottom:16px;background:var(--vscode-input-background);color:var(--vscode-input-foreground);border:1px solid var(--vscode-input-border);border-radius:4px;font-size:13px}.search-box:focus{outline:none;border-color:var(--vscode-focusBorder)}button{background:var(--vscode-button-background);color:var(--vscode-button-foreground);border:none;padding:8px 16px;border-radius:4px;cursor:pointer;font-size:13px;margin:4px 4px 4px 0;transition:background .2s}button:hover{background:var(--vscode-button-hoverBackground)}button.secondary{background:var(--vscode-button-secondaryBackground);color:var(--vscode-button-secondaryForeground)}button.danger{background:#f14c4c;color:#fff}.card{background:var(--vscode-sideBar-dropBackground);border:1px solid var(--vscode-panel-border);border-left:3px solid;border-radius:6px;padding:12px;margin:8px 0;cursor:pointer;transition:all .2s;position:relative}.card:hover{background:var(--vscode-list-hoverBackground);transform:translateX(2px)}.card.active{border-left-width:4px;background:var(--vscode-list-activeSelectionBackground);box-shadow:0 2px 8px rgba(0,0,0,0.15)}.card-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}.card-name{font-weight:600;font-size:14px}.card-email{font-size:12px;color:var(--vscode-descriptionForeground);margin-bottom:6px}.card-meta{display:flex;gap:8px;align-items:center;font-size:11px;color:var(--vscode-descriptionForeground);margin-bottom:8px}.card-actions{display:flex;gap:4px;margin-top:8px;flex-wrap:wrap}.status-badge{font-size:10px;padding:2px 8px;border-radius:12px;background:var(--vscode-badge-background);color:var(--vscode-badge-foreground)}.tag-badge{font-size:10px;padding:2px 6px;border-radius:4px;background:rgba(var(--tag-rgb),0.2);color:var(--vscode-foreground);border:1px solid rgba(var(--tag-rgb),0.4)}.empty{text-align:center;padding:32px 16px;color:var(--vscode-descriptionForeground)}.info{background:var(--vscode-textCodeBlock-background);border-left:3px solid var(--vscode-focusBorder);padding:12px;border-radius:4px;font-size:12px;margin-bottom:16px}.stats{display:flex;gap:4px;font-size:10px;color:var(--vscode-descriptionForeground)}.hidden{display:none!important}</style></head><body><h2>🔄 Codex Account Switcher v2.0</h2><div class="info">Manage multiple ChatGPT Plus accounts • New: Tags, Search, Stats!</div><input type="text" class="search-box" placeholder="🔍 Search accounts by name, email, or tag..." onkeyup="filterAccounts(this.value)"><button onclick="importAccount()">➕ Import Account</button><div id="accounts"></div><script>const vscode=acquireVsCodeApi();let accounts=[];let filteredAccounts=[];window.addEventListener("message",e=>{accounts=e.data.accounts||[];filteredAccounts=accounts;renderAccounts()});function filterAccounts(query){const q=query.toLowerCase();filteredAccounts=accounts.filter(a=>a.name.toLowerCase().includes(q)||((a.email||"").toLowerCase().includes(q))||((a.tag||"").toLowerCase().includes(q)));renderAccounts()}function renderAccounts(){const c=document.getElementById("accounts");if(!filteredAccounts.length){if(accounts.length){c.innerHTML=\'<div class="empty">🔍 No accounts match your search</div>\'}else{c.innerHTML=\'<div class="empty">📦 No accounts yet<br><small>Click "Import Account" to get started</small></div>\'}return}c.innerHTML=filteredAccounts.map(a=>{const ac=a.isActive?"active":"";const sb=a.isActive?\'<span class="status-badge">ACTIVE</span>\':"";const ed=a.email?\'<div class="card-email">📧 \'+a.email+"</div>":"";const tag=a.tag?\'<span class="tag-badge">🏷️ \'+a.tag+"</span>":"";const usage=a.usageCount?\'<span class="stats">🔄 \'+a.usageCount+" uses</span>":"";const lastUsed=a.lastUsedText?\'<span class="stats">🕐 \'+a.lastUsedText+"</span>":"";const borderColor=a.color||"#007ACC";return\'<div class="card \'+ac+\'" style="border-left-color:\'+borderColor+\'" onclick="switchAccount(\\\'\'+a.id+\'\\\')"><div class="card-header"><span class="card-name">\'+a.name+"</span>"+sb+\'</div>\'+ed+\'<div class="card-meta">\'+tag+usage+lastUsed+\'</div><div class="card-actions" onclick="event.stopPropagation()"><button class="secondary" onclick="changeTag(\\\'\'+a.id+\'\\\')">🏷️ Tag</button><button class="secondary" onclick="renameAccount(\\\'\'+a.id+\'\\\')">✏️ Rename</button><button class="danger" onclick="deleteAccount(\\\'\'+a.id+\'\\\')">🗑️ Delete</button></div></div>\'}).join("")}function importAccount(){vscode.postMessage({cmd:"import"})}function switchAccount(id){vscode.postMessage({cmd:"switch",id:id})}function deleteAccount(id){vscode.postMessage({cmd:"delete",id:id})}function renameAccount(id){const a=accounts.find(x=>x.id===id);const n=prompt("New name:",a?a.name:"");if(n&&a&&n!==a.name){vscode.postMessage({cmd:"rename",id:id,name:n})}}function changeTag(id){const tags=["Work","Personal","Client","Testing","Project"];const a=accounts.find(x=>x.id===id);const currentTag=a?a.tag:"Personal";const newTag=prompt("Choose tag ("+tags.join(", ")+"):",currentTag);if(newTag&&tags.includes(newTag)){vscode.postMessage({cmd:"updateTag",id:id,tag:newTag})}}</script></body></html>';
    }
}

export function deactivate() {}
EXT

# Create SVG icon
cat > media/icon.svg << 'SVG'
<svg width="128" height="128" xmlns="http://www.w3.org/2000/svg">
  <circle cx="45" cy="45" r="30" fill="#007ACC" opacity="0.8"/>
  <circle cx="83" cy="83" r="30" fill="#68217A" opacity="0.8"/>
  <path d="M 64 30 A 20 20 0 1 1 64 98" stroke="white" stroke-width="4" fill="none"/>
  <circle cx="64" cy="20" r="6" fill="#FFD700"/>
</svg>
SVG

echo "📦 Installing dependencies..."
npm install --silent 2>&1 | grep -E "added|removed|warn" || true

echo "📦 Installing vsce..."
npm install -g @vscode/vsce --silent 2>&1 || true

echo "🔨 Building extension..."
npm run compile 2>&1 | grep -E "ERROR|WARNING" || echo "✓ Compiled successfully"

echo "📦 Packaging v2.0..."
vsce package --no-yarn 2>&1 || npx @vscode/vsce package --no-yarn 2>&1

VSIX_FILE=$(ls *.vsix 2>/dev/null | head -1)

if [ -n "$VSIX_FILE" ]; then
    cp "$VSIX_FILE" ~/
    echo ""
    echo "✅ Extension v2.0 packaged: ~/$VSIX_FILE"
    
    if command -v code &>/dev/null; then
        echo "🚀 Installing in VS Code..."
        code --install-extension ~/"$VSIX_FILE" --force 2>&1
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Codex Account Switcher v2.0 installed!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🎉 What's New in v2.0:"
        echo "   ✨ Status bar shows active account"
        echo "   🏷️ Color-coded tags for organization"
        echo "   🔍 Search & filter accounts"
        echo "   🕐 Last used timestamps"
        echo "   📊 Usage statistics"
        echo "   ⚡ Quick switch command (Cmd+Shift+P)"
        echo ""
        echo "📖 Next Steps:"
        echo "   1. Look for 'Codex Switcher' in Activity Bar"
        echo "   2. Import your accounts"
        echo "   3. Add tags to organize"
        echo "   4. Use search to find accounts quickly"
        echo "   5. Check status bar for active account"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo "📝 Install: code --install-extension ~/$VSIX_FILE"
    fi
else
    echo "❌ Build failed"
    exit 1
fi

cd ~ && rm -rf "$TEMP_DIR"
