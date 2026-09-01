import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import SidePanelOpenerController from "../../../app/javascript/controllers/side_panel_opener_controller"

const flush = () => new Promise(resolve => setTimeout(resolve, 0))

const html = `
  <button id="meal-form-with-return" data-controller="side-panel-opener"
    data-action="click->side-panel-opener#openMealForm"
    data-date="2026-09-02" data-scope="my" data-return-to="daily_review"></button>
  <button id="meal-form-without-return" data-controller="side-panel-opener"
    data-action="click->side-panel-opener#openMealForm"
    data-date="2026-09-02" data-scope="family"></button>
  <button id="meal-edit-with-return" data-controller="side-panel-opener"
    data-action="click->side-panel-opener#openMealEdit"
    data-meal-id="7" data-scope="my" data-return-to="daily_review"></button>
`

describe("side-panel-opener controller", () => {
  let application: Application
  let fetchMock: ReturnType<typeof vi.fn>

  beforeEach(async () => {
    fetchMock = vi.fn().mockResolvedValue({ text: () => Promise.resolve("") })
    vi.stubGlobal("fetch", fetchMock)
    document.body.innerHTML = html
    application = Application.start()
    application.register("side-panel-opener", SidePanelOpenerController)
    await flush()
  })

  afterEach(async () => {
    application.stop()
    document.body.innerHTML = ""
    await flush()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  const requestedUrl = () => fetchMock.mock.calls[0][0] as string

  it("appends return_to to the meal form url when data-return-to is present", async () => {
    document.querySelector<HTMLButtonElement>("#meal-form-with-return")!.click()
    await flush()

    expect(requestedUrl()).toBe("/meals/new?date=2026-09-02&scope=my&return_to=daily_review")
  })

  it("omits return_to from the meal form url when data-return-to is absent", async () => {
    document.querySelector<HTMLButtonElement>("#meal-form-without-return")!.click()
    await flush()

    expect(requestedUrl()).toBe("/meals/new?date=2026-09-02&scope=family")
  })

  it("appends return_to to the meal edit url when data-return-to is present", async () => {
    document.querySelector<HTMLButtonElement>("#meal-edit-with-return")!.click()
    await flush()

    expect(requestedUrl()).toBe("/meals/7/edit?scope=my&return_to=daily_review")
  })
})
