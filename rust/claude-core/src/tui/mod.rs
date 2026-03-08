pub mod views;
pub mod widgets;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PlanCard {
    pub id: i64,
    pub name: String,
    pub status: String,
    pub tasks_done: i64,
    pub tasks_total: i64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TaskPipelineItem {
    pub task_id: String,
    pub title: String,
    pub status: String,
    pub agent: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MeshNode {
    pub name: String,
    pub online: bool,
    pub active_tasks: i64,
    pub cpu_load: i64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AgentOrgNode {
    pub name: String,
    pub role: String,
    pub host: String,
    pub active_task: Option<String>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct TuiData {
    pub plans: Vec<PlanCard>,
    pub pipeline: Vec<TaskPipelineItem>,
    pub mesh_nodes: Vec<MeshNode>,
    pub agents: Vec<AgentOrgNode>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum MainView {
    #[default]
    PlanKanban,
    TaskPipeline,
    MeshStatus,
    AgentOrgChart,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct TuiApp {
    pub data: TuiData,
    pub active_view: MainView,
}

impl TuiApp {
    pub fn next_view(&mut self) {
        self.active_view = match self.active_view {
            MainView::PlanKanban => MainView::TaskPipeline,
            MainView::TaskPipeline => MainView::MeshStatus,
            MainView::MeshStatus => MainView::AgentOrgChart,
            MainView::AgentOrgChart => MainView::PlanKanban,
        };
    }

    pub fn prev_view(&mut self) {
        self.active_view = match self.active_view {
            MainView::PlanKanban => MainView::AgentOrgChart,
            MainView::TaskPipeline => MainView::PlanKanban,
            MainView::MeshStatus => MainView::TaskPipeline,
            MainView::AgentOrgChart => MainView::MeshStatus,
        };
    }
}

#[cfg(test)]
mod tests {
    use super::{
        views, AgentOrgNode, MainView, MeshNode, PlanCard, TaskPipelineItem, TuiApp, TuiData,
    };
    use ratatui::{backend::TestBackend, Terminal};

    #[test]
    fn renders_plan_kanban_view() {
        let data = sample_data();
        let rendered = render_to_text(&data, MainView::PlanKanban);
        assert!(rendered.contains("PLAN KANBAN"));
        assert!(rendered.contains("Stabilize Mesh"));
    }

    #[test]
    fn renders_task_pipeline_view() {
        let data = sample_data();
        let rendered = render_to_text(&data, MainView::TaskPipeline);
        assert!(rendered.contains("TASK PIPELINE"));
        assert!(rendered.contains("T13-01"));
    }

    #[test]
    fn renders_mesh_status_view() {
        let data = sample_data();
        let rendered = render_to_text(&data, MainView::MeshStatus);
        assert!(rendered.contains("MESH STATUS"));
        assert!(rendered.contains("node-a"));
    }

    #[test]
    fn renders_agent_org_chart_view() {
        let data = sample_data();
        let rendered = render_to_text(&data, MainView::AgentOrgChart);
        assert!(rendered.contains("AGENT ORG CHART"));
        assert!(rendered.contains("Thor"));
    }

    fn render_to_text(data: &TuiData, view: MainView) -> String {
        let backend = TestBackend::new(120, 30);
        let mut terminal = Terminal::new(backend).expect("terminal");
        terminal
            .draw(|frame| {
                views::render_view(frame, frame.area(), view, data);
            })
            .expect("draw");
        let mut all = String::new();
        for row in terminal.backend().buffer().content.chunks(120) {
            let line = row.iter().map(|cell| cell.symbol()).collect::<String>();
            all.push_str(&line);
            all.push('\n');
        }
        all
    }

    fn sample_data() -> TuiData {
        TuiData {
            plans: vec![
                PlanCard {
                    id: 100025,
                    name: "Stabilize Mesh".to_string(),
                    status: "doing".to_string(),
                    tasks_done: 12,
                    tasks_total: 18,
                },
                PlanCard {
                    id: 100026,
                    name: "Rust TUI Port".to_string(),
                    status: "todo".to_string(),
                    tasks_done: 0,
                    tasks_total: 8,
                },
            ],
            pipeline: vec![TaskPipelineItem {
                task_id: "T13-01".to_string(),
                title: "Implement Rust TUI".to_string(),
                status: "in_progress".to_string(),
                agent: "copilot".to_string(),
            }],
            mesh_nodes: vec![MeshNode {
                name: "node-a".to_string(),
                online: true,
                active_tasks: 2,
                cpu_load: 41,
            }],
            agents: vec![AgentOrgNode {
                name: "Thor".to_string(),
                role: "validator".to_string(),
                host: "node-a".to_string(),
                active_task: Some("T13-01".to_string()),
            }],
        }
    }

    #[test]
    fn cycles_views_forward_and_backward() {
        let mut app = TuiApp::default();
        assert_eq!(app.active_view, MainView::PlanKanban);
        app.next_view();
        assert_eq!(app.active_view, MainView::TaskPipeline);
        app.prev_view();
        assert_eq!(app.active_view, MainView::PlanKanban);
    }
}
