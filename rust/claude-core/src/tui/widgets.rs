use std::collections::BTreeMap;

use ratatui::{
    style::{Color, Style, Stylize},
    text::{Line, Text},
    widgets::{Block, Borders, Paragraph, Wrap},
};

use super::TuiData;

pub fn plan_kanban(data: &TuiData) -> Paragraph<'static> {
    let mut cols: BTreeMap<&str, Vec<String>> = BTreeMap::new();
    cols.insert("TODO", Vec::new());
    cols.insert("DOING", Vec::new());
    cols.insert("BLOCKED", Vec::new());
    cols.insert("DONE", Vec::new());

    for plan in &data.plans {
        let key = match plan.status.as_str() {
            "todo" => "TODO",
            "doing" => "DOING",
            "blocked" => "BLOCKED",
            "done" => "DONE",
            _ => "TODO",
        };
        let pct = if plan.tasks_total > 0 {
            (plan.tasks_done * 100) / plan.tasks_total
        } else {
            0
        };
        cols.entry(key).or_default().push(format!(
            "#{:<6} {:<28} {:>3}% ({}/{})",
            plan.id, plan.name, pct, plan.tasks_done, plan.tasks_total
        ));
    }

    let mut lines: Vec<Line<'static>> = vec!["PLAN KANBAN".cyan().bold().into(), "".into()];
    for col in ["TODO", "DOING", "BLOCKED", "DONE"] {
        lines.push(Line::from(format!("{}:", col)).style(Style::default().fg(Color::Yellow)));
        if let Some(items) = cols.get(col) {
            if items.is_empty() {
                lines.push("  -".dark_gray().into());
            } else {
                for item in items {
                    lines.push(Line::from(format!("  {}", item)));
                }
            }
        }
        lines.push("".into());
    }

    Paragraph::new(Text::from(lines))
        .block(Block::default().title(" Plans ").borders(Borders::ALL))
        .wrap(Wrap { trim: true })
}

pub fn task_pipeline(data: &TuiData) -> Paragraph<'static> {
    let mut lines: Vec<Line<'static>> = vec![
        "TASK PIPELINE".cyan().bold().into(),
        "ID       Status        Agent       Title".yellow().into(),
        "".into(),
    ];
    for task in &data.pipeline {
        let status = match task.status.as_str() {
            "in_progress" => "IN_PROGRESS",
            "submitted" => "SUBMITTED",
            "done" => "DONE",
            "blocked" => "BLOCKED",
            _ => "PENDING",
        };
        lines.push(Line::from(format!(
            "{:<8} {:<13} {:<10} {}",
            task.task_id, status, task.agent, task.title
        )));
    }
    if data.pipeline.is_empty() {
        lines.push("No tasks in pipeline".dark_gray().into());
    }
    Paragraph::new(Text::from(lines))
        .block(Block::default().title(" Tasks ").borders(Borders::ALL))
        .wrap(Wrap { trim: true })
}

pub fn mesh_status(data: &TuiData) -> Paragraph<'static> {
    let online = data.mesh_nodes.iter().filter(|n| n.online).count();
    let mut lines: Vec<Line<'static>> = vec![
        "MESH STATUS".cyan().bold().into(),
        Line::from(format!(
            "Online nodes: {}/{}",
            online,
            data.mesh_nodes.len()
        ))
        .style(Style::default().fg(Color::Green)),
        "".into(),
    ];
    for node in &data.mesh_nodes {
        let status = if node.online { "ONLINE" } else { "OFFLINE" };
        let cpu_bar = spark(node.cpu_load);
        lines.push(Line::from(format!(
            "{:<16} {:<8} tasks:{:<3} cpu:{:<3}% {}",
            node.name, status, node.active_tasks, node.cpu_load, cpu_bar
        )));
    }
    if data.mesh_nodes.is_empty() {
        lines.push("No mesh peers found".dark_gray().into());
    }
    Paragraph::new(Text::from(lines))
        .block(Block::default().title(" Mesh ").borders(Borders::ALL))
        .wrap(Wrap { trim: true })
}

pub fn agent_org_chart(data: &TuiData) -> Paragraph<'static> {
    let mut lines: Vec<Line<'static>> = vec![
        "AGENT ORG CHART".cyan().bold().into(),
        "ControlRoom".yellow().into(),
    ];
    for (idx, agent) in data.agents.iter().enumerate() {
        let branch = if idx + 1 == data.agents.len() {
            "└──"
        } else {
            "├──"
        };
        let task = agent.active_task.clone().unwrap_or_else(|| "idle".to_string());
        lines.push(Line::from(format!(
            "{} {} ({}) @{} [{}]",
            branch, agent.name, agent.role, agent.host, task
        )));
    }
    if data.agents.is_empty() {
        lines.push("└── no active agents".dark_gray().into());
    }
    Paragraph::new(Text::from(lines))
        .block(Block::default().title(" Agents ").borders(Borders::ALL))
        .wrap(Wrap { trim: true })
}

fn spark(cpu: i64) -> String {
    let levels = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];
    let clamped = cpu.clamp(0, 100) as usize;
    let idx = clamped * (levels.len() - 1) / 100;
    levels[idx].repeat(6)
}
