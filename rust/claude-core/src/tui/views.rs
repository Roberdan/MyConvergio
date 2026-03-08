use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Style},
    text::Line,
    widgets::{Block, Borders, Paragraph},
    Frame,
};

use super::{MainView, TuiData};
use crate::tui::widgets;

pub fn render_view(frame: &mut Frame<'_>, area: Rect, view: MainView, data: &TuiData) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(1), Constraint::Length(2)])
        .split(area);
    let header = Paragraph::new(Line::from(format!(
        " Convergio Rust TUI | {} ",
        view_name(view)
    )))
    .block(Block::default().borders(Borders::ALL))
    .style(Style::default().fg(Color::Cyan).bold());
    frame.render_widget(header, chunks[0]);

    match view {
        MainView::PlanKanban => frame.render_widget(widgets::plan_kanban(data), chunks[1]),
        MainView::TaskPipeline => frame.render_widget(widgets::task_pipeline(data), chunks[1]),
        MainView::MeshStatus => frame.render_widget(widgets::mesh_status(data), chunks[1]),
        MainView::AgentOrgChart => frame.render_widget(widgets::agent_org_chart(data), chunks[1]),
    }
    let footer = Paragraph::new(" [1] Kanban  [2] Pipeline  [3] Mesh  [4] Org  [Tab] Next view ")
        .block(Block::default().borders(Borders::ALL))
        .style(Style::default().fg(Color::DarkGray));
    frame.render_widget(footer, chunks[2]);
}

fn view_name(view: MainView) -> &'static str {
    match view {
        MainView::PlanKanban => "Plan Kanban",
        MainView::TaskPipeline => "Task Pipeline",
        MainView::MeshStatus => "Mesh Status",
        MainView::AgentOrgChart => "Agent Org Chart",
    }
}
