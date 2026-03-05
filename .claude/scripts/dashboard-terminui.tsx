/**
 * terminui Dashboard Renderer
 * Reads JSON from stdin, renders retro sci-fi dashboard via terminui.
 * Usage: dashboard-data-json.sh | npx tsx scripts/dashboard-terminui.tsx
 */
/** @jsxRuntime automatic */
/** @jsxImportSource terminui */
import {
  createTestBackendState,
  createTestBackend,
  testBackendToString,
  createTerminal,
} from 'terminui';
import {
  terminalDrawJsx,
  Column,
  Row,
  Panel,
  Label,
  List,
  Gauge,
  Sparkline,
  Tabs,
} from 'terminui/jsx';
import {
  lengthConstraint,
  fillConstraint,
  Color,
} from 'terminui';

// ─── Read JSON from stdin (sync via fd) ───
import { readFileSync } from 'node:fs';
const raw = readFileSync(0, 'utf-8');

interface MeshPeer {
  name: string;
  os: string;
  role: string;
  status: string;
  capabilities: string[];
  online: boolean;
  cpu: number;
  tasks: number;
}

interface Plan {
  id: number;
  name: string;
  project: string;
  host: string;
  description: string;
  wave_total: number;
  wave_done: number;
  task_total: number;
  task_done: number;
  tokens: number;
  started_at: string;
}

interface DashData {
  overview: {
    total: number; done: number; doing: number;
    todo: number; cancelled: number;
    tasks_total: number; tasks_done: number; tasks_running: number;
  };
  plans: Plan[];
  mesh: MeshPeer[];
}

const data: DashData = JSON.parse(raw);
const ov = data.overview;
const peers = data.mesh;
const plans = data.plans;

// ─── Terminal size ───
const cols = process.stdout.columns || 80;
const rows = Math.min(process.stdout.rows || 40, 40);

const state = createTestBackendState(cols, rows);
const backend = createTestBackend(state);
const terminal = createTerminal(backend);

// ─── Helper: format tokens ───
const fmtTokens = (t: number): string => {
  if (t >= 1_000_000) return `${(t / 1_000_000).toFixed(0)}M`;
  if (t >= 1_000) return `${(t / 1_000).toFixed(0)}K`;
  return `${t}`;
};

// ─── Helper: mesh topology ASCII art ───
const meshTopology = (): string => {
  if (peers.length === 0) return '  No peers configured';
  const coord = peers.find(p => p.role === 'coordinator') || peers[0];
  const workers = peers.filter(p => p !== coord);
  const icon = (p: MeshPeer) => p.online ? '●' : '○';
  const star = (p: MeshPeer) => p.role === 'coordinator' ? '★' : '●';
  const caps = (p: MeshPeer) =>
    p.capabilities.map(c => c === 'claude' ? 'C' : c === 'copilot' ? 'P' : c === 'ollama' ? 'O' : c[0]?.toUpperCase()).join('');

  const lines: string[] = [];
  // Triangle topology
  if (coord) {
    const cl = `${icon(coord)} ${star(coord)} ${coord.name} [${caps(coord)}] ${coord.online ? 'ON' : 'OFF'} CPU:${coord.cpu}%`;
    const pad = Math.max(0, Math.floor((cols - 20) / 2) - cl.length / 2);
    lines.push(' '.repeat(Math.max(2, pad)) + cl);
  }
  // Connection lines
  const mid = Math.max(8, Math.floor(cols / 2) - 4);
  lines.push(' '.repeat(mid) + '╱ ╲');
  lines.push(' '.repeat(mid - 1) + '╱   ╲');
  // Workers
  const wLine = workers.map(w =>
    `${icon(w)} ${star(w)} ${w.name} [${caps(w)}] ${w.online ? 'ON' : 'OFF'} CPU:${w.cpu}%`
  ).join('    ');
  lines.push('  ' + wLine);
  // Backbone
  if (workers.length >= 2) {
    const bpad = Math.max(2, Math.floor(cols / 2) - 10);
    lines.push(' '.repeat(bpad) + '╲━━━━━━━━━━╱');
    lines.push(' '.repeat(bpad) + '  BACKBONE');
  }
  return lines.join('\n');
};

// ─── Build plan items for List widget ───
const planItems = plans.map(p => {
  const pct = p.task_total > 0 ? Math.round(p.task_done * 100 / p.task_total) : 0;
  const tok = fmtTokens(p.tokens);
  return `#${p.id} ${p.name} [${p.project}] ${pct}% (${p.task_done}/${p.task_total}) W${p.wave_done}/${p.wave_total} ${tok}tok`;
});

// ─── Build mesh status line ───
const onlineCount = peers.filter(p => p.online).length;
const totalTasks = peers.reduce((s, p) => s + p.tasks, 0);
const meshTitle = `Mesh Network (${onlineCount}/${peers.length} online, ${totalTasks} tasks)`;

// ─── Render ───
terminalDrawJsx(
  terminal,
  <Column constraints={[
    lengthConstraint(3),  // header
    lengthConstraint(5),  // overview
    lengthConstraint(12), // mesh
    fillConstraint(1),    // plans
    lengthConstraint(3),  // footer
  ]}>
    {/* Header */}
    <Panel title="CONVERGIO.IO" p={1}>
      <Label
        text="━━ TERMINUI DASHBOARD ━━"
        align="center"
        fg={Color.Cyan}
        bold
      />
    </Panel>

    {/* Overview */}
    <Row constraints={[fillConstraint(1), fillConstraint(1)]} gap={1}>
      <Panel title="Plans">
        <Label
          text={`done:${ov.done}  active:${ov.doing}  queue:${ov.todo}  void:${ov.cancelled}  total:${ov.total}`}
          fg={Color.White}
        />
      </Panel>
      <Panel title="Tasks">
        <Gauge
          percent={ov.tasks_total > 0
            ? Math.round(ov.tasks_done * 100 / ov.tasks_total)
            : 0}
        />
      </Panel>
    </Row>

    {/* Mesh */}
    <Panel title={meshTitle}>
      <Label text={meshTopology()} fg={Color.Green} />
    </Panel>

    {/* Active Plans */}
    <Panel title={`Active Missions (${plans.length})`}>
      {plans.length > 0
        ? <List items={planItems} highlightSymbol="▸ " />
        : <Label text="No active plans" fg={Color.DarkGray} />
      }
    </Panel>

    {/* Footer */}
    <Panel p={1}>
      <Label
        text="piani -h │ TERMINUI RENDERER v1.0 │ terminui + tsx"
        align="center"
        fg={Color.DarkGray}
      />
    </Panel>
  </Column>,
);

// Output to stdout
process.stdout.write(testBackendToString(state) + '\n');
