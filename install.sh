#!/bin/bash
# Codex Account Switcher - One-Command Installer
set -e

echo "🚀 Codex Account Switcher - Installing..."
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

# Package.json
cat > package.json << 'PKG'
{"name":"codex-account-switcher","displayName":"Codex Account Switcher","version":"1.0.0","publisher":"codex-tools","engines":{"vscode":"^1.85.0"},"main":"./dist/extension.js","activationEvents":[],"contributes":{"viewsContainers":{"activitybar":[{"id":"codex-switcher","title":"Codex Switcher","icon":"media/icon.svg"}]},"views":{"codex-switcher":[{"type":"webview","id":"codexAccountSwitcher","name":"Accounts"}]},"commands":[{"command":"codex-switcher.import","title":"Import Account","category":"Codex"}]},"scripts":{"compile":"webpack --mode production"},"devDependencies":{"@types/vscode":"^1.85.0","@types/node":"20.x","typescript":"^5.3.3","webpack":"^5.89.0","webpack-cli":"^5.1.4","ts-loader":"^9.5.1"}}
PKG

# TypeScript config
cat > tsconfig.json << 'TSC'
{"compilerOptions":{"module":"commonjs","target":"ES2020","outDir":"./dist","lib":["ES2020"],"sourceMap":true,"rootDir":"./src","strict":true},"include":["src/**/*"]}
TSC

# Webpack config
cat > webpack.config.js << 'WPC'
const path=require('path');module.exports={target:'node',mode:'production',entry:'./src/extension.ts',output:{path:path.resolve(__dirname,'dist'),filename:'extension.js',libraryTarget:'commonjs2'},externals:{vscode:'commonjs vscode'},resolve:{extensions:['.ts','.js']},module:{rules:[{test:/\.ts$/,exclude:/node_modules/,use:[{loader:'ts-loader'}]}]}};
WPC

# Extension code - FIXED escaping issues
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
}

export function activate(ctx: vscode.ExtensionContext) {
    const provider = new AccountProvider(ctx.extensionUri, ctx);
    ctx.subscriptions.push(
        vscode.window.registerWebviewViewProvider('codexAccountSwitcher', provider)
    );
    ctx.subscriptions.push(
        vscode.commands.registerCommand('codex-switcher.import', () => provider.importAccount())
    );
}

class AccountProvider implements vscode.WebviewViewProvider {
    private view?: vscode.WebviewView;
    private accounts: Account[] = [];
    private accountsPath: string;
    private codexPath: string;

