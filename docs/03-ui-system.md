# UI System

Sofa Studio is a database client built with Qt Quick (QML), focusing on top-tier UI/UX for technical software while maintaining a lean and extensible core.

## UI/UX Premises

*   **UI/UX is a Priority**: The initial MVP proved the core functionality; now the focus is on transforming the experience into a benchmark for quality.
*   **macOS-First, Without Breaking Cross-Platform**: We use macOS as the reference for visual patterns and behavior, but maintain full compatibility with Windows and Linux.
*   **Platform-Specific Enhancements are Allowed**: When a superior visual feature or interaction exists on macOS, we may adopt it with a simple functional fallback for other platforms.
*   **Dark Theme by Default**: In the short term, we refine the dark mode; in the future, we will expand to multiple themes using the same token system.
*   **Custom Visuals (Non-"Generic Qt")**: We avoid relying on default Qt/Controls visuals; we build a consistent identity across all platforms.
*   **Custom Components for Critical UX**: Relevant components must be custom-built (like the `DataGrid`) for quality, performance, and consistency.
*   **Relevant Components are Dedicated Types**: Each relevant custom component must exist as an isolated type (QML file) and, when necessary, a C++ backing class.
*   **Low Dependency on Complex External Components**: We prefer implementing essential components internally to maintain control over design and behavior.
*   **Component Documentation**: Every relevant custom component must have its own documentation to guide evolution and maintain consistency.

## Structure (Shell)

*   **Entry Point**: [Main.qml](apps/desktop/qml/Main.qml) controls the root layout, navigation, and "sessions" (tabs).
*   **Design System / Shared Components**: [src/ui](src/ui) contains reusable components (e.g., `AppButton`, `AppTabs`, `AppSidebar`).
*   **Data Flow**: The UI calls `Q_INVOKABLE` methods on `AppContext` and reacts to signals (the Core never calls the UI directly).

## Theming (Tokens)

**File:** [Theme.qml](src/ui/Theme.qml)

`Theme` is a singleton of semantic tokens (colors, spacing, sizes). Components should not "invent" visual values on their own.

*   **No Hardcoded Hex in Components**: Colors and sizes must come from `Theme` (or tokens derived from it).
*   **Semantic Tokens, Not "Raw"**: Prefer `surface`, `border`, `textPrimary` over "gray700".
*   **Dark First**: New components must be designed with contrast, states, and borders tailored for the dark theme.

## Identidade Visual (Cores Institucionais)

**Base visual oficial (hex):**

*   **Destaque principal**: `#01D4FE`
*   **Destaque secundário**: `#60115F`
*   **Background**: `#0F0F0F`
*   **Destaque escuro 1**: `#0C2433`
*   **Destaque escuro 2**: `#12414E`

**Regras de aplicação:**

*   **Tokens primeiro**: Todas as cores devem ser expostas em `Theme` e consumidas pelos componentes.
*   **Avatar de conexão**: A paleta deve derivar dessas cores e o texto usa contraste automático (claro em fundo escuro, escuro em fundo claro).
*   **Consistência de contraste**: Elementos de destaque precisam manter legibilidade em estados de hover/ativo.

## Multi-Platform Strategy

*   **Consistent Behavior**: Layout, density, states (hover/focus/pressed/disabled), and micro-interactions must remain equivalent across OSs.
*   **Targeted OS Adaptation**: Differences are acceptable when they elevate quality (especially on macOS), provided there is a functional and visually coherent fallback on Windows/Linux.
*   **No Native Style Dependency**: The goal is a unique identity; when using OS-specific APIs/effects, the result should feel like "Sofa", not a "system theme".

## Key Components (Current)

### DataGrid
**File:** [DataGrid.qml](src/ui/DataGrid.qml)

QML wrapper for the C++ engine (`DataGridEngine`) for performance and virtualization.

*   **API**: `engine` (C++ object), `controlsVisible`.
*   **Rendering**: The main area is C++ (e.g., `DataGridView`) and navigation uses QML components (e.g., `ScrollBar`).

### SqlConsole
**File:** [SqlConsole.qml](src/ui/SqlConsole.qml)

SQL console with input and results.

*   **Layout**: Editor on top and `DataGrid` on the bottom.
*   **Interactions**: `Cmd+Enter` to run, `Esc` to cancel.
*   **States**: Loading, error, and empty must be treated as first-class states (clear UI without "flickering").

### ViewEditor
**File:** [ViewEditor.qml](src/ui/ViewEditor.qml)

"Beauty Mode" editor to customize table visualization.

*   **Input**: `tableSchema` (JSON / variant).
*   **Output**: Modified definition.
*   **Persistence**: Saves to `LocalStore` via `App.saveView()`.

## Component Documentation (Required)

Every relevant custom component must have its own document in `docs/` describing:

1.  **Purpose and Scope** (what it solves and what it doesn't).
2.  **Public API** (properties, signals, methods, expected models).
3.  **States and Transitions** (loading/empty/error; hover/focus/pressed; enabled/disabled).
4.  **Theme Rules** (tokens used and how the component reacts to themes).
5.  **Platform Notes** (OS-specific differences and fallback).
6.  **Accessibility and Keyboard** (focus, navigation, shortcuts, and proper screen reading).
7.  **Performance** (expected costs; when to move to C++; virtualization when applicable).

## Example Flow: "Run Query"

1.  `SqlConsole` calls `App.runQueryAsync(...)`.
2.  `SqlConsole` listens for signals via `Connections { target: App }`.
3.  `onSqlStarted`: Enters execution state (loading UI).
4.  `onSqlFinished`:
    *   Exits execution state.
    *   Populates the grid (e.g., `gridEngine.loadFromVariant(result)`).
    *   Updates indicators (rows / time).
5.  `onSqlError`: Displays error state with clear message and possible action (when applicable).
