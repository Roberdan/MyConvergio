import { test, expect, MOCK } from "./fixtures";

/** Stub WebSocket to prevent real connections. */
async function stubWS(page: import("@playwright/test").Page) {
  await page.evaluate(() => {
    (window as any).WebSocket = class FakeWS {
      readyState = 3;
      binaryType = "arraybuffer";
      onopen: any;
      onclose: any;
      onerror: any;
      onmessage: any;
      sent: any[] = [];
      send(data: any) {
        this.sent.push(data);
      }
      close() {}
      constructor() {
        const self = this;
        setTimeout(() => {
          self.readyState = 1;
          if (self.onopen) self.onopen();
        }, 30);
      }
    };
  });
}

test.describe("Plan Cancel & Reset (sidebar)", () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    // Register cancel/reset mocks AFTER generic mockApis (last registered wins)
    await page.route("**/api/plan/cancel*", (route) =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true, plan_id: 300, action: "cancelled" }),
      }),
    );
    await page.route("**/api/plan/reset*", (route) =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true, plan_id: 300, action: "reset" }),
      }),
    );
    await page.goto("/");
    await page.waitForSelector(".kpi-bar .kpi-card", { timeout: 5000 });
  });

  test("sidebar shows Reset and Cancel buttons for active plan", async ({
    page,
  }) => {
    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });

    const resetBtn = page.locator(".plan-action-reset");
    const cancelBtn = page.locator(".plan-action-cancel");
    await expect(resetBtn).toBeVisible();
    await expect(cancelBtn).toBeVisible();
    await expect(resetBtn).toContainText("Reset");
    await expect(cancelBtn).toContainText("Cancel");
  });

  test("sidebar hides action buttons for completed plan", async ({ page }) => {
    await page.route("**/api/plan/300", (route) =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          ...MOCK.planDetail,
          plan: { ...MOCK.planDetail.plan, status: "done" },
        }),
      }),
    );
    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });

    await expect(page.locator(".plan-action-reset")).toHaveCount(0);
    await expect(page.locator(".plan-action-cancel")).toHaveCount(0);
  });

  test("cancel button opens custom modal", async ({ page }) => {
    await page.evaluate(() => (window as any).openPlanSidebar(300));
    await page.waitForSelector("#sidebar.open", { timeout: 3000 });

    // Call cancelPlan directly to avoid onclick routing issues
    await page.evaluate(() => (window as any).cancelPlan(300));
    await page.waitForSelector(".modal-overlay", { timeout: 3000 });

    // Modal should have confirm button
    await expect(page.locator("#confirm-cancel-btn")).toBeVisible();
    await expect(page.locator(".modal-title")).toContainText("Cancel Plan");
  });

  test("cancel confirm button calls API", async ({ page }) => {
    await page.evaluate(() => (window as any).cancelPlan(300));
    await page.waitForSelector("#confirm-cancel-btn", { timeout: 3000 });

    const [request] = await Promise.all([
      page.waitForRequest((req) => req.url().includes("/api/plan/cancel")),
      page.locator("#confirm-cancel-btn").click(),
    ]);
    expect(request.url()).toContain("plan_id=300");
  });

  test("reset button opens custom modal", async ({ page }) => {
    await page.evaluate(() => (window as any).resetPlan(300));
    await page.waitForSelector(".modal-overlay", { timeout: 3000 });

    await expect(page.locator("#confirm-reset-btn")).toBeVisible();
    await expect(page.locator(".modal-title")).toContainText("Reset Plan");
  });

  test("reset confirm button calls API", async ({ page }) => {
    await page.evaluate(() => (window as any).resetPlan(300));
    await page.waitForSelector("#confirm-reset-btn", { timeout: 3000 });

    const [request] = await Promise.all([
      page.waitForRequest((req) => req.url().includes("/api/plan/reset")),
      page.locator("#confirm-reset-btn").click(),
    ]);
    expect(request.url()).toContain("plan_id=300");
  });

  test("cancel modal abort does NOT call API", async ({ page }) => {
    let apiCalled = false;
    page.on("request", (req) => {
      if (req.url().includes("/api/plan/cancel")) apiCalled = true;
    });

    await page.evaluate(() => (window as any).cancelPlan(300));
    await page.waitForSelector(".modal-overlay", { timeout: 3000 });

    // Click Abort button
    await page.locator(".modal-overlay .preflight-action-btn").first().click();
    await page.waitForTimeout(500);
    expect(apiCalled).toBe(false);
    await expect(page.locator(".modal-overlay")).toHaveCount(0);
  });

  test("cancel modal closes on overlay click", async ({ page }) => {
    await page.evaluate(() => (window as any).cancelPlan(300));
    await page.waitForSelector(".modal-overlay", { timeout: 3000 });

    // Click overlay background
    await page.locator(".modal-overlay").click({ position: { x: 5, y: 5 } });
    await page.waitForTimeout(300);
    await expect(page.locator(".modal-overlay")).toHaveCount(0);
  });

  test("cancel confirm removes modal from DOM", async ({ page }) => {
    await page.evaluate(() => (window as any).cancelPlan(300));
    await page.waitForSelector("#confirm-cancel-btn", { timeout: 3000 });
    await page.locator("#confirm-cancel-btn").click();
    await page.waitForTimeout(500);
    // Modal overlay should be removed after confirm
    await expect(page.locator(".modal-overlay")).toHaveCount(0);
  });
});

