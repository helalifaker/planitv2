# Recommended VS Code / Cursor Extensions for Plan-It

This document lists recommended extensions for developing Plan-It, organized by category and priority.

---

## Essential Extensions (Must Have)

### TypeScript & JavaScript

#### **ESLint** (`dbaeumer.vscode-eslint`)
- **Why:** Enforces code quality and catches TypeScript/React errors
- **Config:** Use with Next.js ESLint config
- **Priority:** ⭐⭐⭐⭐⭐

#### **Prettier** (`esbenp.prettier-vscode`)
- **Why:** Automatic code formatting for consistent style
- **Config:** Create `.prettierrc` aligned with project conventions
- **Priority:** ⭐⭐⭐⭐⭐

#### **TypeScript Nightly** (`ms-vscode.vscode-typescript-next`)
- **Why:** Latest TypeScript features support (you're using TS 5.7)
- **Priority:** ⭐⭐⭐⭐

---

### Python & FastAPI

#### **Python** (`ms-python.python`)
- **Why:** Core Python support for FastAPI backend
- **Priority:** ⭐⭐⭐⭐⭐

#### **Pylance** (`ms-python.vscode-pylance`)
- **Why:** Fast, feature-rich Python language server with type checking
- **Priority:** ⭐⭐⭐⭐⭐

#### **Ruff** (`charliermarsh.ruff`)
- **Why:** Ultra-fast Python linter/formatter (written in Rust, perfect for Python 3.14)
- **Note:** Preferred over pylint/autopep8 (faster, modern)
- **Priority:** ⭐⭐⭐⭐⭐

#### **Black Formatter** (`ms-python.black-formatter`)
- **Why:** Alternative formatter if you prefer Black over Ruff formatting
- **Priority:** ⭐⭐⭐ (Optional - Ruff can format too)

---

### Tailwind CSS

#### **Tailwind CSS IntelliSense** (`bradlc.vscode-tailwindcss`)
- **Why:** Autocomplete, linting, and hover previews for Tailwind CSS 4.0
- **Critical:** Essential for Tailwind development (Pigment aesthetic)
- **Priority:** ⭐⭐⭐⭐⭐

---

### Database

#### **PostgreSQL Client** (`cweijan.vscode-postgresql-client2`)
- **Why:** Direct PostgreSQL connection, query execution, table browsing
- **Use:** Connect to PostgreSQL 18, execute ltree queries, view schema
- **Priority:** ⭐⭐⭐⭐⭐

#### **SQLTools** (`mtxr.sqltools` + `mtxr.sqltools-driver-pg`)
- **Why:** Alternative SQL client with better query history and formatting
- **Priority:** ⭐⭐⭐⭐

---

## Highly Recommended

### Code Quality

#### **Error Lens** (`usernamehw.errorlens`)
- **Why:** Inline error/warning display (saves time debugging)
- **Priority:** ⭐⭐⭐⭐

#### **Pretty TypeScript Errors** (`yoavbls.pretty-ts-errors`)
- **Why:** Makes TypeScript errors readable (instead of walls of red text)
- **Priority:** ⭐⭐⭐⭐

#### **EditorConfig** (`editorconfig.editorconfig`)
- **Why:** Consistent file formatting across team (indentation, line endings)
- **Priority:** ⭐⭐⭐⭐

---

### Productivity

#### **GitLens** (`eamodio.gitlens`)
- **Why:** Enhanced Git capabilities (blame, history, file annotations)
- **Priority:** ⭐⭐⭐⭐

#### **Path Intellisense** (`christian-kohler.path-intellisense`)
- **Why:** Autocomplete for file paths (useful for imports)
- **Priority:** ⭐⭐⭐

#### **Auto Rename Tag** (`formulahendry.auto-rename-tag`)
- **Why:** Automatically renames paired HTML/JSX tags
- **Priority:** ⭐⭐⭐

---

### Documentation

#### **Markdown All in One** (`yzhang.markdown-all-in-one`)
- **Why:** Preview, formatting, and table of contents for Markdown
- **Use:** View/edit PRD, schema docs, README
- **Priority:** ⭐⭐⭐

#### **Markdownlint** (`davidanson.vscode-markdownlint`)
- **Why:** Linting for Markdown files
- **Priority:** ⭐⭐⭐

---

## Optional but Useful

### Testing

#### **Playwright** (`ms-playwright.playwright`)
- **Why:** E2E testing support (if you plan to use Playwright)
- **Priority:** ⭐⭐⭐

#### **Jest** (`orta.vscode-jest`)
- **Why:** Jest testing support for React/TypeScript tests
- **Priority:** ⭐⭐⭐

---

### Configuration Files

#### **Even Better TOML** (`tamasfe.even-better-toml`)
- **Why:** TOML syntax support (useful for `pyproject.toml`, `uv` config)
- **Priority:** ⭐⭐⭐

#### **YAML** (`redhat.vscode-yaml`)
- **Why:** YAML support (Docker Compose, CI/CD configs)
- **Priority:** ⭐⭐

---

## Extension Settings Recommendations

Create `.vscode/settings.json`:

```json
{
  // Python
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.analysis.typeCheckingMode": "basic",
  "ruff.enable": true,
  "ruff.organizeImports": true,

  // TypeScript
  "typescript.preferences.importModuleSpecifier": "relative",
  "typescript.updateImportsOnFileMove.enabled": "always",

  // Formatting
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll": "explicit",
      "source.organizeImports": "explicit"
    }
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },

  // Tailwind CSS
  "tailwindCSS.experimental.classRegex": [
    ["cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]"],
    ["cn\\(([^)]*)\\)", "(?:'|\"|`)([^\"'`]*)(?:'|\"|`)"]
  ],

  // Editor
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  },
  "files.autoSave": "onFocusChange",
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,

  // Git
  "git.autofetch": true,
  "git.confirmSync": false
}
```

---

## Installation

### Quick Install (VS Code / Cursor)

1. **Automatic (Recommended):**
   - Open command palette: `Cmd+Shift+P` (Mac) / `Ctrl+Shift+P` (Windows/Linux)
   - Type: "Extensions: Show Recommended Extensions"
   - Click "Install All"

2. **Manual:**
   - Install extensions one by one from the Extensions marketplace
   - Search by extension ID (e.g., `dbaeumer.vscode-eslint`)

### Command Line Install

```bash
# Install all recommended extensions
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension charliermarsh.ruff
code --install-extension bradlc.vscode-tailwindcss
code --install-extension cweijan.vscode-postgresql-client2
code --install-extension usernamehw.errorlens
code --install-extension eamodio.gitlens
# ... (add others as needed)
```

---

## Notes

- **Ruff vs. Pylint:** Ruff is significantly faster and recommended for Python 3.14. Disable Pylint if Ruff is installed.
- **Black vs. Ruff Formatting:** Ruff can format code (similar to Black) or you can use Black Formatter extension. Choose one.
- **Database Migrations:** This project uses raw SQL migrations (see `docs/DATABASE_SCHEMA_V2.6.md`). No ORM is required.
- **Playwright/Jest:** Install only if you plan to write tests.

---

## Project-Specific Setup

### Python Environment (uv)

```bash
# Ensure Python 3.14.2 is available
python --version  # Should show 3.14.2

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create virtual environment
uv venv
source .venv/bin/activate  # or `.venv\Scripts\activate` on Windows
```

### Node.js Environment (pnpm)

```bash
# Ensure pnpm 9.15.0+ is installed
pnpm --version

# Install dependencies
pnpm install
```

### PostgreSQL Connection

Configure PostgreSQL client extension with:
- **Host:** localhost (or your DB host)
- **Port:** 5432
- **Database:** planit (or your DB name)
- **Username/Password:** From your `.env.local`

---

## Troubleshooting

### ESLint not working
- Check `.eslintrc.json` exists
- Verify ESLint extension is enabled
- Restart VS Code/Cursor

### Python/Pylance issues
- Select correct Python interpreter: `Cmd+Shift+P` → "Python: Select Interpreter"
- Ensure virtual environment is activated
- Check `pyproject.toml` for Ruff config

### Tailwind IntelliSense not working
- Verify `tailwind.config.js` exists
- Check file paths in Tailwind config
- Restart Tailwind extension: `Cmd+Shift+P` → "Tailwind CSS: Restart IntelliSense"

---

## Summary

**Minimum Required Extensions:**
1. ESLint
2. Prettier
3. Python + Pylance
4. Ruff
5. Tailwind CSS IntelliSense
6. PostgreSQL Client

**Full Development Experience:**
- All Essential + Highly Recommended extensions
- Proper VS Code settings configured
- Python virtual environment set up
- Node.js/pnpm configured

