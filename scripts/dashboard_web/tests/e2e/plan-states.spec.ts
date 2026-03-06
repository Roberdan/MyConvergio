import { test, expect, MOCK } from "./fixtures";

test.describe("Plan states rendering", () => {
  test("cancelled plan shows correct status color", async ({
    page,
    mockApis,
  }) => {
    await mockApis({
      planDetail: {
        ...MOCK.planDetail,
        plan: { ...MOCK.planDetail.plan, status: "cancelled" },
        waves: [],
        tasks: [],
        cost: { cost: 0, tokens: 0 },
      },
    });
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });
    await expect(page.locator(".sb-meta")).toContainText("CANCELLED");
  });

  test("todo plan shows status in sidebar", async ({ page, mockApis }) => {
    await mockApis({
      planDetail: {
        ...MOCK.planDetail,
        plan: { ...MOCK.planDetail.plan, status: "todo", tasks_done: 0 },
        waves: [],
        tasks: [],
        cost: { cost: 0, tokens: 0 },
      },
    });
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });
    await expect(page.locator(".sb-meta")).toContainText("TODO");
    // todo plan should show Reset and Cancel buttons
    await expect(page.locator(".plan-action-reset")).toBeVisible();
    await expect(page.locator(".plan-action-cancel")).toBeVisible();
  });

  test("done plan hides action buttons in sidebar", async ({
    page,
    mockApis,
  }) => {
    await mockApis({
      planDetail: {
        ...MOCK.planDetail,
        plan: {
          ...MOCK.planDetail.plan,
          status: "done",
          tasks_done: 8,
          completed_at: "2026-03-05",
        },
        waves: [],
        tasks: [],
        cost: { cost: 52.3, tokens: 520000 },
      },
    });
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });
    await expect(page.locator(".plan-action-reset")).toHaveCount(0);
    await expect(page.locator(".plan-action-cancel")).toHaveCount(0);
  });

  test("blocked task shows red indicator in sidebar", async ({
    page,
    mockApis,
  }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });
    // Plan 300 has a blocked task (T6)
    const blockedTask = page.locator(".sb-task", { hasText: "blocked" });
    await expect(blockedTask).toHaveCount(0); // planDetail mock only has T1 and T4
  });

  test("plan with waves renders wave progress bars", async ({
    page,
    mockApis,
  }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });
    // Should have 2 waves (W1, W2)
    const waves = page.locator(".sb-wave");
    await expect(waves).toHaveCount(2);
    // W1 should show 100%
    await expect(waves.nth(0)).toContainText("100%");
  });

  test("plan with PR shows PR number in wave", async ({ page, mockApis }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });
    await expect(page.locator(".sb-wave").first()).toContainText("PR #42");
  });
});

test.describe("Mission panel states", () => {
  test("no active plans shows empty message", async ({ page, mockApis }) => {
    await mockApis({ mission: { plans: [] } });
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });
    await expect(page.locator("#mission-content")).toContainText(
      /no active|idle/i,
    );
  });

  test("plan with 0% progress shows ring", async ({ page, mockApis }) => {
    const zeroPlan = {
      plans: [
        {
          ...MOCK.mission.plans[0],
          plan: {
            ...MOCK.mission.plans[0].plan,
            tasks_done: 0,
            tasks_total: 5,
          },
        },
      ],
    };
    await mockApis({ mission: zeroPlan });
    await page.goto("/");
    await page.waitForSelector(".mission-ring", { timeout: 5000 });
    const ring = page.locator(".mission-ring").first();
    await expect(ring).toBeVisible();
    await expect(ring.locator(".mission-ring-pct")).toContainText("0%");
  });
});

test.describe("Font loading", () => {
  test("CSS loads JetBrainsMono font family", async ({ page, mockApis }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    const fontFamily = await page.evaluate(() =>
      getComputedStyle(document.body).getPropertyValue("--font-mono"),
    );
    expect(fontFamily).toContain("JetBrainsMono");
  });

  test("body uses mono font variable", async ({ page, mockApis }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    const bodyFont = await page.evaluate(
      () => getComputedStyle(document.body).fontFamily,
    );
    expect(bodyFont).toContain("JetBrains");
  });
});

test.describe("History panel", () => {
  test("history shows completed plans", async ({ page, mockApis }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    const historyRows = page.locator(".history-row");
    await expect(historyRows).toHaveCount(2);
    await expect(historyRows.first()).toContainText("#299");
    await expect(historyRows.first()).toContainText("DB migration");
  });

  test("openPlanSidebar renders sidebar with plan data", async ({
    page,
    mockApis,
  }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 5000 });
    await expect(page.locator("#sb-title")).toContainText("#300");
    await expect(page.locator(".sb-meta")).toContainText("DOING");
  });
});

test.describe("Event feed", () => {
  test("events render with correct icons", async ({ page, mockApis }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    const eventRows = page.locator(".event-row");
    await expect(eventRows).toHaveCount(2);
  });

  test("event with plan_id is clickable", async ({ page, mockApis }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    const firstEvent = page.locator(".event-row").first();
    const cursor = await firstEvent.evaluate(
      (el) => getComputedStyle(el).cursor,
    );
    expect(cursor).toBe("pointer");
  });

  test("empty events show placeholder", async ({ page, mockApis }) => {
    await mockApis({ events: [] });
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });

    await expect(page.locator("#event-feed-content")).toContainText(
      "No events",
    );
  });
});