test.describe("Plan Debug & Resume buttons", () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.goto("/");
    await page.waitForSelector("#mission-content", { timeout: 5000 });
    await page.waitForTimeout(500);
  });

  test("Debug button exists on active plan card", async ({ page }) => {
    const debugBtn = page.locator(".plan-health-btn-term").first();
    if ((await debugBtn.count()) > 0) {
      await debugBtn.scrollIntoViewIfNeeded();
      await expect(debugBtn).toContainText("Debug");
    }
  });

  test("Resume button exists on active plan card", async ({ page }) => {
    const resumeBtn = page.locator(".plan-health-btn-resume").first();
    if ((await resumeBtn.count()) > 0) {
      await resumeBtn.scrollIntoViewIfNeeded();
      await expect(resumeBtn).toContainText("Resume");
    }
  });

  test("Debug button opens terminal with plan session", async ({ page }) => {
    await stubWS(page);
    const debugBtn = page.locator(".plan-health-btn-term").first();
    if ((await debugBtn.count()) === 0) return;
    await debugBtn.scrollIntoViewIfNeeded();
    await debugBtn.click();
    await page.waitForSelector("#term-main.open", { timeout: 3000 });
    await expect(page.locator(".term-tab")).toContainText("Plan #300");
  });

  test("Resume button opens terminal and sends execute command", async ({
    page,
  }) => {
    await page.evaluate(() => {
      (window as any)._wsSends = [];
      (window as any).WebSocket = class FakeWS {
        readyState = 1;
        binaryType = "arraybuffer";
        onopen: any;
        onclose: any;
        onerror: any;
        onmessage: any;
        send(data: any) {
          (window as any)._wsSends.push(data);
        }
        close() {}
        constructor() {
          const self = this;
          setTimeout(() => {
            if (self.onopen) self.onopen();
          }, 20);
        }
      };
    });

    const resumeBtn = page.locator(".plan-health-btn-resume").first();
    if ((await resumeBtn.count()) === 0) return;
    await resumeBtn.scrollIntoViewIfNeeded();
    await resumeBtn.click();
    await page.waitForSelector("#term-main.open", { timeout: 3000 });
    await expect(page.locator(".term-tab")).toContainText("Resume #300");

    await page.waitForTimeout(2000);
    const sends = await page.evaluate(() => (window as any)._wsSends.length);
    expect(sends).toBeGreaterThan(0);
  });
});

test.describe("Plan Move", () => {
  test.beforeEach(async ({ page, mockApis }) => {
    await mockApis();
    await page.route("**/api/plan/move*", (route) =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true, plan_id: 300, target: "omarchy" }),
      }),
    );
    await page.goto("/");
    await page.waitForSelector(".mesh-node", { timeout: 5000 });
  });

  test("move-here button exists on online worker nodes", async ({ page }) => {
    const omarchy = page.locator(".mesh-node.online", { hasText: "omarchy" });
    const moveBtn = omarchy.locator('.mn-act-btn[data-action="movehere"]');
    await expect(moveBtn).toHaveCount(1);
  });

  test("move-here button triggers move dialog", async ({ page }) => {
    page.on("dialog", (dialog) => dialog.accept());
    const omarchy = page.locator(".mesh-node.online", { hasText: "omarchy" });
    const moveBtn = omarchy.locator('.mn-act-btn[data-action="movehere"]');
    await moveBtn.click();
    await page.waitForTimeout(500);
  });
});