    constructor(private uri: vscode.Uri, ctx: vscode.ExtensionContext) {
        this.codexPath = path.join(os.homedir(), '.codex');
        this.accountsPath = path.join(ctx.globalStorageUri.fsPath, 'accounts');
        if (!fs.existsSync(this.accountsPath)) {
            fs.mkdirSync(this.accountsPath, { recursive: true });
        }
        this.load();
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
                this.accounts.push({
                    id: Date.now().toString(36) + Math.random().toString(36).substr(2),
                    name,
                    email: authData.email || authData.user?.email || authData.account?.email,
                    isActive: false,
                    authData
                });
                this.save();
                vscode.window.showInformationMessage('Account "' + name + '" imported!');
                this.update();
            }
        } catch (err) {
            vscode.window.showErrorMessage('Failed to import: ' + err);
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
            this.save();

            vscode.window.showInformationMessage('Switched to: ' + account.name);
            this.update();
        } catch (err) {
            vscode.window.showErrorMessage('Failed to switch: ' + err);
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
            vscode.window.showInformationMessage('Account deleted');
            this.update();
        }
    }

    async renameAccount(id: string, newName: string) {
        const account = this.accounts.find(a => a.id === id);
        if (account && newName) {
            account.name = newName;
            this.save();
            this.update();
        }
    }

    private update() {
        if (this.view) {
            this.view.webview.postMessage({ accounts: this.accounts });
        }
    }

    private getHtml() {
        const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: var(--vscode-font-family); 
            color: var(--vscode-foreground); 
            background: var(--vscode-sideBar-background); 
            padding: 16px; 
        }
        h2 { font-size: 16px; margin-bottom: 16px; font-weight: 600; }
        button { 
            background: var(--vscode-button-background); 
            color: var(--vscode-button-foreground); 
            border: none; 
            padding: 8px 16px; 
            border-radius: 4px; 
            cursor: pointer; 
            font-size: 13px;
            margin: 4px 4px 4px 0;
            transition: background 0.2s;
        }
        button:hover { background: var(--vscode-button-hoverBackground); }
        button.secondary {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
        }
        button.danger { background: #f14c4c; color: white; }
        .card { 
            background: var(--vscode-sideBar-dropBackground); 
            border: 1px solid var(--vscode-panel-border); 
            border-radius: 6px; 
            padding: 12px; 
            margin: 8px 0; 
            cursor: pointer;
            transition: all 0.2s;
        }
        .card:hover { 
            background: var(--vscode-list-hoverBackground); 
            border-color: var(--vscode-focusBorder);
        }
        .card.active { 
            border: 2px solid var(--vscode-focusBorder); 
            background: var(--vscode-list-activeSelectionBackground);
        }
        .card-header { 
            display: flex; 
            justify-content: space-between; 
            align-items: center;
            margin-bottom: 8px;
        }
        .card-name { font-weight: 600; font-size: 14px; }
        .card-email { font-size: 12px; color: var(--vscode-descriptionForeground); margin-bottom: 8px; }
        .card-actions { display: flex; gap: 4px; margin-top: 8px; }
        .status-badge {
            font-size: 10px;
            padding: 2px 8px;
            border-radius: 12px;
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
        }
        .empty { 
            text-align: center; 
            padding: 32px 16px; 
            color: var(--vscode-descriptionForeground);
        }
        .info { 
            background: var(--vscode-textCodeBlock-background);
            border-left: 3px solid var(--vscode-focusBorder);
            padding: 12px;
            border-radius: 4px;
            font-size: 12px;
            margin-bottom: 16px;
        }
    </style>
</head>
<body>
    <h2>🔄 Codex Account Switcher</h2>
    <div class="info">
        Manage multiple ChatGPT Plus accounts for Codex CLI
    </div>
    <button onclick="importAccount()">➕ Import Account</button>
    <div id="accounts"></div>

    <script>
        const vscode = acquireVsCodeApi();
        let accounts = [];

        window.addEventListener('message', event => {
            accounts = event.data.accounts || [];
            renderAccounts();
        });

        function renderAccounts() {
            const container = document.getElementById('accounts');

            if (!accounts.length) {
                container.innerHTML = '<div class="empty">📦 No accounts yet<br><small>Click "Import Account" to get started</small></div>';
                return;
            }

            container.innerHTML = accounts.map(a => {
                const activeClass = a.isActive ? 'active' : '';
                const statusBadge = a.isActive ? '<span class="status-badge">ACTIVE</span>' : '';
                const emailDiv = a.email ? '<div class="card-email">📧 ' + a.email + '</div>' : '';

                return '<div class="card ' + activeClass + '" onclick="switchAccount(\'' + a.id + '\')">' +
                    '<div class="card-header">' +
                        '<span class="card-name">' + a.name + '</span>' +
                        statusBadge +
                    '</div>' +
                    emailDiv +
                    '<div class="card-actions" onclick="event.stopPropagation()">' +
                        '<button class="secondary" onclick="renameAccount(\'' + a.id + '\')">Rename</button>' +
                        '<button class="danger" onclick="deleteAccount(\'' + a.id + '\')">Delete</button>' +
                    '</div>' +
                '</div>';
            }).join('');
        }

        function importAccount() {
            vscode.postMessage({ cmd: 'import' });
        }

        function switchAccount(id) {
            vscode.postMessage({ cmd: 'switch', id: id });
        }

        function deleteAccount(id) {
            vscode.postMessage({ cmd: 'delete', id: id });
        }

        function renameAccount(id) {
            const account = accounts.find(a => a.id === id);
            const newName = prompt('New name:', account ? account.name : '');
            if (newName && account && newName !== account.name) {
                vscode.postMessage({ cmd: 'rename', id: id, name: newName });
            }
        }
    </script>
</body>
</html>`;
        return html;
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
</svg>
SVG

echo "📦 Installing dependencies..."
npm install --silent 2>&1 | grep -E "added|removed|warn" || true

echo "📦 Installing vsce..."
npm install -g @vscode/vsce --silent 2>&1 || true

echo "🔨 Building extension..."
npm run compile 2>&1 | grep -E "ERROR|WARNING" || echo "✓ Compiled successfully"

echo "📦 Packaging..."
vsce package --no-yarn 2>&1 || npx @vscode/vsce package --no-yarn 2>&1

# Find and move the .vsix file
VSIX_FILE=$(ls *.vsix 2>/dev/null | head -1)

if [ -n "$VSIX_FILE" ]; then
    cp "$VSIX_FILE" ~/
    echo ""
    echo "✅ Extension packaged: ~/$VSIX_FILE"

    # Try to install automatically
    if command -v code &>/dev/null; then
        echo "🚀 Installing in VS Code..."
        if code --install-extension ~/"$VSIX_FILE" 2>&1 | grep -q "successfully installed"; then
            echo "✅ Installation complete!"
            echo ""
            echo "🎉 Setup complete!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "   1. Open VS Code"
            echo "   2. Click the Codex icon in the Activity Bar"
            echo "   3. Import your auth.json files"
            echo "   4. Switch accounts with one click!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo "📝 Manual install: code --install-extension ~/$VSIX_FILE"
        fi
    else
        echo "📝 Install manually: code --install-extension ~/$VSIX_FILE"
    fi
else
    echo "❌ Build failed. Please report this issue."
    exit 1
fi

# Cleanup
cd ~ && rm -rf "$TEMP_DIR"
